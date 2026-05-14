// Generates windows/MyWhisper/Assets/app.ico — a multi-resolution, PNG-compressed
// Windows icon drawn with the same mic-on-blue design as the macOS app.
// Runs on macOS (uses AppKit). Usage: swift windows/scripts/make-icon.swift

import AppKit
import Foundation

// ── Draw the master icon at an arbitrary square size ────────────────────────
func drawMaster(_ canvas: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = canvas / 1024.0  // scale factor; design is authored at 1024
    let bgRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 180 * s, yRadius: 180 * s)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.42, green: 0.66, blue: 1.00, alpha: 1.0),
        NSColor(red: 0.20, green: 0.35, blue: 0.86, alpha: 1.0),
        NSColor(red: 0.13, green: 0.20, blue: 0.62, alpha: 1.0)
    ])!
    gradient.draw(in: bgPath, angle: 270)

    NSColor.white.setFill()

    let cx = canvas / 2
    let bodyWidth: CGFloat = 320 * s
    let bodyHeight: CGFloat = 460 * s
    let bodyTopY: CGFloat = canvas * 0.78
    let bodyBottomY: CGFloat = bodyTopY - bodyHeight

    let bodyRect = NSRect(x: cx - bodyWidth / 2, y: bodyBottomY, width: bodyWidth, height: bodyHeight)
    NSBezierPath(roundedRect: bodyRect, xRadius: bodyWidth / 2, yRadius: bodyWidth / 2).fill()

    let standOuterRect = NSRect(
        x: cx - bodyWidth / 2 - 90 * s,
        y: bodyBottomY - 60 * s,
        width: bodyWidth + 180 * s,
        height: bodyHeight * 0.7
    )
    let standInnerRect = standOuterRect.insetBy(dx: 70 * s, dy: 70 * s)
    let standPath = NSBezierPath()
    standPath.appendArc(
        withCenter: NSPoint(x: standOuterRect.midX, y: standOuterRect.midY),
        radius: standOuterRect.width / 2, startAngle: 180, endAngle: 360, clockwise: false)
    standPath.line(to: NSPoint(x: standInnerRect.maxX, y: standInnerRect.midY))
    standPath.appendArc(
        withCenter: NSPoint(x: standInnerRect.midX, y: standInnerRect.midY),
        radius: standInnerRect.width / 2, startAngle: 360, endAngle: 180, clockwise: true)
    standPath.close()
    standPath.fill()

    let neckRect = NSRect(
        x: cx - 26 * s, y: standOuterRect.midY - 10 * s,
        width: 52 * s, height: bodyBottomY - standOuterRect.midY + 30 * s)
    NSBezierPath(rect: neckRect).fill()

    let baseRect = NSRect(x: cx - 180 * s, y: bodyBottomY - 250 * s, width: 360 * s, height: 36 * s)
    NSBezierPath(roundedRect: baseRect, xRadius: 18 * s, yRadius: 18 * s).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// ── Downscale the 1024 master to a PNG blob of the requested size ────────────
func pngBlob(from master: NSBitmapImageRep, size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx
    _ = master.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                    from: .zero, operation: .copy, fraction: 1.0,
                    respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// ── Pack PNG blobs into a PNG-compressed .ico (Vista+) ──────────────────────
func buildICO(_ images: [(size: Int, png: Data)]) -> Data {
    var data = Data()
    data.append(contentsOf: [0, 0])                       // reserved
    data.append(contentsOf: [1, 0])                       // type = icon
    let count = UInt16(images.count)
    data.append(UInt8(count & 0xFF)); data.append(UInt8(count >> 8))

    var offset = 6 + images.count * 16
    for img in images {
        let dim = img.size >= 256 ? 0 : img.size          // 0 encodes 256
        data.append(UInt8(dim))                           // width
        data.append(UInt8(dim))                           // height
        data.append(0)                                    // palette colors
        data.append(0)                                    // reserved
        data.append(contentsOf: [1, 0])                   // planes
        data.append(contentsOf: [32, 0])                  // bits per pixel
        var len = UInt32(img.png.count).littleEndian
        withUnsafeBytes(of: &len) { data.append(contentsOf: $0) }
        var off = UInt32(offset).littleEndian
        withUnsafeBytes(of: &off) { data.append(contentsOf: $0) }
        offset += img.png.count
    }
    for img in images { data.append(img.png) }
    return data
}

// ── Main ────────────────────────────────────────────────────────────────────
let master = drawMaster(1024)
let sizes = [256, 128, 64, 48, 32, 16]
let images = sizes.map { (size: $0, png: pngBlob(from: master, size: $0)) }
let ico = buildICO(images)

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let outURL = scriptDir
    .deletingLastPathComponent()                 // windows/
    .appendingPathComponent("MyWhisper/Assets/app.ico")
try FileManager.default.createDirectory(
    at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try ico.write(to: outURL)
print("✓ wrote \(outURL.path) (\(ico.count / 1024) KB, \(sizes.count) sizes)")
