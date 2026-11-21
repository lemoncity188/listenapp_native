import SwiftUI
@main struct RedFoxListenApp: App {
    @StateObject private var session = Session()
    @StateObject private var downloads = DownloadStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(session).environmentObject(downloads).tint(.teal) } }
}
