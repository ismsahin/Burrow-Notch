import SwiftUI

/// Süre sekmesinin "Alarm" bölümü: alarm listesi + ekleme.
struct AlarmView: View {
    @ObservedObject var service: AlarmService
    @State private var time = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
    @State private var label = ""
    @State private var repeatsDaily = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            addForm.frame(width: 190)
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
            list.frame(maxWidth: .infinity)
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 7) {
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .colorScheme(.dark)
            TextField("Etiket (isteğe bağlı)", text: $label)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .colorScheme(.dark)
            Toggle("Her gün", isOn: $repeatsDaily)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Button {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                service.add(hour: parts.hour ?? 0, minute: parts.minute ?? 0, label: label, repeatsDaily: repeatsDaily)
                label = ""
            } label: {
                Label("Alarm ekle", systemImage: "alarm").font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var list: some View {
        if service.alarms.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "alarm").font(.system(size: 20))
                Text("Alarm yok").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(service.alarms) { alarm in
                        HStack(spacing: 8) {
                            Text(alarm.timeText)
                                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(alarm.isEnabled ? 1 : 0.35))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(alarm.label).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                                Text(alarm.repeatsDaily ? "Her gün" : "Bir kez").font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: { _ in service.toggle(alarm) }))
                                .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                            Button { service.remove(alarm) } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                                .buttonStyle(.plain).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
        }
    }
}
