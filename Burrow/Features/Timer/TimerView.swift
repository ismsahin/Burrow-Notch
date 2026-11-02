import SwiftUI

/// "Süre" sekmesi: geri sayım (zamanlayıcı) ve saat alarmları.
struct TimeToolsView: View {
    let timer: TimerService
    let alarms: AlarmService
    @State private var mode = 0

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $mode) {
                Text("Geri sayım").tag(0)
                Text("Alarm").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            .colorScheme(.dark)
            if mode == 0 { TimerView(timer: timer) } else { AlarmView(service: alarms) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Geri sayım: hazır süreler, çalışan zamanlayıcı, +1 dk / iptal.
struct TimerView: View {
    @ObservedObject var timer: TimerService
    @State private var customMinutes = 20

    var body: some View {
        if let end = timer.endsAt {
            running(end)
        } else {
            picker
        }
    }

    private func running(_ end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date))
            HStack(spacing: 22) {
                ProgressRing(progress: timer.total > 0 ? 1 - remaining / timer.total : 0, color: .orange)
                    .frame(width: 70, height: 70)
                    .overlay(Image(systemName: "timer").font(.system(size: 20, weight: .semibold)).foregroundStyle(.orange))
                VStack(alignment: .leading, spacing: 4) {
                    Text(TimerService.remainingText(until: end, now: context.date))
                        .font(.system(size: 34, weight: .semibold).monospacedDigit())
                    Text("Bitiş \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                VStack(spacing: 8) {
                    pill("+1 dk", symbol: "plus") { timer.extend(by: 60) }
                    pill("İptal", symbol: "xmark", tint: .red) { timer.cancel() }
                }
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(TimerService.presets, id: \.self) { minutes in
                    pill("\(minutes) dk") { timer.start(minutes: minutes) }
                }
            }
            HStack(spacing: 10) {
                Stepper(value: $customMinutes, in: 1...240) {
                    Text("Özel: \(customMinutes) dk").font(.system(size: 12, weight: .medium).monospacedDigit())
                }
                .fixedSize()
                pill("Başlat", symbol: "play.fill", tint: .orange) { timer.start(minutes: customMinutes) }
                Spacer()
            }
            Text("Kalan süre kapalı çentikte görünür; bitince ses çalar.")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
        }
    }

    private func pill(_ title: String, symbol: String? = nil, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .bold)) }
                Text(title).font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint == .white ? .white : tint)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
