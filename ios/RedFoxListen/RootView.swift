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
                    CategoriesView().tabItem { Label("类目", systemImage: "safari") }
                    StudyView().tabItem { Label("学习", systemImage: "book") }

                    NavigationStack { ProfileView() }.tabItem { Label("我的", systemImage: "person") }
                }
            }
        }.tint(Color(red: 0.15, green: 0.65, blue: 0.60)).overlay { if session.busy { ProgressView().padding(24).background(.regularMaterial).cornerRadius(12) } }
        .disabled(session.busy)
        .alert("提示", isPresented: Binding(get: { !session.message.isEmpty }, set: { if !$0 { session.message = "" } })) { Button("确定") { session.message = "" } } message: { Text(session.message) }
    }
}
struct CategoriesView: View {
    private let symbols = ["news": "newspaper", "documentary": "flask", "talkshow": "mic", "action": "film", "animation": "paintpalette", "detective": "shield", "live": "video", "moive": "film", "speech": "antenna.radiowaves.left.and.right", "blog": "book"]
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
                                    Image(systemName: symbols[(category["img"] as? String ?? "").lowercased()] ?? "square.grid.2x2").font(.title2).foregroundColor(.teal).frame(width: 56, height: 56).background(Color.teal.opacity(0.1)).cornerRadius(16)
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
    var body: some View { AsyncImage(url: URL(string: url)) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "play.rectangle").resizable().scaledToFit().padding(8).foregroundColor(.teal) }.frame(width: 56, height: 56).clipped().cornerRadius(8) }
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
                        NavigationLink { ProfileView() } label: { VStack { AsyncImage(url: URL(string: items[i]["poster"] as? String ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.08) }.frame(height: 180); Text(title(items[i])).font(.subheadline).foregroundColor(.primary).lineLimit(2).frame(maxWidth: .infinity, minHeight: 40, alignment: .top); Image(systemName: "lock") } }
                    } else { NavigationLink { SeriesView(id: items[i]["id"] as? Int ?? 0, name: title(items[i])) } label: { VStack { AsyncImage(url: URL(string: items[i]["poster"] as? String ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.08) }.frame(height: 180); Text(title(items[i])).font(.subheadline).foregroundColor(.primary).lineLimit(2).frame(maxWidth: .infinity, minHeight: 40, alignment: .top) } } }
                    HStack {
                        Button((items[i]["thumbUp"] as? Int ?? 1) == 0 ? "已点赞" : "点赞") { toggle(i, key: "thumbUp", endpoint: "curriculumGoodUserRelated/thumbUp") }
                        Button((items[i]["collection"] as? Int ?? 1) == 0 ? "已收藏" : "收藏") { toggle(i, key: "collection", endpoint: "curriculumScheduleUserRelated/collection") }
                    }.buttonStyle(.bordered)
                }
            }
          }.padding(16)
        }.toolbar(.hidden, for: .tabBar).navigationTitle(search.isEmpty ? "课程" : "搜索结果").navigationBarTitleDisplayMode(.inline).toolbar { Button("刷新") { load() } }.task { load() }
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
                let episode = episodes[index]
                let locked = (session.profile["vip"] as? Int ?? 0) == 0 && index >= 10
                HStack(spacing: 12) {
                    NavigationLink {
                        if locked { ProfileView() }
                        else { PlayerView(id: episode["id"] as? Int ?? 0) }
                    } label: {
                        HStack(spacing: 12) {
                            RemotePoster(url: episode["thumbnail"] as? String ?? "")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title(episode)).font(.body).foregroundColor(.teal).fixedSize(horizontal: false, vertical: true)
                                if locked { Image(systemName: "lock.fill").font(.caption2) }
                                Text(episode["desc"] as? String ?? episode["curriculumDesc"] as? String ?? "").font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                    }
                    downloadButton(episode)
                }
            }
        }.toolbar(.hidden, for: .tabBar).navigationTitle(name).navigationBarTitleDisplayMode(.inline).toolbar { Button("刷新") { load() } }.task { load() }
    }
    @ViewBuilder func downloadButton(_ item: JSON) -> some View {
        let videoID = item["id"] as? Int ?? 0
        if downloads.running.contains(videoID) { Button { downloads.cancel(videoID) } label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }.buttonStyle(.borderless).accessibilityLabel("取消下载") }
        else if downloads.localURL(videoID) != nil {
            Image(systemName: "checkmark.circle").foregroundColor(.teal)
                .frame(width: 44, height: 44).accessibilityLabel("已下载")
        }
        else { Button { downloads.start(item) } label: { Image(systemName: "arrow.down.circle").frame(width: 44, height: 44) }.buttonStyle(.borderless).accessibilityLabel("下载视频") }
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
    @State private var recording = false
    @State private var selectedForDeletion: Int?
    var body: some View {
        VStack(spacing: 0) {
            VideoPlayer(player: playback.player).frame(height: 230)
            HStack {
                Text(clock(playback.position))
                Slider(value: Binding(get: { playback.position }, set: { playback.seek($0) }), in: 0...max(1, playback.duration))
                Text(clock(playback.duration))
            }.font(.caption.monospacedDigit()).foregroundColor(.secondary).padding(.horizontal, 8)
            ScrollView {
                if playback.segments.isEmpty {
                    Text("暂无记录").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 4)], spacing: 4) {
                    ForEach(playback.segments.indices, id: \.self) { index in
                        Button { playback.select(index) } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "heart.fill").font(.title3)
                                Text("\(index + 1)").font(.caption2)
                            }.foregroundColor(playback.active == index ? .teal : .gray)
                        }.contextMenu {
                            Button("删除记录", role: .destructive) { selectedForDeletion = index }
                        }
                    }
                }
            }.padding(8)
            HStack(spacing: 0) {
                if recording {
                    Button("A") { session.run { try playback.recordA() } }.frame(maxWidth: .infinity)
                    Button("B") { session.run { try playback.recordB() } }.frame(maxWidth: .infinity)
                }
                control("后退5秒", "gobackward.5") { playback.seek(playback.position - 5) }
                control("前进5秒", "goforward.5") { playback.seek(playback.position + 5) }
                if recording {
                    control("保存记录", "tray.and.arrow.down") { session.run { try await playback.save(session: session) } }.disabled(!playback.recordsReady)
                    control("清空记录", "trash") { deleting = true }
                } else {
                    control(playback.playing ? "暂停" : "播放", playback.playing ? "pause.fill" : "play.fill") { playback.toggle() }
                    control("上一段", "backward.end.fill") { playback.stepSegment(-1) }
                    control("下一段", "forward.end.fill") { playback.stepSegment(1) }
                    control("精听", "flame.fill") { session.run {
                        let value = (playback.detail["specialize"] as? Int ?? 1) == 0 ? 1 : 0
                        _ = try await session.post("curriculumUserDaydayuse/specialize", ["curriculumId": id, "specialize": value])
                        playback.detail["specialize"] = value
                    } }.foregroundColor((playback.detail["specialize"] as? Int) == 0 ? .teal : .secondary)
                }
                if (session.profile["vip"] as? Int) == 8 {
                    control("切换 AB 模式", "arrow.left.arrow.right") { recording.toggle() }
                }
            }.buttonStyle(.plain).padding(.horizontal, 8)
        }.navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
        .task { load() }.onDisappear { playback.stop() }
        .confirmationDialog("确认清空云端AB记录？", isPresented: $deleting) { Button("清空", role: .destructive) { session.run { try await playback.deleteCloud(session: session) } } }
        .confirmationDialog("删除这条记录？", isPresented: Binding(get: { selectedForDeletion != nil }, set: { if !$0 { selectedForDeletion = nil } }), presenting: selectedForDeletion) { index in
            Button("删除", role: .destructive) { playback.remove(index) }
        }
    }
    private func control(_ label: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle()) }.accessibilityLabel(label)
    }
    private func clock(_ seconds: Double) -> String {
        let t = seconds.isFinite ? Int(max(0, seconds)) : 0
        return String(format: "%d:%02d", t / 60, t % 60)
    }
    func load() { session.run { try await playback.load(id: id, session: session, downloads: downloads) } }
}
struct StudyView: View {
    @EnvironmentObject var session: Session
    @State private var study: JSON = [:]
    var body: some View {
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 4) { Text("今天").font(.caption); Text(Date(), style: .date).font(.headline) }.foregroundColor(.white).listRowBackground(Color.teal)
                NavigationLink("离线视频") { DownloadsView() }
                Section("专注") { ForEach(Array((study["curriculumList"] as? [JSON] ?? []).enumerated()), id: \.offset) { _, item in NavigationLink(title(item)) { PlayerView(id: item["id"] as? Int ?? 0) } } }
                Section("收藏") { ForEach(Array((study["categoryList"] as? [JSON] ?? []).enumerated()), id: \.offset) { _, item in NavigationLink(title(item)) { SeriesView(id: item["id"] as? Int ?? 0, name: title(item)) } } }
            }.navigationTitle("我的学习").toolbar { Button("刷新") { load() } }.task { load() }
        }
    }
    func load() { session.run { study = try await session.post("study/list") as? JSON ?? [:] } }
}
struct DownloadsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var downloads: DownloadStore
    var body: some View {
            List {
                ForEach(downloads.running.sorted(), id: \.self) { id in Button("视频 \(id) 下载中，点击取消") { downloads.cancel(id) } }
                ForEach(downloads.items) { item in
                    NavigationLink(item.name) { PlayerView(id: item.id) }
                    Button("删除本地视频", role: .destructive) { session.run { try downloads.remove(item.id) } }
                }
                if downloads.items.isEmpty && downloads.running.isEmpty { Text("暂无下载，请在剧集列表中下载视频") }
            }.navigationTitle("离线视频").toolbar(.hidden, for: .tabBar)
    }
}
struct ProfileView: View {
    @EnvironmentObject var session: Session
    @State private var feedback = ""
    @State private var vipUser = ""
    @State private var removing = false
    var body: some View {
            Form {
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: session.profile["avatar"] as? String ?? "")) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "person.circle.fill").resizable().foregroundColor(.secondary) }.frame(width: 60, height: 60).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.profile["name"] as? String ?? session.profile["username"] as? String ?? "我的账号").font(.headline)
                        Text((session.profile["vip"] as? Int ?? 0) == 0 ? "普通用户" : "VIP").font(.subheadline).foregroundColor(.secondary)
                    }
                }
                NavigationLink("会员说明") { MembershipView() }
                DisclosureGroup("建议") { TextField("建议与反馈", text: $feedback, axis: .vertical); Button("提交反馈") { session.run { _ = try await session.post("suggest/insert", ["userId": session.profile["userId"] ?? 0, "content": feedback]); feedback = ""; session.message = "感谢反馈" } }.disabled(feedback.isEmpty) }
                if (session.profile["vip"] as? Int) == 8 {
                    DisclosureGroup("设置 VIP") { TextField("会员用户名", text: $vipUser); Button("设置会员") { session.run { _ = try await session.post("user/setting/vip", ["username": vipUser]); session.message = "操作成功" } }.disabled(vipUser.isEmpty) }
                }
                NavigationLink("隐私政策") { PrivacyView() }
                Button("退出登录") { session.run { try await session.logout() } }
                Button("注销账号", role: .destructive) { removing = true }
            }.navigationTitle("我的").task { session.run { try await session.loadProfile() } }
            .confirmationDialog("注销将删除账号，是否继续？", isPresented: $removing, titleVisibility: .visible) { Button("确认注销", role: .destructive) { session.run { _ = try await session.post("user/removal", ["id": session.profile["userId"] ?? 0]); try TokenStore.save(""); session.token = ""; session.clearUser() } } }
    }
}
struct MembershipView: View {
    var body: some View {
        ScrollView { VStack(spacing: 24) {
            Text("支付宝二维码").font(.title)
            AsyncImage(url: URL(string: "https://lemoncity.oss-cn-shanghai.aliyuncs.com/zhifubao/zhifubao.png")) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(width: 250, height: 250)
            Text("请在支付备注里面填写用户名，一个工作日左右开通")
            Text("听力年度VIP ¥88\n听力与单词年度双VIP ¥158")
        }.padding() }.navigationTitle("会员说明")
    }
}
