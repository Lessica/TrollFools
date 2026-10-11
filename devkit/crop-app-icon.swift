#!/usr/bin/env swift

// Offline App icon masking with Core Graphics and Image I/O. Requires macOS and Swift.
// Usage: devkit/crop-app-icon.swift INPUT.png OUTPUT.png [--size PIXELS] [--mask MASK.png]

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct CropError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

let usage = """
Usage: crop-app-icon.swift INPUT.png OUTPUT.png [--size PIXELS] [--mask MASK.png]

Crop a square PNG to the iOS App icon outline, with transparent, antialiased corners.
The source image is resized proportionally; its existing transparency is preserved.

Options:
  --size PIXELS  Output width and height (default: 128).
  --mask PATH    Square PNG whose alpha channel defines the outline.
                Defaults to app-icon-mask.png beside this script (180 × 180).
  -h, --help     Show this help.

The output size must not exceed the mask's resolution. Use a larger --mask for
larger output. INPUT and OUTPUT may be the same file; PNG writes are atomic.
Always start with the original square artwork to avoid masking edges twice.
"""

struct Options {
    let input: URL
    let output: URL
    let mask: URL
    let size: Int

    init(arguments: [String]) throws {
        var paths: [String] = []
        var size = 128
        var mask = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("app-icon-mask.png")
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--" {
                paths.append(contentsOf: arguments.dropFirst(index + 1))
                break
            }
            if argument == "--size" || argument == "--mask" {
                index += 1
                guard index < arguments.count else {
                    throw CropError(message: "Missing value for \(argument).")
                }
                let value = arguments[index]
                if argument == "--size" {
                    guard let pixels = Int(value), pixels > 0 else {
                        throw CropError(message: "--size must be a positive integer.")
                    }
                    size = pixels
                } else {
                    mask = URL(fileURLWithPath: value)
                }
            } else if argument.hasPrefix("-") {
                throw CropError(message: "Unknown option: \(argument).")
            } else {
                paths.append(argument)
            }
            index += 1
        }
        guard paths.count == 2 else {
            throw CropError(message: "Specify an input PNG and an output PNG.\n\n\(usage)")
        }
        input = URL(fileURLWithPath: paths[0])
        output = URL(fileURLWithPath: paths[1])
        self.mask = mask
        self.size = size
        guard output.pathExtension.lowercased() == "png" else {
            throw CropError(message: "The output filename must end in .png.")
        }
        guard output.standardizedFileURL.resolvingSymlinksInPath() != mask.standardizedFileURL.resolvingSymlinksInPath() else {
            throw CropError(message: "The output must not overwrite the mask.")
        }
    }
}

func loadPNG(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetType(source) as String? == UTType.png.identifier,
          CGImageSourceGetCount(source) == 1,
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw CropError(message: "Cannot read a single-frame PNG: \(url.path)")
    }
    guard image.width == image.height else {
        throw CropError(message: "The image must be square: \(url.path) (\(image.width) × \(image.height)).")
    }
    return image
}

func rgbaPixels(_ image: CGImage, size: Int, colorSpace: CGColorSpace) throws -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    try pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw CropError(message: "Cannot create an RGBA image context.")
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return pixels
}

func crop(_ options: Options) throws {
    let original = try loadPNG(options.input)
    let mask = try loadPNG(options.mask)
    guard options.size <= mask.width else {
        throw CropError(message: "Output size \(options.size) exceeds the mask's \(mask.width) px resolution. Supply a larger --mask.")
    }
    let colorSpace = original.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
        ?? CGColorSpace(name: CGColorSpace.sRGB)!
    var pixels = try rgbaPixels(original, size: options.size, colorSpace: colorSpace)
    let maskPixels = try rgbaPixels(mask, size: options.size, colorSpace: colorSpace)
    let corners = [0, options.size - 1, (options.size - 1) * options.size, options.size * options.size - 1]
    guard corners.allSatisfy({ maskPixels[$0 * 4 + 3] == 0 }),
          maskPixels[((options.size / 2) * options.size + options.size / 2) * 4 + 3] == 255 else {
        throw CropError(message: "The mask must have transparent corners and an opaque center at the requested size.")
    }
    for offset in stride(from: 0, to: pixels.count, by: 4) {
        let alpha = Int(pixels[offset + 3])
        // RGBA contexts premultiply RGB. Restore straight RGB before changing alpha
        // so existing semitransparent artwork does not acquire dark fringes.
        if alpha > 0 && alpha < 255 {
            for component in 0..<3 {
                pixels[offset + component] = UInt8(min(255, (Int(pixels[offset + component]) * 255 + alpha / 2) / alpha))
            }
        }
        pixels[offset + 3] = UInt8((alpha * Int(maskPixels[offset + 3]) + 127) / 255)
    }
    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let output = CGImage(
            width: options.size,
            height: options.size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: options.size * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
          ) else {
        throw CropError(message: "Cannot create the masked image.")
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        throw CropError(message: "Cannot create the PNG encoder.")
    }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CropError(message: "Cannot encode the output PNG.")
    }
    try (data as Data).write(to: options.output, options: .atomic)
    print("Saved \(options.output.path) (\(options.size) × \(options.size), mask: \(options.mask.path))")
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    print(usage)
} else {
    do {
        try crop(Options(arguments: arguments))
    } catch {
        FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}
