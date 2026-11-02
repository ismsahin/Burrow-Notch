import SwiftUI

/// "Anımsatıcılar" sekmesi: üstte liste (kategori) seçimi, altında o listenin tamamlanmamışları; daireye tıkla → tamamlandı.
struct RemindersView: View {
    @ObservedObject var service: ReminderService
    @ObservedObject var settings: AppSettings

    private var selectedListID: String? { ReminderService.resolvedListID(settings.reminderListID, lists: service.lists) }
    private var visibleItems: [ReminderItem] { ReminderService.items(service.items, inList: selectedListID) }

    var body: some View {
        Group {
            switch service.access {
            case .granted:
                VStack(alignment: .leading, spacing: 8) {
                    if service.lists.count > 1 { listPicker }
                    if visibleItems.isEmpty {
                        message(symbol: "checkmark.circle", title: "Bu listede her şey tamam 🎉")
                    } else {
                        list
                    }
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

    private var listPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(service.lists) { list in
                    chip(title: list.title, color: Color(nsColor: list.color),
                         count: ReminderService.items(service.items, inList: list.id).count,
                         isSelected: selectedListID == list.id) { settings.reminderListID = list.id }
                }
                chip(title: "Tümü", color: .white, count: service.items.count, isSelected: selectedListID == nil) {
                    settings.reminderListID = ReminderService.allListsID
                }
            }
        }
    }

    private func chip(title: String, color: Color, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).lineLimit(1)
                Text("\(count)").foregroundStyle(.white.opacity(0.45)).monospacedDigit()
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(isSelected ? 0.18 : 0.06)))
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private var list: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 6) {
                ForEach(visibleItems) { item in
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

/// Ana sekmedeki küçük anımsatıcı parçası: seçili listeden ilk birkaç öğe.
struct HomeRemindersView: View {
    @ObservedObject var service: ReminderService
    @ObservedObject var settings: AppSettings
    private static let maxRows = 4

    private var selectedList: ReminderList? {
        let id = ReminderService.resolvedListID(settings.reminderListID, lists: service.lists)
        return service.lists.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(selectedList?.title ?? "Anımsatıcılar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selectedList.map { Color(nsColor: $0.color) } ?? .white.opacity(0.7))
                .lineLimit(1)
            switch service.access {
            case .granted:
                let items = ReminderService.items(service.items, inList: selectedList?.id)
                if items.isEmpty {
                    Text("Her şey tamam").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                } else {
                    ForEach(items.prefix(Self.maxRows)) { item in
                        ReminderRow(item: item) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { service.complete(item) }
                        }
                    }
                }
            case .unknown:
                Button("Erişim ver") { service.requestAccess() }
                    .buttonStyle(.plain).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.accentColor)
            case .denied:
                Text("İzin yok").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .onAppear { service.reload() }
    }
}

struct ReminderRow: View {
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
