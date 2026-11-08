import SwiftUI

/// Custom Shape rendering the exact SVG paths of the "日本" brand logo (viewBox 0 0 38 20)
struct AppLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 38.0
        let scaleY = rect.height / 20.0
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)

        // Path 1: Kanji "日" (Nichi / Sun)
        var p1 = Path()
        // Outer box
        p1.move(to: CGPoint(x: 0, y: 1.40081))
        p1.addLine(to: CGPoint(x: 13.7154, y: 1.40081))
        p1.addLine(to: CGPoint(x: 13.7154, y: 18.8795))
        p1.addLine(to: CGPoint(x: 12.0428, y: 18.8795))
        p1.addLine(to: CGPoint(x: 12.0428, y: 2.96888))
        p1.addLine(to: CGPoint(x: 1.60988, y: 2.96888))
        p1.addLine(to: CGPoint(x: 1.60988, y: 18.9841))
        p1.addLine(to: CGPoint(x: 0, y: 18.9841))
        p1.closeSubpath()

        // Center divider
        p1.move(to: CGPoint(x: 1.08719, y: 8.63483))
        p1.addLine(to: CGPoint(x: 12.7536, y: 8.63483))
        p1.addLine(to: CGPoint(x: 12.7536, y: 10.182))
        p1.addLine(to: CGPoint(x: 1.08719, y: 10.182))
        p1.closeSubpath()

        // Bottom horizontal bar
        p1.move(to: CGPoint(x: 1.04538, y: 16.057))
        p1.addLine(to: CGPoint(x: 12.7745, y: 16.057))
        p1.addLine(to: CGPoint(x: 12.7745, y: 17.6251))
        p1.addLine(to: CGPoint(x: 1.04538, y: 17.6251))
        p1.closeSubpath()

        // Path 2: Kanji "本" (Hon / Origin / Book)
        var p2 = Path()
        // Top horizontal crossbar
        p2.move(to: CGPoint(x: 18.5868, y: 4.39059))
        p2.addLine(to: CGPoint(x: 36.8182, y: 4.39059))
        p2.addLine(to: CGPoint(x: 36.8182, y: 5.97957))
        p2.addLine(to: CGPoint(x: 18.5868, y: 5.97957))
        p2.closeSubpath()

        // Lower horizontal accent bar
        p2.move(to: CGPoint(x: 22.7474, y: 13.7154))
        p2.addLine(to: CGPoint(x: 32.4904, y: 13.7154))
        p2.addLine(to: CGPoint(x: 32.4904, y: 15.3043))
        p2.addLine(to: CGPoint(x: 22.7474, y: 15.3043))
        p2.closeSubpath()

        // Center vertical stem
        p2.move(to: CGPoint(x: 26.8453, y: 0))
        p2.addLine(to: CGPoint(x: 28.497, y: 0))
        p2.addLine(to: CGPoint(x: 28.497, y: 19.2141))
        p2.addLine(to: CGPoint(x: 26.8453, y: 19.2141))
        p2.closeSubpath()

        // Left diagonal sweeping branch
        p2.move(to: CGPoint(x: 26.3435, y: 4.91328))
        p2.addLine(to: CGPoint(x: 27.7653, y: 5.37325))
        p2.addCurve(to: CGPoint(x: 25.4654, y: 9.61748), control1: CGPoint(x: 27.138, y: 6.85072), control2: CGPoint(x: 26.3714, y: 8.26546))
        p2.addCurve(to: CGPoint(x: 22.4547, y: 13.2554), control1: CGPoint(x: 24.5594, y: 10.9556), control2: CGPoint(x: 23.5559, y: 12.1682))
        p2.addCurve(to: CGPoint(x: 19.005, y: 15.9107), control1: CGPoint(x: 21.3536, y: 14.3287), control2: CGPoint(x: 20.2037, y: 15.2137))
        p2.addLine(to: CGPoint(x: 18.6705, y: 15.4925))
        p2.addLine(to: CGPoint(x: 18.2523, y: 15.0116))
        p2.addLine(to: CGPoint(x: 17.876, y: 14.6144))
        p2.addCurve(to: CGPoint(x: 20.4267, y: 12.9), control1: CGPoint(x: 18.7541, y: 14.1544), control2: CGPoint(x: 19.6043, y: 13.583))
        p2.addCurve(to: CGPoint(x: 22.7893, y: 10.6001), control1: CGPoint(x: 21.263, y: 12.217), control2: CGPoint(x: 22.0505, y: 11.4504))
        p2.addCurve(to: CGPoint(x: 24.8173, y: 7.86125), control1: CGPoint(x: 23.5419, y: 9.73596), control2: CGPoint(x: 24.2179, y: 8.823))
        p2.addCurve(to: CGPoint(x: 26.3435, y: 4.91328), control1: CGPoint(x: 25.4166, y: 6.8995), control2: CGPoint(x: 25.9254, y: 5.91684))
        p2.closeSubpath()

        // Right diagonal sweeping branch
        p2.move(to: CGPoint(x: 28.9988, y: 4.976))
        p2.addCurve(to: CGPoint(x: 31.1523, y: 8.823), control1: CGPoint(x: 29.5563, y: 6.30015), control2: CGPoint(x: 30.2742, y: 7.58248))
        p2.addCurve(to: CGPoint(x: 34.1003, y: 12.1473), control1: CGPoint(x: 32.0304, y: 10.0496), control2: CGPoint(x: 33.0131, y: 11.1577))
        p2.addCurve(to: CGPoint(x: 37.55, y: 14.4889), control1: CGPoint(x: 35.2014, y: 13.123), control2: CGPoint(x: 36.3513, y: 13.9035))
        p2.addLine(to: CGPoint(x: 37.1318, y: 14.8862))
        p2.addLine(to: CGPoint(x: 36.7137, y: 15.388))
        p2.addLine(to: CGPoint(x: 36.3583, y: 15.8688))
        p2.addCurve(to: CGPoint(x: 32.8667, y: 13.2554), control1: CGPoint(x: 35.1456, y: 15.1859), control2: CGPoint(x: 33.9818, y: 14.3147))
        p2.addCurve(to: CGPoint(x: 29.8769, y: 9.63839), control1: CGPoint(x: 31.7656, y: 12.1821), control2: CGPoint(x: 30.769, y: 10.9765))
        p2.addCurve(to: CGPoint(x: 27.6189, y: 5.45688), control1: CGPoint(x: 28.9849, y: 8.30031), control2: CGPoint(x: 28.2322, y: 6.90647))
        p2.addLine(to: CGPoint(x: 28.9988, y: 4.976))
        p2.closeSubpath()

        path.addPath(p1.applying(transform))
        path.addPath(p2.applying(transform))
        return path
    }
}
