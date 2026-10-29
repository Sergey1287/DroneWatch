import Foundation

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [DroneWatchEvent] = []
    @Published var lastRefresh: Date?
    @Published var sourceStatus = "Источники ещё не подключены"

    private let storageURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("dronewatch-events.json")
    }()

    init() { load() }

    func add(_ event: DroneWatchEvent) {
        // Keep one record per source and event ID; source adapters should provide stable IDs in production.
        events.insert(event, at: 0)
        events = Array(events.prefix(500))
        save()
    }

    func markRefresh(status: String) {
        lastRefresh = .now
        sourceStatus = status
    }

    func clear() {
        events.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            sourceStatus = "Ошибка локального сохранения"
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([DroneWatchEvent].self, from: data) else { return }
        events = decoded
    }
}
