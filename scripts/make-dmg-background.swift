#!/usr/bin/env swift
// DMG penceresi arka planı: "Burrow'u Uygulamalar'a sürükle" + ok. 600x380 (@1x) ve 1200x760 (@2x).
// Kullanım: swift scripts/make-dmg-background.swift <çıktı-klasörü>
import AppKit

let outDir = CommandLine.arguments.dropFirst().first ?? "."

func render(scale: CGFloat) -> Data {
    let size = CGSize(width: 600 * scale, height: 380 * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = CGSize(width: 600, height: 380)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let bounds = CGRect(x: 0, y: 0, width: 600, height: 380)

    // Açık zemin: Finder simge etiketlerini koyu yazar, koyu zeminde okunmaz.
    NSGradient(colors: [NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.94, alpha: 1),
                        NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.91, alpha: 1)])!.draw(in: bounds, angle: -90)
    let glow = CGPoint(x: 300, y: 380)
    NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.62, blue: 0.25, alpha: 0.22), .clear])!
        .draw(fromCenter: glow, radius: 0, toCenter: glow, radius: 330, options: [])

    // Ok: uygulama simgesi (x=150) → Uygulamalar (x=450), simge merkezleri y≈190
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 235, y: 190))
    arrow.line(to: CGPoint(x: 355, y: 190))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    NSColor(calibratedWhite: 0.2, alpha: 0.45).setStroke()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: CGPoint(x: 340, y: 205))
    head.line(to: CGPoint(x: 362, y: 190))
    head.line(to: CGPoint(x: 340, y: 175))
    head.lineWidth = 5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    func draw(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: alpha),
            .paragraphStyle: style,
        ]
        NSAttributedString(string: text, attributes: attrs).draw(in: CGRect(x: 0, y: y, width: 600, height: size * 1.5))
    }
    draw("Burrow'u Uygulamalar klasörüne sürükle", y: 312, size: 19, weight: .semibold, alpha: 0.9)
    draw("Sonra bu pencereyi kapatıp diski çıkarabilirsin", y: 48, size: 12, weight: .regular, alpha: 0.55)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try! render(scale: 1).write(to: URL(fileURLWithPath: outDir).appendingPathComponent("dmg-background.png"))
try! render(scale: 2).write(to: URL(fileURLWithPath: outDir).appendingPathComponent("dmg-background@2x.png"))
print("DMG arka planı üretildi: \(outDir)")
