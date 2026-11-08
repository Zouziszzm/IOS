import SwiftUI

struct SplashScreenView: View {
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    var targetHeaderFrame: CGRect = .zero
    var onFinished: () -> Void

    @State private var logoOpacity: Double = 0.0
    @State private var isScaledDown: Bool = false
    @State private var backgroundOpacity: Double = 1.0

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var canvasColor: Color {
        themeManager.canvasColor
    }

    var body: some View {
        GeometryReader { proxy in
            let centerPoint = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            // Exact header target position calculated directly from the measured header frame
            let targetPoint: CGPoint = {
                if targetHeaderFrame != .zero && targetHeaderFrame.midY > 30 {
                    return CGPoint(x: targetHeaderFrame.midX, y: targetHeaderFrame.midY)
                }
                // Fallback positioning (safe area top + padding top 14 + half height 11)
                return CGPoint(x: 24 + 21, y: 59 + 14 + 11)
            }()

            ZStack {
                // Background overlay matching active theme
                canvasColor
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)

                // Clean solid brand logo: fades in without drawing strokes, then scales down to header
                AppLogoShape()
                    .fill(inkColor)
                    .opacity(logoOpacity)
                    .frame(
                        width: isScaledDown ? 42 : 144,
                        height: isScaledDown ? 22 : 76
                    )
                    // Position either centered or glided to exact top header position
                    .position(isScaledDown ? targetPoint : centerPoint)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startSplashSequence()
        }
    }

    private func startSplashSequence() {
        // Step 1: Smoothly fade in the solid logo (no outline/stroke drawing)
        withAnimation(.easeOut(duration: 0.45)) {
            logoOpacity = 1.0
        }

        // Haptic feedback upon appearance
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Step 2: Scale down and glide directly to top header position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                isScaledDown = true
            }

            // Step 3: Fade out splash background to reveal main content
            withAnimation(.easeInOut(duration: 0.35).delay(0.12)) {
                backgroundOpacity = 0.0
            }

            // Step 4: Settle into header and complete splash transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                onFinished()
            }
        }
    }
}
