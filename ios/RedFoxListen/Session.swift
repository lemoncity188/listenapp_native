import Foundation
import Combine
import CommonCrypto
import AVFoundation
import Security

typealias JSON = [String: Any]
struct AppFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
enum TokenStore {
    static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.redfox.listen.native", kSecAttrAccount as String: "token"]
    static func read() -> String {
        var q = query; q[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ token: String) throws {
        SecItemDelete(query as CFDictionary)
        if token.isEmpty { return }
        var q = query; q[kSecValueData as String] = Data(token.utf8)
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw AppFailure(message: "无法安全保存登录凭证") }
    }
}
// Compatible with the Android BouncyCastle AES/CBC/ZeroBytePadding wire format.
func encrypt(_ text: String) throws -> String {
    let key = Array("gww417038_x8888x".utf8)
    var input = Array(text.utf8)
    input += Array(repeating: 0, count: 16 - input.count % 16)
    var output = [UInt8](repeating: 0, count: input.count + 16)
    var written = 0
    let status = key.withUnsafeBytes { k in input.withUnsafeBytes { i in output.withUnsafeMutableBytes { o in
        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(0), k.baseAddress, key.count, k.baseAddress, i.baseAddress, input.count, o.baseAddress, o.count, &written)
    } } }
    guard status == kCCSuccess else { throw AppFailure(message: "登录数据加密失败") }
    return Data(output.prefix(written)).base64EncodedString()
}


@MainActor final class Session: ObservableObject {
    @Published var token = TokenStore.read()
    @Published var baseURL = UserDefaults.standard.string(forKey: "apiURL") ?? "http://47.97.107.100:8090/"
    @Published var busy = false
    @Published var message = ""
    @Published var profile: JSON = [:]
    private var pendingRequests = 0
    func run(_ work: @escaping () async throws -> Void) {
        pendingRequests += 1; busy = true
        Task { defer { pendingRequests -= 1; busy = pendingRequests > 0 }; do { try await work() } catch { message = error.localizedDescription } }
    }
    func post(_ endpoint: String, _ body: Any = JSON()) async throws -> Any {
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), ["http", "https"].contains(url.scheme ?? "") else { throw AppFailure(message: "接口地址无效") }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401 { try TokenStore.save(""); token = ""; clearUser() }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw AppFailure(message: "服务器请求失败") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? JSON else { throw AppFailure(message: "服务器返回格式无效") }
        if (json["errorCode"] as? Int) == 1000 && (json["subCode"] as? Int) == 1 { try TokenStore.save(""); token = ""; clearUser() }
        guard (json["status"] as? Int) == 0 else { throw AppFailure(message: json["subMessage"] as? String ?? json["errorMessage"] as? String ?? "请求失败") }
        return json["data"] ?? NSNull()
    }
    func authenticate(mode: Int, mobile: String, password: String, name: String, code: String) async throws {
        guard mobile.range(of: "^[0-9]{11}$", options: .regularExpression) != nil, password.count >= 6 else { throw AppFailure(message: "请输入11位手机号和至少6位密码") }
        if mode != 0 && code.isEmpty { throw AppFailure(message: "请输入验证码") }
        if mode == 1 && name.isEmpty { throw AppFailure(message: "请输入昵称") }
        var body: JSON = ["mobile": try encrypt(mobile), "password": try encrypt(password)]
        if mode != 0 { body["verificationCode"] = code }
        if mode == 1 { body["username"] = name; body["roles"] = "editor"; body["avatar"] = "https://lemoncity.oss-cn-shanghai.aliyuncs.com/avatar/avater01.png" }
        let result = try await post(mode == 0 ? "user/login" : mode == 1 ? "user/register" : "user/change/password", body)
        if mode == 0 {
            guard let value = result as? String, !value.isEmpty else { throw AppFailure(message: "登录未返回凭证") }
            try TokenStore.save(value); token = value
        } else { message = mode == 1 ? "注册成功，请登录" : "密码已修改，请登录" }
    }

    func loadProfile() async throws { profile = try await post("user/info") as? JSON ?? [:] }
    func clearUser() { profile = [:] }
    func logout() async throws { _ = try await post("user/logout"); try TokenStore.save(""); token = ""; clearUser() }
}
