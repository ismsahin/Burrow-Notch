import SwiftUI

/// Kapalı çentik: ortada fiziksel çentik boşluğu, iki yanda canlı etkinlik.
struct CompactNotchView: View {
    let activity: LiveActivity
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var media: MediaController
    let services: AppServices

    init(activity: LiveActivity, viewModel: NotchViewModel, services: AppServices) {
        self.activity = activity
        self.viewModel = viewModel
        self.services = services
        media = services.media
    }

    private var sideWidth: CGFloat { activity.extraWidth / 2 }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: sideWidth, alignment: .leading)
                .padding(.leading, sideWidth > 0 ? 8 : 0)
            Spacer(minLength: viewModel.geometry.notchSize.width - (sideWidth > 0 ? 16 : 0))
            trailing
                .frame(width: sideWidth, alignment: .trailing)
                .padding(.trailing, sideWidth > 0 ? 8 : 0)
        }
        .frame(height: viewModel.geometry.notchSize.height)
        .foregroundStyle(.white)
        .clipped()
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .none:
            EmptyView()
        case .media:
            ArtworkView(image: media.artwork, size: 22, cornerRadius: 6)
        case .charging(_, let isCharging):
            Image(systemName: isCharging ? "bolt.fill" : "powerplug")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCharging ? .green : .white.opacity(0.8))
        case .lowBattery:
            Image(systemName: "battery.25")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.red)
        case .hud(let kind, let value):
            Image(systemName: HUDSymbol.name(for: kind, value: value))
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22)
        case .device(let name, let connected):
            HStack(spacing: 6) {
                Image(systemName: DeviceSymbol.name(for: name))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(connected ? .blue : .white.opacity(0.6))
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case .none:
            EmptyView()
        case .media:
            EqualizerView(isPlaying: media.isPlaying, color: Color(nsColor: media.artworkColor))
                .frame(width: 22, height: 14)
        case .charging(let percent, let isCharging):
            HStack(spacing: 4) {
                Text("%\(percent)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                BatteryGlyph(percent: percent, isCharging: isCharging)
            }
        case .lowBattery(let percent):
            Text("%\(percent)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.red)
        case .hud(_, let value):
            LevelBar(value: value)
                .frame(width: 60, height: 5)
        case .device(_, let connected):
            Text(connected ? "Bağlandı" : "Ayrıldı")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
