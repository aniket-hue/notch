import AppKit
import SwiftUI

enum OIcon: String {
    case logo
    case settings, appearance, widgets, clipboard, info
    case note, play, pause, next, prev
    case trash
    case chevronLeft = "chevron-left"
    case chevronRight = "chevron-right"
    case check
    case calendar
    case calendarClear = "calendar-clear"
    case lock, video, grip, git, eye, copy, open, tray, stack
    case package, archive, folders
    case boxArrowDown = "box-arrow-down"
    case cardsThree = "cards-three"
    case eyeSlash = "eye-slash"
    case checkCircle = "check-circle"
    case xCircle = "x-circle"
}

struct Icon: View {
    let icon: OIcon
    var size: CGFloat

    init(_ icon: OIcon, size: CGFloat = 16, weight _: CGFloat = 2) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        if icon == .logo {
            NotchMark().frame(width: size, height: size)
        } else {
            Image(nsImage: IconStore.image(icon))
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }

    @MainActor
    static func menuBarImage() -> NSImage {
        let renderer = ImageRenderer(content: NotchMark().frame(width: 16, height: 14).foregroundStyle(.black))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 16, height: 14))
        image.isTemplate = true
        return image
    }
}

struct NotchMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(3, 5))
        path.addLine(to: p(21, 5))
        path.addLine(to: p(21, 10))
        path.addQuadCurve(to: p(15.5, 16), control: p(21, 16))
        path.addLine(to: p(8.5, 16))
        path.addQuadCurve(to: p(3, 10), control: p(3, 16))
        path.closeSubpath()
        return path
    }
}

enum IconStore {
    @MainActor private static var cache: [OIcon: NSImage] = [:]

    @MainActor
    static func image(_ icon: OIcon) -> NSImage {
        if let cached = cache[icon] { return cached }
        let img = load(icon.rawValue)
        cache[icon] = img
        return img
    }

    private static func load(_ name: String) -> NSImage {
        let url = Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "Icons")
            ?? Bundle.main.url(forResource: name, withExtension: "pdf")
        if let url, let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            return img
        }
        return NSImage(size: NSSize(width: 24, height: 24))
    }
}
