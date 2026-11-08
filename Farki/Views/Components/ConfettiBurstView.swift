import SwiftUI

// MARK: - Confetti Particle Model
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let side: Side
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let isCircle: Bool

    // Trajectory parameters
    let targetX: CGFloat
    let targetY: CGFloat
    let targetRotation: Double
    let delay: Double

    enum Side {
        case left, right
    }
}

// MARK: - Confetti Cannon Burst View
struct ConfettiBurstView: View {
    @Binding var trigger: Int

    @State private var particles: [ConfettiParticle] = []
    @State private var animProgress: CGFloat = 0.0
    @State private var opacity: Double = 0.0

    private let colors: [Color] = [
        Color(hex: "#EF4444"), // Crimson
        Color(hex: "#F59E0B"), // Amber / Gold
        Color(hex: "#10B981"), // Emerald Green
        Color(hex: "#38BDF8"), // Sky Blue
        Color(hex: "#EC4899"), // Pink
        Color(hex: "#8B5CF6"), // Purple
        Color(hex: "#FCD34D")  // Bright Yellow
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    let startX: CGFloat = p.side == .left ? -10 : geo.size.width + 10
                    let startY: CGFloat = geo.size.height * 0.70

                    let currentX = startX + (p.targetX * animProgress)
                    // Parabolic arc: shoots upward then curves gently downward
                    let arcY = (p.targetY * animProgress) + (180 * animProgress * animProgress)
                    let currentY = startY + arcY

                    Group {
                        if p.isCircle {
                            Circle()
                                .fill(p.color)
                                .frame(width: p.width, height: p.height)
                        } else {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(p.color)
                                .frame(width: p.width, height: p.height)
                        }
                    }
                    .rotationEffect(.degrees(p.targetRotation * animProgress))
                    .position(x: currentX, y: currentY)
                    .opacity(opacity)
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: trigger) { _ in
            emitBurst()
        }
    }

    private func emitBurst() {
        guard trigger > 0 else { return }

        var newParticles: [ConfettiParticle] = []
        let particleCount = 28 // 28 per side = 56 total festive burst

        // 1. Left Cannon (Shoots Upwards & Inwards to the Right)
        for _ in 0..<particleCount {
            let color = colors.randomElement() ?? Color(hex: "#F59E0B")
            let width = CGFloat.random(in: 6...11)
            let height = CGFloat.random(in: 4...12)
            let isCircle = Bool.random()

            // Target displacement: rightwards + strongly upwards
            let targetX = CGFloat.random(in: 110...260)
            let targetY = -CGFloat.random(in: 240...480)
            let rot = Double.random(in: 360...1080) * (Bool.random() ? 1 : -1)

            newParticles.append(ConfettiParticle(
                side: .left,
                color: color,
                width: width,
                height: height,
                isCircle: isCircle,
                targetX: targetX,
                targetY: targetY,
                targetRotation: rot,
                delay: Double.random(in: 0...0.08)
            ))
        }

        // 2. Right Cannon (Shoots Upwards & Inwards to the Left)
        for _ in 0..<particleCount {
            let color = colors.randomElement() ?? Color(hex: "#10B981")
            let width = CGFloat.random(in: 6...11)
            let height = CGFloat.random(in: 4...12)
            let isCircle = Bool.random()

            // Target displacement: leftwards + strongly upwards
            let targetX = -CGFloat.random(in: 110...260)
            let targetY = -CGFloat.random(in: 240...480)
            let rot = Double.random(in: 360...1080) * (Bool.random() ? 1 : -1)

            newParticles.append(ConfettiParticle(
                side: .right,
                color: color,
                width: width,
                height: height,
                isCircle: isCircle,
                targetX: targetX,
                targetY: targetY,
                targetRotation: rot,
                delay: Double.random(in: 0...0.08)
            ))
        }

        self.particles = newParticles
        self.animProgress = 0.0
        self.opacity = 1.0

        // Launch animation
        withAnimation(.easeOut(duration: 1.35)) {
            self.animProgress = 1.0
        }

        // Fade out gracefully toward end of flight
        withAnimation(.easeIn(duration: 0.45).delay(0.90)) {
            self.opacity = 0.0
        }

        // Cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            if self.animProgress >= 1.0 {
                self.particles = []
            }
        }
    }
}
