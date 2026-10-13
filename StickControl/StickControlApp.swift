import SwiftUI

@main
struct StickControlApp: App {
    @StateObject private var model = PracticeModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            PracticeView(model: model)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { model.pause() }
                }
        }
    }
}
