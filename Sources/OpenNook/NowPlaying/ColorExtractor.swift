import AppKit
import SwiftUI

enum ColorExtractor {
    static func gradientColors(from image: NSImage) -> [Color] {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }

        let side = 10
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        struct Swatch {
            let hsb: (h: CGFloat, s: CGFloat, b: CGFloat)
            let score: CGFloat
        }

        var swatches: [Swatch] = []
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = CGFloat(pixels[i]) / 255
            let g = CGFloat(pixels[i + 1]) / 255
            let b = CGFloat(pixels[i + 2]) / 255
            let hsb = rgbToHSB(r, g, b)
            swatches.append(Swatch(hsb: hsb, score: hsb.s * hsb.b))
        }

        let ranked = swatches.sorted { $0.score > $1.score }
        guard let primary = ranked.first else { return [] }

        let secondary = ranked.first { abs($0.hsb.h - primary.hsb.h) > 0.08 } ?? primary

        return [tweak(primary.hsb), tweak(secondary.hsb)]
    }

    private static func tweak(_ hsb: (h: CGFloat, s: CGFloat, b: CGFloat)) -> Color {
        Color(hue: hsb.h, saturation: min(1, hsb.s * 1.1), brightness: max(0.5, hsb.b))
    }

    private static func rgbToHSB(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        let maxc = max(r, g, b)
        let minc = min(r, g, b)
        let delta = maxc - minc
        var h: CGFloat = 0
        if delta != 0 {
            if maxc == r { h = (g - b) / delta }
            else if maxc == g { h = 2 + (b - r) / delta }
            else { h = 4 + (r - g) / delta }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s = maxc == 0 ? 0 : delta / maxc
        return (h, s, maxc)
    }
}
