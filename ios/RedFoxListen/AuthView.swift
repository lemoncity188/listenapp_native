import SwiftUI
struct AuthView: View {
    @EnvironmentObject var model: Session
    @State private var mode = 0
    @State private var mobile = ""
    @State private var password = ""
    @State private var repeatPassword = ""
    @State private var name = ""
    @State private var code = ""
    @State private var privacy = false
    @State private var agreed = false
    @State private var countdown = 0
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: "https://lemoncity.oss-cn-shanghai.aliyuncs.com/logo/firefox_word.png")) { image in image.resizable().scaledToFit() } placeholder: { Color.clear }.frame(width: 66, height: 66).padding(.bottom, 24)
                        field { TextField("请输入手机号", text: $mobile).keyboardType(.phonePad).textContentType(.username) }
                        if mode == 1 { field { TextField("请输入用户名", text: $name) } }
                        field { SecureField("请输入密码", text: $password) }
                        if mode != 0 {
                            field { SecureField("确认密码", text: $repeatPassword) }
                            HStack {
                                field { TextField("验证码", text: $code).keyboardType(.numberPad) }
                                Button(countdown > 0 ? "\(countdown)秒后重试" : "发送验证码") {
                                    model.run {
                                        guard mobile.range(of: "^[0-9]{11}$", options: .regularExpression) != nil else { throw AppFailure(message: "请输入11位手机号") }
                                        _ = try await model.post("user/sendCode", ["mobile": try encrypt(mobile)])
                                        countdown = 60
                                    }
                                }.disabled(countdown > 0)
                            }
                        }
                        Button(mode == 0 ? "登陆" : mode == 1 ? "注册" : "修改密码") {
                            model.run {
                                guard mode == 0 || password == repeatPassword else { throw AppFailure(message: "两次密码输入不一致") }
                                guard mode != 1 || agreed else { throw AppFailure(message: "请先阅读并同意隐私政策") }
                                try await model.authenticate(mode: mode, mobile: mobile, password: password, name: name, code: code)
                                if mode != 0 { mode = 0; password = ""; repeatPassword = ""; code = "" }
                            }
                        }.frame(maxWidth: .infinity).frame(height: 48).foregroundColor(.white).background(Color(red: 0.15, green: 0.65, blue: 0.60)).cornerRadius(4).padding(.top, 16)
                        if mode == 0 {
                            Button("立即注册") { privacy = true }.padding(.top, 14)
                            Button("忘记密码") { mode = 2 }.padding(.top, 14)
                        } else { Button("已有账号去登陆") { mode = 0 } }
                    }.font(.system(size: 16)).padding(.horizontal, 40).padding(.vertical, 32).frame(minHeight: geometry.size.height)
                }.background(Color.white)
            }
            .sheet(isPresented: $privacy) {
                NavigationStack {
                    VStack {
                        PrivacyView()
                        HStack {
                            Button("拒绝") { privacy = false }
                            Spacer()
                            Button("同意") { agreed = true; mode = 1; privacy = false }
                        }.padding(24)
                    }
                }
            }
            .task(id: countdown) {
                guard countdown > 0 else { return }
                do { try await Task.sleep(nanoseconds: 1_000_000_000); countdown -= 1 } catch { }
            }
        }
    }
    func field<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().textInputAutocapitalization(.never).autocorrectionDisabled().padding(.horizontal, 16).frame(height: 48).background(Color(white: 0.975)).cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.1)))
    }
}

struct PrivacyView: View { var body: some View { ScrollView { Text(privacyText).padding() }.navigationTitle("隐私政策") } }
