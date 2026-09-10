//
//  HoverEffect.swift
//  FinVault
//

import SwiftUI
import AppKit

/// Reusable hover feedback for clickable controls — a subtle scale-up plus a
/// brightness lift, a pointing-hand cursor, and a quick, smooth animation.
///
/// macOS gives no built-in hover affordance for custom `Button` styles (glass
/// pills, sidebar rows, category chips, …), so without this they look
/// identical whether the pointer is over them or not. This modifier is the
/// single place that hover feedback is defined so every button across the
/// app stays visually consistent — apply it directly, or via
/// `GlassHoverButtonStyle` for a plain `ButtonStyle`.
///
/// **Usage:**
/// ```swift
/// someButtonLabel
///     .hoverHighlight()
/// ```
///
/// **Where Used:**
/// - `DashboardQuickActionButton` (Dashboard quick-actions row)
struct HoverHighlight: ViewModifier {
    var scale: CGFloat = 1.02
    var brightness: Double = 0.06

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovered ? brightness : 0)
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    /// Applies the app-wide hover feedback (scale, brightness lift, pointing
    /// cursor) used across custom button surfaces. See `HoverHighlight`.
    func hoverHighlight(scale: CGFloat = 1.02, brightness: Double = 0.06) -> some View {
        modifier(HoverHighlight(scale: scale, brightness: brightness))
    }
}

/// A plain `ButtonStyle` wrapper around `hoverHighlight`, for buttons that
/// don't build their own custom label view (e.g. `.buttonStyle(.plain)`
/// callers that just want the standard hover feedback without adopting the
/// view-modifier form).
struct GlassHoverButtonStyle: ButtonStyle {
    var scale: CGFloat = 1.02
    var brightness: Double = 0.06

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .hoverHighlight(scale: scale, brightness: brightness)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
