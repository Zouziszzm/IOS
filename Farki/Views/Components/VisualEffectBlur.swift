import SwiftUI
import UIKit

/// High-performance native iOS Frosted Glass blur view with customizable intensity
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style = .systemUltraThinMaterial
    var intensity: CGFloat = 0.65

    func makeUIView(context: Context) -> UIVisualEffectView {
        let effect = UIBlurEffect(style: blurStyle)
        let blurView = UIVisualEffectView(effect: effect)
        blurView.alpha = intensity
        return blurView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
        uiView.alpha = intensity
    }
}
