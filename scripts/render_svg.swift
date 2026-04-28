#!/usr/bin/swift
import AppKit

guard CommandLine.arguments.count >= 4 else {
    fputs("Usage: render_svg.swift <input.svg> <output.png> <size>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
guard let size = Int(CommandLine.arguments[3]) else {
    fputs("Error: Invalid size\n", stderr)
    exit(1)
}

guard let svgData = try? Data(contentsOf: URL(fileURLWithPath: inputPath)),
      let svgImage = NSImage(data: svgData) else {
    fputs("Error: Failed to load SVG from \(inputPath)\n", stderr)
    exit(1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else {
    fputs("Error: Failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let targetRect = NSRect(x: 0, y: 0, width: size, height: size)
svgImage.draw(in: targetRect, from: .zero, operation: .copy, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Error: Failed to generate PNG\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("Error: Failed to write PNG: \(error)\n", stderr)
    exit(1)
}
