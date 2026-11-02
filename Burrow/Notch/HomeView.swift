import SwiftUI

/// Ana sekme: Ayarlar › Etkinlikler › Ana Ekran'da seçilen parçalar, seçilen sırayla (müzik, takvim, anımsatıcılar, ayna).
/// Ayna açılınca müzik dışındaki parçaların yerini kaplar; ✕ ya da çentiği kapatmak küçültür.
struct HomeView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var mirror: CameraMirror
    let services: AppServices

    init(viewModel: NotchViewModel, services: AppServices) {
        self.viewModel = viewModel
        self.services = services
        settings = services.settings
        mirror = services.mirror
    }

    private var layout: [HomeWidget] { settings.homeLayout }
    private var hasMedia: Bool { layout.contains(.media) }

    /// Takvim / anımsatıcı sütun genişliği. İkisi birden müzikle yan yanaysa daralır ki toplam çentiğe sığsın;
    /// müzik yoksa kalan alanı paylaşırlar (`nil`).
    private var sideColumnWidth: CGFloat? {
        guard hasMedia else { return nil }
        let sideCount = layout.filter { $0 == .calendar || $0 == .reminders }.count
        return sideCount >= 2 ? Self.narrowSideWidth : Self.sideWidth
    }
    static let sideWidth: CGFloat = 160
    static let narrowSideWidth: CGFloat = 118
    /// Müzik çaların küçülebileceği en dar genişlik (kapak + kontroller).
    static let minMediaWidth: CGFloat = 180

    private var isMirrorLarge: Bool {
        layout.contains(.mirror) && (mirror.state == .running || mirror.state == .starting)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if layout.isEmpty {
                emptyHint
            } else if isMirrorLarge {
                if hasMedia { media }
                MirrorView(mirror: mirror, isLarge: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4, anchor: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.4, anchor: .trailing).combined(with: .opacity)))
            } else {
                ForEach(Array(layout.enumerated()), id: \.element) { index, widget in
                    if index > 0, widget != .mirror, layout[index - 1] != .mirror { divider }
                    view(for: widget)
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isMirrorLarge)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: layout)
        .onChange(of: layout.contains(.mirror)) { _, isShown in
            if !isShown { mirror.stop() }
        }
    }

    @ViewBuilder
    private func view(for widget: HomeWidget) -> some View {
        switch widget {
        case .media:
            media
        case .calendar:
            CalendarListView(service: services.calendar)
                .frame(width: sideColumnWidth)
                .frame(maxWidth: sideColumnWidth == nil ? .infinity : nil)
                .transition(.opacity)
        case .reminders:
            HomeRemindersView(service: services.reminders, settings: settings)
                .frame(width: sideColumnWidth, alignment: .leading)
                .frame(maxWidth: sideColumnWidth == nil ? .infinity : nil, alignment: .leading)
                .transition(.opacity)
        case .mirror:
            MirrorView(mirror: mirror, isLarge: false)
                .frame(width: MirrorView.smallSize)
                .frame(maxHeight: .infinity)
        }
    }

    private var media: some View {
        MediaPlayerView(media: services.media)
            .frame(minWidth: Self.minMediaWidth, maxWidth: .infinity)
    }

    private var emptyHint: some View {
        Text("Ana ekran boş: Ayarlar › Etkinlikler › Ana Ekran")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1).padding(.vertical, 4)
    }
}
