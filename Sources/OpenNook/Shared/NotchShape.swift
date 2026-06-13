import SwiftUI

/// The classic notch silhouette: flush square top corners (so it melds with the
/// screen edge) and smoothly rounded bottom corners.
struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let r = min(bottomCornerRadius, rect.height / 2, rect.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))            // top-left (flush)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))         // top-right (flush)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))     // down right side
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))     // bottom edge
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}
