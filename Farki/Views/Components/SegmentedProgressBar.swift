import SwiftUI

/// 30-segment brutalist vertical bar progress indicator matching Dashboard.png
public struct SegmentedProgressBar: View {
    public var progress: Double
    public var totalSegments: Int = 30
    public var height: CGFloat = 34

    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var filledColor: Color {
        themeManager.segmentFilledColor
    }

    private var emptyColor: Color {
        themeManager.segmentEmptyColor
    }

    public init(progress: Double, totalSegments: Int = 30, height: CGFloat = 34) {
        self.progress = progress
        self.totalSegments = totalSegments
        self.height = height
    }

    /// Calculate fractional fill (0.0 ... 1.0) for an individual segment bar
    private func fillFraction(for index: Int) -> CGFloat {
        guard totalSegments > 0 else { return 0.0 }
        let clamped = min(max(progress, 0.0), 1.0)
        let exactFilled = clamped * Double(totalSegments)
        let segStart = Double(index)
        let segEnd = Double(index + 1)

        if exactFilled >= segEnd {
            return 1.0
        } else if exactFilled <= segStart {
            return 0.0
        } else {
            return CGFloat(exactFilled - segStart)
        }
    }

    public var body: some View {
        HStack(spacing: 2.2) {
            ForEach(0..<totalSegments, id: \.self) { index in
                let fraction = fillFraction(for: index)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(emptyColor)
                            .frame(width: geo.size.width, height: geo.size.height)

                        // Partially or fully filled segment (horizontally from left to right)
                        if fraction > 0.0 {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(filledColor)
                                .frame(width: max(1.0, geo.size.width * fraction), height: geo.size.height)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
            }
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.3), value: progress)
        .animation(.easeInOut(duration: 0.35), value: themeManager.activeTheme)
    }
}
