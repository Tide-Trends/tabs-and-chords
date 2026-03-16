#!/usr/bin/env swift
// Generates assets/AppIcon.icns — the Tabs & Chords app bundle icon.
// Run from the repo root: swift scripts/generate_icon.swift
import AppKit

let iconsetDir = "assets/AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let s = CGFloat(size)

    // Create pixel-exact bitmap (no Retina scaling surprises)
    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .calibratedRGB,
        bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0)!
    bitmapRep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    ctx.shouldAntialias = true
    NSGraphicsContext.current = ctx

    // ── Background: dark purple gradient, rounded rect ──────────────────
    let corner = s * 0.22
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                              xRadius: corner, yRadius: corner)
    let gradient = NSGradient(
        colors: [NSColor(red: 0.28, green: 0.14, blue: 0.62, alpha: 1),
                 NSColor(red: 0.09, green: 0.04, blue: 0.28, alpha: 1)],
        atLocations: [0, 1], colorSpace: .genericRGB)!
    gradient.draw(in: bgPath, angle: 90) // light at top, dark at bottom

    // ── Guitar pick (scaled from 18×18 source coords) ───────────────────
    let scale = s / 18.0 * 0.76          // 76 % fill
    let ox = (s - 18.0 * scale) / 2.0   // horizontal centre
    let oy = (s - 18.0 * scale) / 2.0   // vertical centre
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: ox + x * scale, y: oy + y * scale) }

    let pick = NSBezierPath()
    pick.move(to: p(9, 16))
    pick.curve(to: p(3.5, 8.5), controlPoint1: p(4.8, 15),   controlPoint2: p(2.2, 11.6))
    pick.curve(to: p(9, 2),     controlPoint1: p(4.1, 5.1),  controlPoint2: p(6.3, 2.1))
    pick.curve(to: p(14.5, 8.5),controlPoint1: p(11.7, 1.9), controlPoint2: p(13.9, 5.1))
    pick.curve(to: p(9, 16),    controlPoint1: p(15.8, 11.6),controlPoint2: p(13.2, 15))
    pick.close()
    NSColor.white.setFill()
    pick.fill()

    // ── Strings (3 vertical lines through the pick) ──────────────────────
    let lineW = max(0.8, s * 0.018)
    NSColor(red: 0.20, green: 0.10, blue: 0.52, alpha: 1).setStroke()
    for x: CGFloat in [6.2, 9.0, 11.8] {
        let str = NSBezierPath()
        str.move(to: p(x, 5.2))
        str.line(to: p(x, 12.6))
        str.lineWidth = lineW
        str.stroke()
    }

    // ── Sound hole ───────────────────────────────────────────────────────
    let holeRect = NSRect(x: ox + 7.3 * scale, y: oy + 7.2 * scale,
                          width: 3.4 * scale,   height: 3.4 * scale)
    let hole = NSBezierPath(ovalIn: holeRect)
    hole.lineWidth = lineW
    hole.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmapRep.representation(using: .png, properties: [:]) else {
        fatalError("PNG generation failed for size \(size)")
    }
    return png
}

let sizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in sizes {
    let data = drawIcon(size: size)
    let path = "\(iconsetDir)/\(name)"
    try! data.write(to: URL(fileURLWithPath: path))
    print("  \(name)")
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", "-o", "assets/AppIcon.icns", iconsetDir]
try! proc.run()
proc.waitUntilExit()

guard proc.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr); exit(1)
}
try? FileManager.default.removeItem(atPath: iconsetDir)
print("Created assets/AppIcon.icns")
