import SwiftUI

extension Notification.Name {
    static let burrowOpenSettings = Notification.Name("com.ismsahin.Burrow.openSettings")
}

/// Açık çentik: üst bant (sekme + durum) ve sekme içeriği.
struct ExpandedNotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var media: MediaController
    @ObservedObject var shelf: ShelfStore
    let services: AppServices

    init(viewModel: NotchViewModel, services: AppServices) {
        self.viewModel = viewModel
        self.services = services
        settings = services.settings
        media = services.media
        shelf = services.shelf
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.bottom, 14)
        .foregroundStyle(.white)
        .background(alignment: .bottom) { tint }
    }

    // Kapak renginden yumuşak ışıma (Boring Notch esintisi)
    @ViewBuilder
    private var tint: some View {
        if settings.albumTint, media.info != nil, viewModel.tab == .home {
            RadialGradient(colors: [Color(nsColor: media.artworkColor).opacity(0.22), .clear],
                           center: .bottomLeading, startRadius: 10, endRadius: 320)
                .allowsHitTesting(false)
                .padding(.horizontal, -30)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(visibleTabs) { tab in
                    TabButton(tab: tab, isSelected: viewModel.tab == tab, badge: tab == .shelf ? shelf.items.count : 0) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { viewModel.tab = tab }
                    }
            }
            Spacer(minLength: viewModel.isIsland ? 16 : viewModel.geometry.notchSize.width + 16)
            DeviceBatteryHeader(services: services)
            BatteryHeader(battery: services.battery)
            IconButton(symbol: "gearshape.fill", help: "Ayarlar") {
                viewModel.collapse()
                NotificationCenter.default.post(name: .burrowOpenSettings, object: nil)
            }
        }
        .frame(height: max(24, viewModel.geometry.notchSize.height))
    }

    private var visibleTabs: [NotchTab] {
        NotchTab.allCases.filter { $0 != .shelf || settings.enableShelf }
    }

    @ViewBuilder
    private var content: some View {
        switch visibleTabs.contains(viewModel.tab) ? viewModel.tab : .home {
        case .home:
            HomeView(viewModel: viewModel, services: services)
                .transition(.opacity.combined(with: .move(edge: .leading)))
        case .shelf:
            ShelfView(store: services.shelf, isTargeted: viewModel.isDropTargeted)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .timer:
            TimerView(timer: services.timer)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }
}

private struct TabButton: View {
    let tab: NotchTab
    let isSelected: Bool
    let badge: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.symbol).font(.system(size: 11, weight: .semibold))
                Text(tab.title).font(.system(size: 11, weight: .semibold))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.white.opacity(0.25)))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(isSelected ? 0.18 : 0)))
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.55))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let symbol: String
    var size: CGFloat = 12
    var help: String = ""
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: size + 14, height: size + 14)
                .background(Circle().fill(Color.white.opacity(isHovering ? 0.15 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

/// Bağlı kulaklık vb. cihazların pil özeti (en düşük kulaklık düzeyi), üzerine gelince ayrıntı.
private struct DeviceBatteryHeader: View {
    @ObservedObject var services: AppServices

    var body: some View {
        let devices = services.deviceBatteries.sorted { $0.key < $1.key }
        if services.settings.showDeviceBattery, !devices.isEmpty {
            HStack(spacing: 8) {
                ForEach(devices.prefix(2), id: \.key) { name, battery in
                    HStack(spacing: 3) {
                        Image(systemName: DeviceSymbol.name(for: name)).font(.system(size: 11, weight: .semibold))
                        if let level = battery.lowest ?? battery.caseLevel {
                            Text("%\(level)").font(.system(size: 11, weight: .semibold).monospacedDigit())
                        }
                    }
                    .foregroundStyle((battery.lowest ?? 100) <= 20 ? .red : .white.opacity(0.8))
                    .help("\(name): \(battery.summary)")
                }
            }
        }
    }
}

private struct BatteryHeader: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        if battery.state.hasBattery {
            HStack(spacing: 5) {
                Text("%\(battery.state.percent)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                BatteryGlyph(percent: battery.state.percent, isCharging: battery.state.isCharging)
            }
        }
    }
}
