import SwiftUI
import MapKit

private enum Tab: String, CaseIterable {
    case map = "Карта"
    case radar = "Радар"
    case events = "События"
    case settings = "Настройки"

    var symbol: String {
        switch self {
        case .map: return "map"
        case .radar: return "dot.radiowaves.left.and.right"
        case .events: return "list.bullet.rectangle"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var location: LocationManager
    @State private var tab: Tab = .map
    @State private var showDemoNotice = false
    @State private var alertsEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch tab {
                case .map: mapView
                case .radar: radarView
                case .events: eventsView
                case .settings: settingsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            tabBar
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            location.requestPermission()
            alertsEnabled = await NotificationService.requestPermission()
        }
        .alert("Демонстрационное событие", isPresented: $showDemoNotice) {
            Button("Понятно", role: .cancel) { }
        } message: {
            Text("Добавлена только тестовая запись. Она не означает, что БПЛА обнаружен или что существует реальная угроза.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.title2.weight(.bold))
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("DroneWatch").font(.headline)
                Text("Персональный мониторинг").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(.orange).frame(width: 8, height: 8)
            Text("Источники не подключены")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
        .padding()
    }

    private var mapView: some View {
        ZStack(alignment: .top) {
            Map {
                UserAnnotation()
                ForEach(store.events) { event in
                    if let coordinate = event.coordinate {
                        Marker(event.title, coordinate: coordinate)
                            .tint(event.kind == .officialWarning ? .orange : .cyan)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(location.location.map {
                        String(format: "Местоположение: %.4f, %.4f",
                               $0.coordinate.latitude, $0.coordinate.longitude)
                    } ?? "Местоположение недоступно", systemImage: "location")
                    Text("Метки отображаются только для событий с координатами.")
                    Text("Официальные предупреждения не равны обнаружению БПЛА.")
                }
                .font(.caption)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var radarView: some View {
        VStack(spacing: 20) {
            Text("РАДАР").font(.headline).tracking(4)
            ZStack {
                Circle().stroke(.green.opacity(0.75), lineWidth: 1).frame(width: 280, height: 280)
                Circle().stroke(.green.opacity(0.45), lineWidth: 1).frame(width: 210, height: 210)
                Circle().stroke(.green.opacity(0.35), lineWidth: 1).frame(width: 140, height: 140)
                Circle().stroke(.green.opacity(0.25), lineWidth: 1).frame(width: 70, height: 70)
                Rectangle().fill(.green.opacity(0.35)).frame(width: 1, height: 280)
                Rectangle().fill(.green.opacity(0.35)).frame(width: 280, height: 1)
                Image(systemName: "location.fill").foregroundStyle(.cyan)
            }
            Text("Нет измерений дальности и азимута")
                .font(.subheadline.weight(.medium))
            Text("Экран показывает только сетку. Цели не рисуются без реального источника измерений.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
        .padding(.top, 24)
    }

    private var eventsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Журнал событий").font(.title3.bold())
                Spacer()
                Text("\(store.events.count)").foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            if store.events.isEmpty {
                ContentUnavailableView(
                    "Пока нет событий",
                    systemImage: "tray",
                    description: Text("События появятся после подключения источников данных.")
                )
            } else {
                List(store.events) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title).font(.headline)
                        Text(event.kind.rawValue).font(.caption).foregroundStyle(.cyan)
                        Text(event.message).font(.subheadline)
                        Text("\(event.evidence.rawValue) · \(event.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("Источник: \(event.sourceID)").font(.caption2).foregroundStyle(.secondary)
                        if let url = event.sourceURL {
                            Link("Открыть источник", destination: url)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top)
    }

    private var settingsView: some View {
        Form {
            Section("Источники") {
                LabeledContent("Статус", value: store.sourceStatus)
                LabeledContent("Последнее обновление", value: store.lastRefresh?.formatted(date: .abbreviated, time: .shortened) ?? "Нет данных")
                Text("Автоматические официальные потоки пока не настроены. Приложение не использует вымышленные API-адреса.")
                    .font(.footnote)
            }
            Section("Разрешения") {
                Button("Запросить геолокацию") { location.requestPermission() }
                Button("Запросить уведомления") {
                    Task { alertsEnabled = await NotificationService.requestPermission() }
                }
                LabeledContent("Уведомления", value: alertsEnabled ? "Разрешены" : "Не подтверждено")
            }
            Section("Проверка интерфейса") {
                Button("Добавить тестовую запись") {
                    store.add(.demo)
                    showDemoNotice = true
                }
                Button("Отправить тестовое уведомление") {
                    Task {
                        await NotificationService.sendLocal(
                            title: "DroneWatch — тест",
                            body: "Это проверка уведомлений, а не сообщение об угрозе."
                        )
                    }
                }
                Button("Очистить журнал", role: .destructive) { store.clear() }
            }
            Section("Ограничения") {
                Text("iPhone 16 не является радаром или широкополосным радиоприёмником. Приложение показывает опубликованные данные и не гарантирует обнаружение БПЛА.")
                    .font(.footnote)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 18))
                        Text(item.rawValue).font(.caption2)
                    }
                    .foregroundStyle(tab == item ? .cyan : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.05))
    }
}
