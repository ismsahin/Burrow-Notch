import SwiftUI

/// Kamera aynası. Küçükken dokun → açılır ve büyür; büyükken ✕ → kapanır, küçük hâline döner.
struct MirrorView: View {
    @ObservedObject var mirror: CameraMirror
    let isLarge: Bool
    /// Küçük hâl yalnızca bir düğme: tıklayınca zaten büyüyor.
    static let smallSize: CGFloat = 44

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: isLarge ? 20 : 12, style: .continuous) }

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
                .frame(width: isLarge ? nil : Self.smallSize, height: isLarge ? nil : Self.smallSize)
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

    @ViewBuilder
    private func label(symbol: String, text: String) -> some View {
        if isLarge {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                Text(text).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.6))
        } else {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .help(text)
        }
    }
}
