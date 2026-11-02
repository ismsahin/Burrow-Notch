import SwiftUI

/// "Anımsatıcılar" sekmesi: tamamlanmamışlar; daireye tıkla → tamamlandı.
struct RemindersView: View {
    @ObservedObject var service: ReminderService

    var body: some View {
        Group {
            switch service.access {
            case .granted:
                if service.items.isEmpty {
                    message(symbol: "checkmark.circle", title: "Tüm anımsatıcılar tamam 🎉")
                } else {
                    list
                }
            case .unknown:
                VStack(spacing: 8) {
                    message(symbol: "checklist", title: "Anımsatıcılarını burada gör")
                    Button("Anımsatıcılara erişim ver") { service.requestAccess() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            case .denied:
                message(symbol: "lock", title: "İzin yok: Sistem Ayarları › Gizlilik › Anımsatıcılar")
            }
        }
        .onAppear { service.reload() }
    }

    private var list: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 6) {
                ForEach(service.items) { item in
                    ReminderRow(item: item) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { service.complete(item) }
                    }
                }
            }
        }
    }

    private func message(symbol: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 20))
            Text(title).font(.system(size: 11, weight: .semibold)).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.6))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReminderRow: View {
    let item: ReminderItem
    let onComplete: () -> Void
    @State private var isHovering = false

    private var dueText: String? {
        guard let due = item.due else { return nil }
        if due < .now { return "Gecikti · " + due.formatted(date: .abbreviated, time: .shortened) }
        return Calendar.current.isDateInToday(due) ? "Bugün " + due.formatted(date: .omitted, time: .shortened)
            : due.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onComplete) {
                Image(systemName: isHovering ? "checkmark.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(nsColor: item.color))
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .help("Tamamlandı olarak işaretle")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    if item.isFlagged { Image(systemName: "flag.fill").font(.system(size: 8)).foregroundStyle(.orange) }
                    Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                }
                if let dueText {
                    Text(dueText).font(.system(size: 9))
                        .foregroundStyle((item.due ?? .distantFuture) < .now ? .red : .white.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
