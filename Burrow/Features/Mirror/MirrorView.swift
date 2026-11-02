import SwiftUI

/// Dokununca açılan küçük kamera aynası.
struct MirrorView: View {
    @ObservedObject var mirror: CameraMirror

    var body: some View {
        Button { mirror.toggle() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                switch mirror.state {
                case .running:
                    CameraPreview(session: mirror.session)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .frame(width: 84, height: 84)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Kamera aynası")
    }

    private func label(symbol: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
            Text(text).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.6))
    }
}
