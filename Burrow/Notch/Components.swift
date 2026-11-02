import SwiftUI

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Çalarken dalgalanan çubuklar. Gerçek ses analizi değildir (izin gerektirmez, CPU harcamaz).
struct EqualizerView: View {
    let isPlaying: Bool
    let color: Color
    private let barCount = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: barHeight(index: index, time: t))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.12), value: t)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 3 }
        let speeds: [Double] = [5.1, 7.3, 4.2, 6.4]
        let phase = sin(time * speeds[index % speeds.count] + Double(index) * 1.7)
        return CGFloat(4 + (phase + 1) / 2 * 10)
    }
}

struct LevelBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule().fill(Color.white)
                    .frame(width: proxy.size.width * CGFloat(min(1, max(0, value))))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: value)
    }
}

struct BatteryGlyph: View {
    let percent: Int
    let isCharging: Bool

    private var fillColor: Color {
        if isCharging { return .green }
        return percent <= 20 ? .red : .white
    }

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(2, 18 * CGFloat(percent) / 100))
                    .padding(1.5)
            }
            .frame(width: 22, height: 11)
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.5)).frame(width: 1.5, height: 4)
        }
    }
}

enum HUDSymbol {
    static func name(for kind: HUDKind, value: Double) -> String {
        switch kind {
        case .brightness:
            return value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume(let muted):
            if muted || value <= 0.001 { return "speaker.slash.fill" }
            if value < 0.33 { return "speaker.wave.1.fill" }
            if value < 0.66 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        }
    }
}

enum DeviceSymbol {
    static func name(for deviceName: String) -> String {
        let lower = deviceName.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") || lower.contains("headphone") || lower.contains("kulaklık") || lower.contains("buds") {
            return "headphones"
        }
        if lower.contains("keyboard") || lower.contains("klavye") { return "keyboard" }
        if lower.contains("mouse") || lower.contains("fare") { return "computermouse" }
        if lower.contains("trackpad") { return "rectangle.and.hand.point.up.left" }
        if lower.contains("speaker") || lower.contains("hoparlör") { return "hifispeaker.fill" }
        return "dot.radiowaves.left.and.right"
    }
}
