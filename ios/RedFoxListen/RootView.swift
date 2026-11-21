import SwiftUI
import AVKit

func title(_ item: JSON) -> String { (item["curriculumName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? item["categoryName"] as? String ?? "课程" }
struct RootView: View {
    @EnvironmentObject var session: Session
    var body: some View {
        Group {
            if session.token.isEmpty { AuthView() }
            else {
                TabView {
                    CategoriesView().tabItem { Label("发现", systemImage: "square.grid.2x2") }
                    StudyView().tabItem { Label("学习", systemImage: "book") }
                    DownloadsView().tabItem { Label("下载", systemImage: "arrow.down.circle") }
                    ProfileView().tabItem { Label("我的", systemImage: "person") }
                }
            }
        }.tint(Color(red: 0.15, green: 0.65, blue: 0.60)).overlay { if session.busy { ProgressView().padding(24).background(.regularMaterial).cornerRadius(12) } }
        .disabled(session.busy)
        .alert("提示", isPresented: Binding(get: { !session.message.isEmpty }, set: { if !$0 { session.message = "" } })) { Button("确定") { session.message = "" } } message: { Text(session.message) }
    }
}
struct CategoriesView: View {
    @EnvironmentObject var session: Session
    @State private var categories: [JSON] = []
    @State private var search = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("搜索课程", text: $search).submitLabel(.search)
                        NavigationLink("搜索") { CatalogView(code: "", search: search.trimmingCharacters(in: .whitespacesAndNewlines)) }.disabled(search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.padding(12).background(Color(.secondarySystemBackground)).cornerRadius(14)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                            NavigationLink { CatalogView(code: category["code"] as? String ?? "", search: "") } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "square.grid.2x2").font(.title2).foregroundColor(.teal).frame(width: 56, height: 56).background(Color.teal.opacity(0.1)).cornerRadius(16)
                                    Text(category["desc"] as? String ?? "分类").font(.caption).foregroundColor(.primary)
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(16)
            }.navigationTitle("红狐听力").navigationBarTitleDisplayMode(.inline).toolbar { Button("刷新") { load() } }.task { load() }
        }
    }
    func load() { session.run { try await session.loadProfile(); categories = try await session.post("dict/selectByKind", ["kind": "video"]) as? [JSON] ?? [] } }
}
struct RemotePoster: View {
    let url: String
    var body: some View { AsyncImage(url: URL(string: url)) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "play.rectangle").resizable().scaledToFit().padding(8).foregroundColor(.teal) }.frame(width: 64, height: 72).clipped().cornerRadius(8) }
}
struct CatalogView: View {
    @EnvironmentObject var session: Session
    let code: String
    let search: String
    @State private var items: [JSON] = []
    var body: some View {
        ScrollView {
          LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], alignment: .leading, spacing: 16) {
            ForEach(items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 8) {
                    if (session.profile["vip"] as? Int ?? 0) == 0 && (items[i]["id"] as? Int ?? 0) != 3 {
                        NavigationLink { MembershipView() } label: { VStack { AsyncImage(url: URL(string: items[i]["poster"] as? String ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.08) }.frame(height: 180); Text(title(items[i])).font(.subheadline).foregroundColor(.primary).lineLimit(2).frame(maxWidth: .infinity, minHeight: 40, alignment: .top); Image(systemName: "lock") } }
                    } else { NavigationLink { SeriesView(id: items[i]["id"] as? Int ?? 0, name: title(items[i])) } label: { VStack { AsyncImage(url: URL(string: items[i]["poster"] as? String ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.08) }.frame(height: 180); Text(title(items[i])).font(.subheadline).foregroundColor(.primary).lineLimit(2).frame(maxWidth: .infinity, minHeight: 40, alignment: .top) } } }
                    HStack {
                        Button((items[i]["thumbUp"] as? Int ?? 1) == 0 ? "已点赞" : "点赞") { toggle(i, key: "thumbUp", endpoint: "curriculumGoodUserRelated/thumbUp") }
                        Button((items[i]["collection"] as? Int ?? 1) == 0 ? "已收藏" : "收藏") { toggle(i, key: "collection", endpoint: "curriculumScheduleUserRelated/collection") }
                    }.buttonStyle(.bordered)
                }
            }
          }.padding(16)
        }.navigationTitle(search.isEmpty ? "课程" : "搜索结果").navigationBarTitleDisplayMode(.inline).toolbar { Button("刷新") { load() } }.task { load() }
    }
    func load() { session.run { items = try await session.post("category/selectByCategoryNo", ["categoryNo": code, "searchText": search, "categoryId": 0]) as? [JSON] ?? [] } }
    func toggle(_ i: Int, key: String, endpoint: String) { session.run { let next = (items[i][key] as? Int ?? 1) == 0 ? 1 : 0; _ = try await session.post(endpoint, ["curriculumId": items[i]["id"] ?? 0, key: next]); items[i][key] = next } }
}
struct SeriesView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var downloads: DownloadStore
    let id: Int
    let name: String
    @State private var episodes: [JSON] = []
    var body: some View {
        List {
            ForEach(episodes.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 10) {
                    if (session.profile["vip"] as? Int ?? 0) == 0 && index >= 10 { NavigationLink(title(episodes[index]) + " 🔒") { MembershipView() } }
                    else { NavigationLink(title(episodes[index])) { PlayerView(id: episodes[index]["id"] as? Int ?? 0) } }
                    Text(episodes[index]["curriculumDesc"] as? String ?? episodes[index]["desc"] as? String ?? "").font(.caption).foregroundColor(.secondary)
                    downloadButton(episodes[index])
                }
            }
        }.navigationTitle(name).navigationBarTitleDisplayMode(.inline).toolbar { Button("刷新") { load() } }.task { load() }
    }
    @ViewBuilder func downloadButton(_ item: JSON) -> some View {
        let videoID = item["id"] as? Int ?? 0
        if downloads.running.contains(videoID) { Button("下载中，点击取消") { downloads.cancel(videoID) }.buttonStyle(.bordered) }
        else if downloads.localURL(videoID) != nil { Text("已下载").font(.caption).foregroundColor(.teal) }
        else { Button("下载视频") { downloads.start(item) }.buttonStyle(.bordered) }
        if let error = downloads.errors[videoID] { Text(error).font(.caption).foregroundColor(.red) }
    }
    func load() { session.run { episodes = try await session.post("curriculum/selectByCategoryId", ["categoryId": id]) as? [JSON] ?? [] } }
}
struct PlayerView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var downloads: DownloadStore
    @StateObject private var playback = Playback()
    let id: Int
    @State private var deleting = false
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VideoPlayer(player: playback.player).frame(height: 240)
                Slider(value: Binding(get: { playback.position }, set: { playback.seek($0) }), in: 0...max(1, playback.duration))
                Text(String(format: "%.1f / %.1f 秒", playback.position, playback.duration)).monospacedDigit()
                HStack {
                    Button("后退5秒") { playback.seek(playback.position - 5) }
                    Button(playback.playing ? "暂停" : "播放") { playback.toggle() }
                    Button("前进5秒") { playback.seek(playback.position + 5) }
                }.buttonStyle(.bordered)
                Picker("播放速度", selection: $playback.rate) { ForEach([Float(0.5),0.75,1,1.25,1.5,2], id: \.self) { Text(String(format: "%.2gx", $0)).tag($0) } }.onChange(of: playback.rate) { if playback.playing { playback.player.rate = $0 } }
                HStack {
                    Button(playback.pendingA == nil ? "设置A" : "取消A") { session.run { try playback.recordA() } }
                    Button("设置B") { session.run { try playback.recordB() } }
                    Button("取消循环") { playback.active = nil }
                }.buttonStyle(.bordered)
                HStack {
                    Button("上一段") { if let index = playback.active, index > 0 { playback.select(index - 1) } }
                    Button("下一段") { if let index = playback.active, index + 1 < playback.segments.count { playback.select(index + 1) } }
                }
                ForEach(playback.segments.indices, id: \.self) { index in
                    HStack {
                        Button(String(format: "%@ %.2f → %.2f", playback.active == index ? "▶" : "", playback.segments[index].APos, playback.segments[index].BPos)) { playback.select(index) }
                        Spacer(); Button("删除") { playback.remove(index) }
                    }
                }
                HStack {
                    Button("保存AB记录") { session.run { try await playback.save(session: session) } }.disabled(!playback.recordsReady)
                    Button("清空云端记录", role: .destructive) { deleting = true }
                }
                Button((playback.detail["specialize"] as? Int ?? 1) == 0 ? "取消精听" : "标记精听") { session.run {
                    let value = (playback.detail["specialize"] as? Int ?? 1) == 0 ? 1 : 0
                    _ = try await session.post("curriculumUserDaydayuse/specialize", ["curriculumId": id, "specialize": value]); playback.detail["specialize"] = value
                } }
                if downloads.running.contains(id) { Text("下载中…") } else { Button("下载当前视频") { downloads.start(playback.detail) } }
                if let error = downloads.errors[id] { Text(error).foregroundColor(.red) }
                Button("重新加载") { load() }
            }.padding()
        }.navigationTitle(title(playback.detail)).navigationBarTitleDisplayMode(.inline)
        .task { load() }.onDisappear { playback.stop() }
        .confirmationDialog("确认清空云端AB记录？", isPresented: $deleting) { Button("清空", role: .destructive) { session.run { try await playback.deleteCloud(session: session) } } }
    }
    func load() { session.run { try await playback.load(id: id, session: session, downloads: downloads) } }
}
struct StudyView: View {
    @EnvironmentObject var session: Session
    @State private var study: JSON = [:]
    var body: some View {
        NavigationStack {
            List {
                Section("精听课程") { ForEach(Array((study["curriculumList"] as? [JSON] ?? []).enumerated()), id: \.offset) { _, item in NavigationLink(title(item)) { PlayerView(id: item["id"] as? Int ?? 0) } } }
                Section("收藏专辑") { ForEach(Array((study["categoryList"] as? [JSON] ?? []).enumerated()), id: \.offset) { _, item in NavigationLink(title(item)) { SeriesView(id: item["id"] as? Int ?? 0, name: title(item)) } } }
            }.navigationTitle("我的学习").toolbar { Button("刷新") { load() } }.task { load() }
        }
    }
    func load() { session.run { study = try await session.post("study/list") as? JSON ?? [:] } }
}
struct DownloadsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var downloads: DownloadStore
    var body: some View {
        NavigationStack {
            List {
                ForEach(downloads.running.sorted(), id: \.self) { id in Button("视频 \(id) 下载中，点击取消") { downloads.cancel(id) } }
                ForEach(downloads.items) { item in
                    NavigationLink(item.name) { PlayerView(id: item.id) }
                    Button("删除本地视频", role: .destructive) { session.run { try downloads.remove(item.id) } }
                }
                if downloads.items.isEmpty && downloads.running.isEmpty { Text("暂无下载，请在剧集列表中下载视频") }
            }.navigationTitle("离线视频")
        }
    }
}
struct ProfileView: View {
    @EnvironmentObject var session: Session
    @State private var feedback = ""
    @State private var vipUser = ""
    @State private var removing = false
    var body: some View {
        NavigationStack {
            Form {
                Section("账号") { Text(session.profile["username"] as? String ?? "我的账号"); Text("会员等级：\(session.profile["vip"] as? Int ?? 0)"); Button("刷新资料") { session.run { try await session.loadProfile() } } }
                NavigationLink("会员说明") { MembershipView() }
                Section("反馈") { TextField("建议与反馈", text: $feedback, axis: .vertical); Button("提交反馈") { session.run { _ = try await session.post("suggest/insert", ["userId": session.profile["userId"] ?? 0, "content": feedback]); feedback = ""; session.message = "感谢反馈" } }.disabled(feedback.isEmpty) }
                if (session.profile["vip"] as? Int) == 8 {
                    Section("管理员") { TextField("会员用户名", text: $vipUser); Button("设置会员") { session.run { _ = try await session.post("user/setting/vip", ["username": vipUser]); session.message = "操作成功" } }.disabled(vipUser.isEmpty) }
                }
                NavigationLink("隐私政策") { PrivacyView() }
                Button("退出登录") { session.run { try await session.logout() } }
                Button("注销账号", role: .destructive) { removing = true }
            }.navigationTitle("我的").task { session.run { try await session.loadProfile() } }
            .confirmationDialog("注销将删除账号，是否继续？", isPresented: $removing, titleVisibility: .visible) { Button("确认注销", role: .destructive) { session.run { _ = try await session.post("user/removal", ["id": session.profile["userId"] ?? 0]); try TokenStore.save(""); session.token = ""; session.clearUser() } } }
        }
    }
}
struct MembershipView: View {
    var body: some View {
        ScrollView { VStack(spacing: 24) {
            Text("支付宝二维码").font(.title)
            AsyncImage(url: URL(string: "https://lemoncity.oss-cn-shanghai.aliyuncs.com/zhifubao/zhifubao.png")) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(width: 250, height: 250)
            Text("请在支付备注里面填写用户名，一个工作日左右开通")
            Text("听力年度VIP ¥88\n听力与单词年度双VIP ¥158")
            Text("以上说明沿用原Android项目").foregroundColor(.secondary)
        }.padding() }.navigationTitle("会员说明")
    }
}
