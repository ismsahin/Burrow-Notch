#!/usr/bin/env swift
// Burrow uygulama simgesini üretir: koyu yuva + çentik + sıcak ışıma.
// Kullanım: swift scripts/make-icon.swift Burrow/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

let outDir = CommandLine.arguments.dropFirst().first ?? "."
let sizes: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]

func render(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS simge ızgarası: 1024 içinde 824'lük yuvarlak kare
    let inset = s * 0.0977
    let body = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSGradient(colors: [NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.16, alpha: 1),
                        NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.06, alpha: 1)])!
        .draw(in: bodyPath, angle: -90)
    ctx.restoreGState()

    bodyPath.addClip()
    // Yuvadan sızan sıcak ışık
    let glowCenter = CGPoint(x: body.midX, y: body.maxY - body.height * 0.2)
    NSGradient(colors: [NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.25, alpha: 0.75),
                        NSColor(calibratedRed: 0.95, green: 0.3, blue: 0.45, alpha: 0.25),
                        NSColor.clear])!
        .draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: body.width * 0.62, options: [])

    // Çentik (yuva)
    let notchW = body.width * 0.52
    let notchH = body.height * 0.2
    let notch = CGRect(x: body.midX - notchW / 2, y: body.maxY - notchH, width: notchW, height: notchH + notchH)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: notch, xRadius: notchH * 0.7, yRadius: notchH * 0.7).fill()

    // Çentik içinde iki küçük "canlı etkinlik" noktası
    let dot = notchH * 0.32
    NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.35, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: notch.minX + notchH * 0.45, y: body.maxY - notchH * 0.66, width: dot, height: dot)).fill()
    NSColor(calibratedRed: 0.45, green: 0.85, blue: 0.55, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: notch.maxX - notchH * 0.45 - dot, y: body.maxY - notchH * 0.66, width: dot, height: dot)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for (points, scale) in sizes {
    let pixels = points * scale
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try! render(pixels: pixels).write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
    images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("Contents.json"))
print("Simgeler üretildi: \(outDir)")
