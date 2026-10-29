import SwiftUI

@main
struct DroneWatchApp: App {
    @StateObject private var store = EventStore()
    @StateObject private var location = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(location)
                .preferredColorScheme(.dark)
        }
    }
}
