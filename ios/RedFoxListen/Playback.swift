import Foundation
import Combine
import AVFoundation
import MediaPlayer

@MainActor final class Playback: ObservableObject {
    let player = AVPlayer()
    @Published var detail: JSON = [:]
    @Published var segments: [ABSegment] = []
    @Published var active: Int?
    @Published var pendingA: Double?
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var playing = false
    @Published var rate: Float = 1
    @Published var loaded = false
    @Published var recordsReady = false
    private var observer: Any?
    private var failureObserver: NSObjectProtocol?
    private var itemStatus: NSKeyValueObservation?
    private var seeking = false
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    func load(id: Int, session: Session, downloads: DownloadStore) async throws {
        stop(); loaded = false; recordsReady = false; segments = []; active = nil; pendingA = nil
        if let cached = downloads.items.first(where: { $0.id == id }), let local = downloads.localURL(id) {
            detail = ["id": id, "curriculumName": cached.name, "categoryId": cached.categoryId]; configure(local, session: session)
        } else {
            detail = try await session.post("curriculum/load", ["id": id]) as? JSON ?? [:]
            guard let url = URL(string: (detail["url"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? detail["videoUrl"] as? String ?? ""), ["http", "https"].contains(url.scheme ?? "") else { throw AppFailure(message: "视频地址无效") }
            configure(url, session: session)
        }
        // Loading errors remain visible; saving is disabled until remote records load successfully.
        let result = try await session.post("curriculumUserRecord/pageList", ["curriculumId": id]) as? JSON ?? [:]
        let data = try JSONSerialization.data(withJSONObject: result["recordPhase"] as? [JSON] ?? [])
        segments = try JSONDecoder().decode([ABSegment].self, from: data).filter(\.valid).sorted { $0.APos < $1.APos }
        recordsReady = true
    }
    private func configure(_ url: URL, session: Session) {
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback); try AVAudioSession.sharedInstance().setActive(true) } catch { session.message = error.localizedDescription }
        let item = AVPlayerItem(url: url); player.replaceCurrentItem(with: item); loaded = true
        itemStatus = item.observe(\.status, options: [.new]) { [weak session] item, _ in
            if item.status == .failed { Task { @MainActor in session?.message = item.error?.localizedDescription ?? "视频加载失败" } }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak session] _ in Task { @MainActor in session?.message = "视频播放中断，请检查网络后重试" } }
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                if !self.seeking { self.position = max(0, time.seconds.isFinite ? time.seconds : 0) }
                let length = self.player.currentItem?.duration.seconds ?? 0
                self.duration = length.isFinite ? max(0, length) : 0
                self.playing = self.player.rate != 0
                if self.playing, let i = self.active, self.segments.indices.contains(i), self.position >= self.segments[i].BPos, !self.seeking { self.seek(self.segments[i].APos) }
                self.updateNowPlaying()
            }
        }
        let center = MPRemoteCommandCenter.shared()
        let play = center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player.playImmediately(atRate: self?.rate ?? 1) }; return .success }
        let pause = center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player.pause() }; return .success }
        let previous = center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stepSegment(-1) }
            return .success
        }
        let next = center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stepSegment(1) }
            return .success
        }
        remoteTargets = [(center.playCommand, play), (center.pauseCommand, pause),
                         (center.previousTrackCommand, previous), (center.nextTrackCommand, next)]
    }
    func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: detail["curriculumName"] as? String ?? "红狐听力", MPMediaItemPropertyPlaybackDuration: duration, MPNowPlayingInfoPropertyElapsedPlaybackTime: position, MPNowPlayingInfoPropertyPlaybackRate: player.rate]
    }
    func toggle() { if player.rate == 0 { player.playImmediately(atRate: rate) } else { player.pause() } }
    func seek(_ value: Double) {
        let target = boundedSeek(value, duration: duration); position = target; seeking = true
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in Task { @MainActor in self?.seeking = false } }
    }
    func recordA() throws {
        guard player.rate > 0 else { throw AppFailure(message: "请先播放") }
        pendingA = pendingA == nil ? position : nil
    }
    func recordB() throws {
        guard player.rate > 0 else { throw AppFailure(message: "请先播放") }
        guard let start = pendingA, position > start else { throw AppFailure(message: "请先设置A点，B点必须晚于A点") }
        let activeSegment = active.flatMap { segments.indices.contains($0) ? segments[$0] : nil }
        segments.append(ABSegment(APos: start, BPos: position)); segments.sort { $0.APos < $1.APos }
        active = activeSegment.flatMap { segments.firstIndex(of: $0) }; pendingA = nil
    }
    func select(_ index: Int) {
        guard segments.indices.contains(index) else { return }
        if active == index { active = nil; return }
        active = index; seek(segments[index].APos); player.playImmediately(atRate: rate)
    }
    func stepSegment(_ direction: Int) {
        let target: Int?
        if let active { target = active + direction }
        else if direction > 0 { target = segments.firstIndex { $0.APos >= position } }
        else { target = segments.lastIndex { $0.APos < position } }
        if let target, segments.indices.contains(target) { select(target) }
    }
    func remove(_ index: Int) {
        guard segments.indices.contains(index) else { return }
        segments.remove(at: index)
        if active == index { active = nil } else if let i = active, i > index { active = i - 1 }
    }
    func save(session: Session) async throws {
        guard recordsReady else { throw AppFailure(message: "请先成功加载云端记录") }
        _ = try await session.post("curriculumUserRecord/insertOrUpdate", ["curriculumId": detail["id"] ?? 0, "curriculumName": detail["curriculumName"] ?? "", "category": detail["categoryId"] ?? 0, "recordPhase": segments.map { ["APos": $0.APos, "BPos": $0.BPos] }])
        session.message = "AB记录已保存"
    }
    func deleteCloud(session: Session) async throws {
        _ = try await session.post("curriculumUserRecord/deleteRecord", ["curriculumId": detail["id"] ?? 0]); segments = []; active = nil; pendingA = nil; recordsReady = true
    }
    func stop() {
        player.pause()
        if let observer { player.removeTimeObserver(observer); self.observer = nil }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver); self.failureObserver = nil }
        itemStatus = nil; remoteTargets.forEach { $0.0.removeTarget($0.1) }; remoteTargets = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
