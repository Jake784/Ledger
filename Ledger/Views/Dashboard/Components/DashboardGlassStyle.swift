//
//  DashboardGlassStyle.swift
//  FinVault
//

import SwiftUI

/// Liquid Glass surface treatments scoped to the Dashboard's bento layout.
///
/// Deliberately kept separate from `cardStyle`/`Card` (`ViewsSharedCardStyle.swift`),
/// which is reused verbatim by Income, Expenses, Budget, Goals, Projections, and
/// Savings — changing that shared modifier would restyle every other module's
/// cards, not just the Dashboard. These modifiers exist so the Dashboard can move
/// to Liquid Glass on its own without touching anything else.
extension View {
    /// Neutral glass used for the Dashboard's non-hero surfaces (Ahorros, Metas
    /// Activas, both category breakdown charts) — no tint, just a soft shadow so
    /// each card reads as floating above the window background.
    func dashboardGlass(cornerRadius: CGFloat = 16) -> some View {
        self
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    /// Accent-tinted glass for the Dashboard's single hero card (Capital Actual).
    func dashboardHeroGlass(cornerRadius: CGFloat = 20) -> some View {
        self.glassEffect(.regular.tint(Color.accentColor.opacity(0.15)), in: .rect(cornerRadius: cornerRadius))
    }
}
