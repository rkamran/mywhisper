// Generates a 1024×1024 PNG app icon for MyWhisper.
// Usage: swift scripts/make-icon.swift <output-png-path>

import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <out.png>\n".data(using: .utf8)!)
    exit(2)
}

let outPath = CommandLine.arguments[1]
let canvas: CGFloat = 1024
let cornerRadius: CGFloat = 180  // approximates the macOS Big Sur squircle

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

// ── Background: blue→indigo vertical gradient inside rounded square ─────────
let bgRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
let gradient = NSGradient(colors: [
    NSColor(red: 0.42, green: 0.66, blue: 1.00, alpha: 1.0),
    NSColor(red: 0.20, green: 0.35, blue: 0.86, alpha: 1.0),
    NSColor(red: 0.13, green: 0.20, blue: 0.62, alpha: 1.0)
])!
gradient.draw(in: bgPath, angle: 270)

// ── Subtle inner shine arc on top half ──────────────────────────────────────
NSGraphicsContext.current?.saveGraphicsState()
bgPath.addClip()
let shineRect = NSRect(x: -canvas * 0.2, y: canvas * 0.55, width: canvas * 1.4, height: canvas * 0.8)
let shine = NSBezierPath(ovalIn: shineRect)
NSColor(white: 1.0, alpha: 0.08).setFill()
shine.fill()
NSGraphicsContext.current?.restoreGraphicsState()

// ── Microphone glyph (drawn from primitives, all white) ─────────────────────
NSColor.white.setFill()
NSColor.white.setStroke()

let cx = canvas / 2
let bodyWidth: CGFloat = 320
let bodyHeight: CGFloat = 460
let bodyTopY: CGFloat = canvas * 0.78
let bodyBottomY: CGFloat = bodyTopY - bodyHeight

// Capsule mic body
let bodyRect = NSRect(
    x: cx - bodyWidth / 2,
    y: bodyBottomY,
    width: bodyWidth,
    height: bodyHeight
)
NSBezierPath(roundedRect: bodyRect, xRadius: bodyWidth / 2, yRadius: bodyWidth / 2).fill()

// U-shaped stand (open at top, hugs the lower half of the body)
let standOuterRect = NSRect(
    x: cx - bodyWidth / 2 - 90,
    y: bodyBottomY - 60,
    width: bodyWidth + 180,
    height: bodyHeight * 0.7
)
let standInnerInset: CGFloat = 70
let standInnerRect = standOuterRect.insetBy(dx: standInnerInset, dy: standInnerInset)

let standPath = NSBezierPath()
standPath.appendArc(
    withCenter: NSPoint(x: standOuterRect.midX, y: standOuterRect.midY),
    radius: standOuterRect.width / 2,
    startAngle: 180, endAngle: 360, clockwise: false
)
standPath.line(to: NSPoint(x: standInnerRect.maxX, y: standInnerRect.midY))
standPath.appendArc(
    withCenter: NSPoint(x: standInnerRect.midX, y: standInnerRect.midY),
    radius: standInnerRect.width / 2,
    startAngle: 360, endAngle: 180, clockwise: true
)
standPath.close()
standPath.fill()

// Short vertical neck from bottom of body to top of stand center
let neckRect = NSRect(
    x: cx - 26,
    y: standOuterRect.midY - 10,
    width: 52,
    height: bodyBottomY - standOuterRect.midY + 30
)
NSBezierPath(rect: neckRect).fill()

// Horizontal base line at the bottom
let baseRect = NSRect(x: cx - 180, y: bodyBottomY - 250, width: 360, height: 36)
NSBezierPath(roundedRect: baseRect, xRadius: 18, yRadius: 18).fill()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try pngData.write(to: URL(fileURLWithPath: outPath))
print("✓ wrote \(outPath) (\(pngData.count / 1024) KB)")
