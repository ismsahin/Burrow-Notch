import SwiftUI
import UniformTypeIdentifiers

/// Raf sekmesi: dosyaları bırak, sürükleyerek geri al, AirDrop ile paylaş.
struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    let isTargeted: Bool

    var body: some View {
        if store.items.isEmpty {
            dropZone
        } else {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(store.items) { ShelfItemView(item: $0, store: store) }
                    }
                    .padding(.horizontal, 2)
                }
                HStack(spacing: 10) {
                    Text("\(store.items.count) öğe · sürükleyerek çıkar")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Button { store.airDrop(store.items) } label: {
                        Label("Tümünü AirDrop'la", systemImage: "airplayaudio")
                    }
                    Button(role: .destructive) { store.clear() } label: {
                        Label("Temizle", systemImage: "trash")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.white.opacity(isTargeted ? 0.7 : 0.22), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(isTargeted ? 0.08 : 0.03)))
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                        .font(.system(size: 22, weight: .medium))
                        .symbolEffect(.bounce, value: isTargeted)
                    Text("Dosyaları buraya bırak")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Geçici cep: dosyalar taşınmaz, sadece burada durur.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    let store: ShelfStore
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 44, height: 44)
            Text(item.name)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 68)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(isHovering ? 0.12 : 0.05)))
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button { store.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8), .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { store.open(item) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Aç") { store.open(item) }
            Button("Finder'da Göster") { store.reveal(item) }
            Button("AirDrop ile Gönder") { store.airDrop([item]) }
            Divider()
            Button("Raftan Kaldır") { store.remove(item) }
        }
        .help(item.url.path)
    }
}
