import SwiftUI

/// "Bildirimler" sekmesi: son bildirimler; tıkla → uygulamayı aç.
struct NotificationsView: View {
    @ObservedObject var service: NotificationCenterService
    let isEnabled: Bool

    var body: some View {
        Group {
            if !isEnabled {
                message(symbol: "bell.slash", title: "Bildirimler kapalı", detail: "Ayarlar › Etkinlikler'den açabilirsin.")
            } else if service.status == .needsAccess {
                VStack(spacing: 8) {
                    message(symbol: "lock.shield", title: "Tam Disk Erişimi gerekiyor",
                            detail: "macOS diğer uygulamaların bildirimlerini yalnızca bu izinle okutur. Listeye Burrow'u ekleyip aç.")
                    Button("Ayarları Aç") { NotificationCenterService.openFullDiskAccessSettings() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            } else if service.recent.isEmpty {
                message(symbol: "bell", title: "Yeni bildirim yok", detail: "Gelen bildirimler önce büyük, sonra küçük görünür.")
            } else {
                list
            }
        }
        .onAppear { service.markAllRead() }
    }

    private var list: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(service.recent.count) bildirim").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button("Temizle") { service.clear() }.buttonStyle(.plain).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(service.recent) { entry in
                        Button { service.open(entry) } label: { NotificationRow(entry: entry) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func message(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 20))
            Text(title).font(.system(size: 11.5, weight: .semibold))
            Text(detail).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.75))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotificationRow: View {
    let entry: NotificationEntry
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AppIcon(bundleID: entry.appID, size: compact ? 26 : 22)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(entry.title).font(.system(size: compact ? 12 : 11, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(entry.date, style: .time).font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                }
                let detail = [entry.subtitle, entry.body].filter { !$0.isEmpty }.joined(separator: " — ")
                if !detail.isEmpty {
                    Text(detail).font(.system(size: compact ? 11 : 10)).foregroundStyle(.white.opacity(0.7))
                        .lineLimit(compact ? 2 : 1)
                }
            }
        }
        .padding(.vertical, compact ? 0 : 3)
        .contentShape(Rectangle())
    }
}

struct AppIcon: View {
    let bundleID: String
    let size: CGFloat

    var body: some View {
        if let image = AppIconCache.icon(for: bundleID) {
            Image(nsImage: image).resizable().frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Color.white.opacity(0.15)).frame(width: size, height: size)
                .overlay(Image(systemName: "bell.fill").font(.system(size: size * 0.45)))
        }
    }
}
