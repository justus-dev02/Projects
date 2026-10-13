import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// A minimal snapshot testing helper built on `ImageRenderer`, so the package needs no
/// third-party dependency.
///
/// - Reference images live next to the tests in `__Snapshots__/<name>.png`.
/// - Missing references are recorded and the test fails once, so new snapshots get reviewed.
/// - `SNAPSHOT_RECORD=1` re-records all references.
/// - `PROJECTS_SKIP_SNAPSHOTS=1` skips the comparison. Text rendering differs between macOS
///   versions, so CI runners with a different OS than the recording machine set this flag.
enum Snapshot {
    nonisolated static var isSkipped: Bool {
        ProcessInfo.processInfo.environment["PROJECTS_SKIP_SNAPSHOTS"] == "1"
    }

    static func verify(
        _ view: some View,
        named name: String,
        size: CGSize,
        colorScheme: ColorScheme = .light,
        tolerance: Double = 0.01,
        filePath: String = #filePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let content = view
            .frame(width: size.width, height: size.height)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.cgImage else {
            Issue.record("Rendering \(name) failed", sourceLocation: sourceLocation)
            return
        }

        let directory = URL(filePath: filePath).deletingLastPathComponent().appending(path: "__Snapshots__")
        #if os(macOS)
        let platform = "macOS"
        #else
        let platform = "iOS"
        #endif
        // Rendering differs per platform, so every platform has its own reference image.
        let referenceURL = directory.appending(path: "\(name)-\(platform).png")
        let record = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"

        if record || !FileManager.default.fileExists(atPath: referenceURL.path()) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try writePNG(image, to: referenceURL)
            Issue.record("Recorded snapshot \(name). Review it and run the tests again.", sourceLocation: sourceLocation)
            return
        }

        guard let reference = loadImage(at: referenceURL) else {
            Issue.record("Could not read reference \(name)", sourceLocation: sourceLocation)
            return
        }
        let difference = differingPixelRatio(image, reference)
        if difference > tolerance {
            let failureURL = URL.temporaryDirectory.appending(path: "\(name)-actual.png")
            try? writePNG(image, to: failureURL)
            Issue.record(
                "Snapshot \(name) differs in \(Int(difference * 100)) % of pixels. Actual image: \(failureURL.path())",
                sourceLocation: sourceLocation
            )
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    private static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Fraction of pixels whose RGBA channels differ by more than a small threshold.
    /// Returns 1 when the sizes differ.
    private static func differingPixelRatio(_ lhs: CGImage, _ rhs: CGImage) -> Double {
        guard lhs.width == rhs.width, lhs.height == rhs.height else { return 1 }
        let left = rgbaBytes(of: lhs)
        let right = rgbaBytes(of: rhs)
        var differing = 0
        for pixel in stride(from: 0, to: left.count, by: 4) {
            for channel in 0..<4 where abs(Int(left[pixel + channel]) - Int(right[pixel + channel])) > 10 {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(lhs.width * lhs.height)
    }

    private static func rgbaBytes(of image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }
}
