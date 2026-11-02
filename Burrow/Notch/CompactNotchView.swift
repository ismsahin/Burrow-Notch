import SwiftUI

/// Kapalı çentik: ortada fiziksel çentik (ya da ada gövdesi), iki yanda canlı etkinlik.
/// Birden fazla kalıcı etkinlik varsa sağ altta sayfa noktaları çıkar; kaydırarak geçilir.
struct CompactNotchView: View {
    let activity: LiveActivity
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var media: MediaController
    @ObservedObject var center: ActivityCenter
    let services: AppServices

    init(activity: LiveActivity, viewModel: NotchViewModel, services: AppServices) {
        self.activity = activity
        self.viewModel = viewModel
        self.services = services
        media = services.media
        center = services.activity
    }

    private var isLargeHUD: Bool { viewModel.isLargeHUD(activity) }
    private var sideWidth: CGFloat { (isLargeHUD ? 120 : activity.extraWidth) / 2 }
    private var sidePadding: CGFloat { sideWidth > 0 ? 8 : 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leading
                    .frame(width: max(0, sideWidth - sidePadding), alignment: .leading)
                    .padding(.leading, sidePadding)
                Spacer(minLength: viewModel.centerWidth)
                trailing
                    .frame(width: max(0, sideWidth - sidePadding), alignment: .trailing)
                    .padding(.trailing, sidePadding)
            }
            .frame(height: viewModel.barHeight)
            if isLargeHUD, case .hud(let kind, let value) = activity {
                LargeHUDRow(kind: kind, value: value)
                    .frame(height: NotchViewModel.largeHUDExtraHeight)
                    .padding(.horizontal, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if case .notification(let entry) = activity {
                NotificationRow(entry: entry, compact: true)
                    .frame(height: NotchViewModel.notificationCardHeight, alignment: .top)
                    .padding(.horizontal, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .foregroundStyle(.white)
        .clipped()
    }

    // MARK: - Sol

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .none:
            EmptyView()
        case .media:
            ArtworkView(image: media.artwork, size: min(22, viewModel.barHeight - 4), cornerRadius: 5)
        case .download(_, _, let count):
            ZStack(alignment: .topTrailing) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                if count > 1 {
                    Text("\(count)").font(.system(size: 8, weight: .bold)).padding(2)
                        .background(Circle().fill(.red)).offset(x: 5, y: -4)
                }
            }
        case .calendar(let title, _):
            HStack(spacing: 5) {
                Image(systemName: "calendar").font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
                Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
        case .timer:
            Image(systemName: "timer").font(.system(size: 13, weight: .semibold)).foregroundStyle(.orange)
        case .notifications(let appID, _):
            AppIcon(bundleID: appID, size: min(20, viewModel.barHeight - 6))
        case .notification(let entry):
            HStack(spacing: 6) {
                AppIcon(bundleID: entry.appID, size: min(18, viewModel.barHeight - 8))
                Text(AppIconCache.name(for: entry.appID)).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
        case .charging(_, let isCharging):
            Image(systemName: isCharging ? "bolt.fill" : "powerplug")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCharging ? .green : .white.opacity(0.8))
        case .lowBattery:
            Image(systemName: "battery.25").font(.system(size: 14, weight: .semibold)).foregroundStyle(.red)
        case .hud(let kind, let value):
            if !isLargeHUD {
                Image(systemName: HUDSymbol.name(for: kind, value: value))
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 22)
            }
        case .device(let name, let connected, _):
            HStack(spacing: 6) {
                Image(systemName: DeviceSymbol.name(for: name))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(connected ? .blue : .white.opacity(0.6))
                Text(name).font(.system(size: 11, weight: .semibold)).lineLimit(1).truncationMode(.tail)
            }
        case .notice(let symbol, let title, _):
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(.green)
                Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
        }
    }

    // MARK: - Sağ

    @ViewBuilder
    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 2) {
            trailingContent
            if center.current.kind != nil, center.carousel.count > 1 {
                PageDots(count: center.carousel.count, selected: center.carousel.selectedIndex ?? 0)
            }
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch activity {
        case .none:
            EmptyView()
        case .media:
            EqualizerView(isPlaying: media.isPlaying, color: Color(nsColor: media.artworkColor))
                .frame(width: 22, height: 14)
        case .download(_, let progress, _):
            HStack(spacing: 5) {
                Text("%\(Int((progress * 100).rounded()))").font(.system(size: 10, weight: .semibold).monospacedDigit())
                ProgressRing(progress: progress, color: .blue).frame(width: 16, height: 16)
            }
        case .calendar(_, let start):
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(CalendarCountdown.text(until: start, now: context.date))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.orange)
            }
        case .timer(let end, let total):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 5) {
                    Text(TimerService.remainingText(until: end, now: context.date))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    ProgressRing(progress: total > 0 ? 1 - max(0, end.timeIntervalSince(context.date)) / total : 0, color: .orange)
                        .frame(width: 14, height: 14)
                }
            }
        case .charging(let percent, let isCharging):
            HStack(spacing: 4) {
                Text("%\(percent)").font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .lineLimit(1).fixedSize()
                BatteryGlyph(percent: percent, isCharging: isCharging)
            }
        case .lowBattery(let percent):
            Text("%\(percent)").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(.red)
        case .hud(_, let value):
            if !isLargeHUD { LevelBar(value: value).frame(width: 60, height: 5) }
        case .device(_, let connected, let battery):
            if let battery, connected {
                Text(battery.summary)
                    .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle((battery.lowest ?? 100) <= 20 ? .red : .green)
                    .lineLimit(1)
            } else {
                Text(connected ? "Bağlandı" : "Ayrıldı")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        case .notice(_, _, let detail):
            Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
        case .notifications(_, let count):
            Text("\(count)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Color.red))
        case .notification:
            Image(systemName: "bell.badge.fill").font(.system(size: 11)).foregroundStyle(.red, .white.opacity(0.8))
        }
    }
}

/// Büyük HUD satırı: simge + kalın çubuk + yüzde (çentiğin altında).
private struct LargeHUDRow: View {
    let kind: HUDKind
    let value: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: HUDSymbol.name(for: kind, value: value))
                .font(.system(size: 14, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22)
            LevelBar(value: value).frame(height: 7)
            Text("\(Int((value * 100).rounded()))")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .frame(width: 26, alignment: .trailing)
        }
    }
}

struct PageDots: View {
    let count: Int
    let selected: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index == selected ? 0.9 : 0.3))
                    .frame(width: index == selected ? 7 : 3, height: 3)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }
}

struct ProgressRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeOut(duration: 0.3), value: progress)
    }
}

enum CalendarCountdown {
    /// "12 dk", "1 sa 5 dk", "Şimdi"
    static func text(until start: Date, now: Date = Date()) -> String {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        if minutes <= 0 { return "Şimdi" }
        if minutes < 60 { return "\(minutes) dk" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) sa" : "\(hours) sa \(rest) dk"
    }
}
