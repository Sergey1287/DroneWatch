import Foundation

/// Implement one adapter per official provider after its access method, terms,
/// schema and update frequency have been verified.
protocol SourceAdapter {
    var sourceID: String { get }
    func fetchEvents() async throws -> [DroneWatchEvent]
}

enum SourceError: LocalizedError {
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let source):
            return "\(source): официальный автоматизированный канал не настроен."
        }
    }
}

/// Safe starter adapter: intentionally does not scrape pages or invent API endpoints.
/// Replace with a documented, permitted feed or an official downloadable dataset.
struct UnconfiguredOfficialSource: SourceAdapter {
    let sourceID: String

    func fetchEvents() async throws -> [DroneWatchEvent] {
        throw SourceError.notConfigured(sourceID)
    }
}
