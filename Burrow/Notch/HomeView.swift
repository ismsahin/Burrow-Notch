import SwiftUI

/// Ana sekme: oynatıcı | takvim | ayna
struct HomeView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var settings: AppSettings
    let services: AppServices

    init(viewModel: NotchViewModel, services: AppServices) {
        self.viewModel = viewModel
        self.services = services
        settings = services.settings
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MediaPlayerView(media: services.media)
                .frame(maxWidth: .infinity)
            if settings.showCalendar {
                divider
                CalendarListView(service: services.calendar)
                    .frame(width: 160)
            }
            if settings.enableMirror {
                MirrorView(mirror: services.mirror)
                    .frame(width: 84)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1).padding(.vertical, 4)
    }
}
