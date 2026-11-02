import SwiftUI

struct CalendarListView: View {
    @ObservedObject var service: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { service.openCalendarApp() } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Date.now, format: .dateTime.day())
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .help("Takvim'i aç")

            switch service.access {
            case .granted:
                if service.items.isEmpty {
                    Text("Yaklaşan etkinlik yok 🎉")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    ForEach(service.items) { EventRow(item: $0) }
                }
            case .unknown:
                Button("Takvime erişim ver") { service.requestAccess() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            case .denied:
                Text("Takvim izni yok. Sistem Ayarları › Gizlilik › Takvimler")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EventRow: View {
    let item: CalendarItem

    private var timeText: String {
        if item.isAllDay { return "Tüm gün" }
        let calendar = Calendar.current
        let time = item.start.formatted(date: .omitted, time: .shortened)
        if item.start <= .now { return "Şimdi" }
        return calendar.isDateInToday(item.start) ? time : "Yarın \(time)"
    }

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(Color(nsColor: item.color)).frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(timeText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
