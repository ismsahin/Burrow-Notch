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
                .frame(maxWidth: hasMedia ? 160 : .infinity)
                .transition(.opacity)
        case .reminders:
            HomeRemindersView(service: services.reminders, settings: settings)
                .frame(maxWidth: hasMedia ? 170 : .infinity, alignment: .leading)
                .transition(.opacity)
        case .mirror:
            MirrorView(mirror: mirror, isLarge: false)
                .frame(width: MirrorView.smallSize)
                .frame(maxHeight: .infinity)
        }
    }

    private var media: some View {
        MediaPlayerView(media: services.media).frame(maxWidth: .infinity)
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
