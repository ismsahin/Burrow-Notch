import SwiftUI

/// Ana sekme: oynatıcı | takvim | ayna.
/// Ayna açılınca takvimin yerini kaplar (müzik yarıda, ayna yarıda); ✕ ya da çentiği kapatmak küçültür.
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

    private var isMirrorLarge: Bool {
        settings.enableMirror && (mirror.state == .running || mirror.state == .starting)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MediaPlayerView(media: services.media)
                .frame(maxWidth: .infinity)
            if isMirrorLarge {
                MirrorView(mirror: mirror, isLarge: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4, anchor: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.4, anchor: .trailing).combined(with: .opacity)))
            } else {
                if settings.showCalendar {
                    divider
                    CalendarListView(service: services.calendar)
                        .frame(width: 160)
                        .transition(.opacity)
                }
                if settings.enableMirror {
                    MirrorView(mirror: mirror, isLarge: false)
                        .frame(width: 84)
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isMirrorLarge)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1).padding(.vertical, 4)
    }
}
