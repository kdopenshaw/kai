#!/usr/bin/env swift

import AppKit
import Foundation

func createIconPNG(size: CGFloat, outputPath: String) {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    // White rounded rect background
    let radius = size * 0.18
    let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                            xRadius: radius, yRadius: radius)
    NSColor.white.setFill()
    path.fill()

    // Blue script x
    let fontSize = size * 0.65
    let font = NSFont(name: "Apple Chancery", size: fontSize)
        ?? NSFont(name: "Snell Roundhand", size: fontSize)
        ?? NSFontManager.shared.convert(.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask)

    let blue = NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: blue
    ]
    let str = NSAttributedString(string: "x", attributes: attrs)
    let strSize = str.size()
    let x = (size - strSize.width) / 2
    let y = (size - strSize.height) / 2 + size * 0.02
    str.draw(at: NSPoint(x: x, y: y))

    img.unlockFocus()

    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: outputPath))
}

func createMenuBarPNG(size: Int, logicalSize: Int, outputPath: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: logicalSize, height: logicalSize)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx

    let fontSize = CGFloat(logicalSize) * 0.85
    let font = NSFont(name: "Apple Chancery", size: fontSize)
        ?? NSFont(name: "Snell Roundhand", size: fontSize)
        ?? NSFontManager.shared.convert(.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black
    ]
    let str = NSAttributedString(string: "x", attributes: attrs)
    let strSize = str.size()
    let x = (CGFloat(logicalSize) - strSize.width) / 2
    let y = (CGFloat(logicalSize) - strSize.height) / 2
    str.draw(at: NSPoint(x: x, y: y))

    ctx.flushGraphics()
    NSGraphicsContext.current = nil

    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: outputPath))
}

// --- Main ---
let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let resources = "\(repo)/Sources/Kai/Resources"
try? FileManager.default.createDirectory(atPath: resources, withIntermediateDirectories: true)

// Menu bar icons (template: black on transparent, macOS tints them)
createMenuBarPNG(size: 18, logicalSize: 18, outputPath: "\(resources)/menubar-icon.png")
createMenuBarPNG(size: 36, logicalSize: 18, outputPath: "\(resources)/menubar-icon@2x.png")
print("Created menu bar icons")

// App icon — create iconset
let iconset = "\(repo)/Kai.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let iconSizes: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (sz, name) in iconSizes {
    createIconPNG(size: sz, outputPath: "\(iconset)/\(name)")
}

// Convert to icns
let icnsPath = "\(repo)/Kai.app/Contents/Resources/AppIcon.icns"
try? FileManager.default.createDirectory(
    atPath: "\(repo)/Kai.app/Contents/Resources",
    withIntermediateDirectories: true
)
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset, "-o", icnsPath]
try? proc.run()
proc.waitUntilExit()
print("Created \(icnsPath)")

// Copy icns to resources for future builds
try? FileManager.default.copyItem(
    atPath: icnsPath,
    toPath: "\(resources)/AppIcon.icns"
)

// Cleanup iconset
try? FileManager.default.removeItem(atPath: iconset)
print("Done!")
