import Foundation
import CoreLocation

enum EventKind: String, Codable, CaseIterable, Identifiable {
    case officialWarning = "Официальное предупреждение"
    case airspaceRestriction = "Ограничение воздушного пространства"
    case aircraftObservation = "Авиационное наблюдение"
    case droneDetection = "Обнаружение датчиком"

    var id: String { rawValue }
}

enum EvidenceStatus: String, Codable {
    case officialNotice = "Официальное сообщение"
    case observed = "Наблюдение"
    case sensorConfirmed = "Подтверждено датчиком"
    case unverified = "Не проверено"
}

struct DroneWatchEvent: Identifiable, Codable {
    var id: UUID = UUID()
    var sourceID: String
    var kind: EventKind
    var evidence: EvidenceStatus
    var title: String
    var message: String
    var issuedAt: Date?
    var observedAt: Date?
    var receivedAt: Date = .now
    var latitude: Double?
    var longitude: Double?
    var sourceURL: URL?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static let demo = DroneWatchEvent(
        sourceID: "local-demo",
        kind: .officialWarning,
        evidence: .unverified,
        title: "Демонстрационное событие",
        message: "Это тестовая запись интерфейса, не реальное предупреждение и не обнаружение БПЛА.",
        issuedAt: .now,
        receivedAt: .now
    )
}
