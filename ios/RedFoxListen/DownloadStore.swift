import Foundation
import Combine

struct DownloadItem: Codable, Identifiable { var id: Int; var name: String; var categoryId: Int; var source: String }
@MainActor final class DownloadStore: ObservableObject {
    @Published var items: [DownloadItem] = []
    @Published var running: Set<Int> = []
    @Published var errors: [Int: String] = [:]
    private var tasks: [Int: Task<Void, Never>] = [:]
    private let folder: URL
    init() {
        folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("videos", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true; var url = folder; try url.setResourceValues(values)
            if let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")) { items = try JSONDecoder().decode([DownloadItem].self, from: data).filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent("\($0.id).mp4").path) } }
        } catch { errors[0] = error.localizedDescription }
    }
    func localURL(_ id: Int) -> URL? { let url = folder.appendingPathComponent("\(id).mp4"); return FileManager.default.fileExists(atPath: url.path) ? url : nil }
    func start(_ detail: JSON) {
        guard let id = detail["id"] as? Int, !running.contains(id) else { return }
        running.insert(id); errors[id] = nil
        tasks[id] = Task {
            defer { running.remove(id); tasks[id] = nil }
            do {
                guard let source = (detail["url"] as? String).flatMap({ $0.isEmpty ? nil : $0 }) ?? detail["videoUrl"] as? String, let url = URL(string: source), ["http", "https"].contains(url.scheme ?? ""), url.pathExtension.lowercased() != "m3u8" else { throw AppFailure(message: "仅支持下载直接视频文件，HLS流请在线播放") }
                let (temp, response) = try await URLSession.shared.download(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !(http.mimeType ?? "").contains("text") else { throw AppFailure(message: "下载响应无效") }
                try Task.checkCancellation()
                let destination = folder.appendingPathComponent("\(id).mp4")
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.moveItem(at: temp, to: destination)
                items.removeAll { $0.id == id }; items.append(DownloadItem(id: id, name: detail["curriculumName"] as? String ?? "视频", categoryId: detail["categoryId"] as? Int ?? 0, source: source))
                try persist()
            } catch { if !Task.isCancelled { errors[id] = error.localizedDescription } }
        }
    }
    func cancel(_ id: Int) { tasks[id]?.cancel() }
    func remove(_ id: Int) throws {
        guard !running.contains(id) else { throw AppFailure(message: "请先取消下载") }
        if let url = localURL(id) { try FileManager.default.removeItem(at: url) }
        items.removeAll { $0.id == id }; try persist()
    }
    private func persist() throws { try JSONEncoder().encode(items).write(to: folder.appendingPathComponent("manifest.json"), options: .atomic) }
}
