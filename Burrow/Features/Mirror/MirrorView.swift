import SwiftUI

/// Kamera aynası. Küçükken dokun → açılır ve büyür; büyükken ✕ → kapanır, küçük hâline döner.
struct MirrorView: View {
    @ObservedObject var mirror: CameraMirror
    let isLarge: Bool

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: isLarge ? 20 : 16, style: .continuous) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button { if !isLarge { mirror.start() } } label: {
                ZStack {
                    shape.fill(Color.white.opacity(0.08))
                    switch mirror.state {
                    case .running:
                        CameraPreview(session: mirror.session).clipShape(shape)
                    case .starting:
                        ProgressView().controlSize(.small)
                    case .denied:
                        label(symbol: "video.slash.fill", text: "İzin yok")
                    case .unavailable:
                        label(symbol: "video.slash", text: "Kamera yok")
                    case .off:
                        label(symbol: "person.crop.square", text: "Ayna")
                    }
                }
                .frame(width: isLarge ? nil : 84, height: isLarge ? nil : 84)
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .help(isLarge ? "" : "Kamera aynası")

            if isLarge {
                Button { mirror.stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.ultraThinMaterial))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Aynayı kapat")
            }
        }
    }

    private func label(symbol: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
            Text(text).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.6))
    }
}
