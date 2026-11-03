import SwiftUI

@main
struct TunerApp: App {
    @State private var model = TunerModel()

    var body: some Scene {
        WindowGroup {
            TunerView()
                .environment(model)
        }
    }
}
