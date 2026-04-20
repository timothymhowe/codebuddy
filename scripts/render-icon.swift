#!/usr/bin/env swift
// Draws a simple text icon: "codepuppy" on a rounded rect, outputs AppIcon.icns.

import AppKit

let repoRoot = FileManager.default.currentDirectoryPath
let outDir = repoRoot + "/Resources"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Rounded-rect background
let inset: CGFloat = 40
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = NSBezierPath(roundedRect: rect, xRadius: 180, yRadius: 180)
NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.24, alpha: 1).setFill()
path.fill()

// Text
let text = "codepuppy"
let fontSize: CGFloat = 150
let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .kern: -2 as NSNumber,
]
let attr = NSAttributedString(string: text, attributes: attrs)
let textSize = attr.size()
let origin = NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2)
attr.draw(at: origin)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("png encode fail\n", stderr); exit(1)
}

let iconsetDir = outDir + "/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
let base = iconsetDir + "/icon_512x512@2x.png"
try png.write(to: URL(fileURLWithPath: base))
print("wrote \(base)")

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
]
for (name, sz) in sizes {
    let p = Process()
    p.launchPath = "/usr/bin/sips"
    p.arguments = ["-z", "\(sz)", "\(sz)", base, "--out", iconsetDir + "/" + name]
    p.standardOutput = Pipe(); p.standardError = Pipe()
    try p.run(); p.waitUntilExit()
}
let ic = Process()
ic.launchPath = "/usr/bin/iconutil"
ic.arguments = ["-c", "icns", iconsetDir, "-o", outDir + "/AppIcon.icns"]
try ic.run(); ic.waitUntilExit()
print("wrote \(outDir)/AppIcon.icns")
