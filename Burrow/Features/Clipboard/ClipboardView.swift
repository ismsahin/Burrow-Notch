import ImageIO
import SwiftUI

/// "Pano" sekmesi: kopyalama geçmişi, kategori filtreleri, yıldız, arama. Tıkla → tekrar kopyalanır.
struct ClipboardView: View {
    @ObservedObject var store: ClipboardStore
    @State private var filter: ClipboardFilter = .all
    @State private var query = ""
    @State private var copiedID: UUID?

    private var visible: [ClipboardItem] { ClipboardLogic.filtered(store.items, by: filter, query: query) }

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            if visible.isEmpty {
                empty
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(visible) { item in
                            ClipCard(item: item, store: store, isCopied: copiedID == item.id) {
                                store.copy(item)
                                copiedID = item.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    if copiedID == item.id { copiedID = nil }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            chip("Tümü", symbol: "tray.full", value: .all)
            chip("Yıldızlı", symbol: "star.fill", value: .starred)
            ForEach(ClipboardItem.Kind.allCases) { kind in
                chip(kind.title, symbol: kind.symbol, value: .kind(kind))
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 9))
                TextField("Ara", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10.5))
                    .frame(width: 70)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            Button { store.clearUnstarred() } label: { Image(systemName: "trash").font(.system(size: 10)) }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.6))
                .help("Yıldızsızları temizle")
        }
    }

    private func chip(_ title: String, symbol: String, value: ClipboardFilter) -> some View {
        let selected = filter == value
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { filter = value } } label: {
            HStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 8.5, weight: .semibold))
                if selected { Text(title).font(.system(size: 10, weight: .semibold)) }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(selected ? 0.18 : 0.05)))
            .foregroundStyle(.white.opacity(selected ? 1 : 0.6))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: filter == .starred ? "star" : "doc.on.clipboard").font(.system(size: 20))
            Text(filter == .starred ? "Yıldızlı öğe yok" : "Kopyaladıkların burada birikir")
                .font(.system(size: 11, weight: .semibold))
            Text("Parola yöneticilerinin kopyaladıkları kaydedilmez.")
                .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white.opacity(0.7))
    }
}

private struct ClipCard: View {
    let item: ClipboardItem
    let store: ClipboardStore
    let isCopied: Bool
    let onCopy: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: item.kind.symbol).font(.system(size: 9, weight: .semibold))
                    Text(item.date, style: .relative).font(.system(size: 8.5)).lineLimit(1)
                    Spacer(minLength: 0)
                    Button { store.toggleStar(item) } label: {
                        Image(systemName: item.isStarred ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundStyle(item.isStarred ? .yellow : .white.opacity(isHovering ? 0.7 : 0.25))
                    }
                    .buttonStyle(.plain)
                    .help(item.isStarred ? "Yıldızı kaldır" : "Yıldızla")
                }
                .foregroundStyle(.white.opacity(0.5))
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(width: 132, height: 92)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(isHovering ? 0.12 : 0.06)))
            .overlay {
                if isCopied {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.6))
                    Label("Kopyalandı", systemImage: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.green)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Kopyala") { onCopy() }
            Button(item.isStarred ? "Yıldızı Kaldır" : "Yıldızla") { store.toggleStar(item) }
            if item.kind == .link, let text = item.text, let url = URL(string: text) {
                Button("Tarayıcıda Aç") { NSWorkspace.shared.open(url) }
            }
            Divider()
            Button("Sil") { store.remove(item) }
        }
        .help(item.text ?? "Resim")
    }

    @ViewBuilder
    private var preview: some View {
        if let url = store.imageURL(for: item), let image = ClipThumbnails.thumbnail(for: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else if item.kind == .media, let paths = item.text {
            let first = paths.split(separator: "\n").first.map(String.init) ?? paths
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first)).resizable().frame(width: 30, height: 30)
                Text((first as NSString).lastPathComponent).font(.system(size: 10, weight: .medium)).lineLimit(3)
            }
        } else {
            Text(item.text ?? "")
                .font(.system(size: 10.5, weight: item.kind == .link ? .medium : .regular))
                .foregroundStyle(item.kind == .link ? Color.accentColor : .white.opacity(0.9))
                .lineLimit(4)
        }
    }
}

/// Küçük resim önbelleği: tam boy PNG her çizimde çözülmesin (üzerine gelince takılma olmasın).
@MainActor
enum ClipThumbnails {
    private static let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 120
        return cache
    }()
    private static let maxPixel = 264

    static func thumbnail(for url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width / 2, height: cg.height / 2))
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
