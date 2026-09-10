//
//  FormGlassStyle.swift
//  FinVault
//

import SwiftUI

/// Liquid Glass surface treatments for the Add Income / Add Expense modals.
///
/// Deliberately kept separate from `cardStyle`/`Card` (`ViewsSharedCardStyle.swift`),
/// which stays the flat/material look used by every other sheet in the app
/// (Settings, Goals, Budget, Categories, Savings, Projections, onboarding,
/// `CapitalAdjustmentSheet`) — changing that shared modifier would restyle
/// all of them, not just these two forms. Also kept separate from
/// `DashboardGlassStyle`, which is intentionally Dashboard-only for the same
/// reason. These modifiers exist so `AddIncomeSheet`/`AddExpenseSheet` can
/// move to Liquid Glass on their own without touching anything else.
extension View {
    /// The form's outer card — the main glass surface behind every field.
    /// Neutral (untinted) glass, matching the calm, non-hero surfaces
    /// elsewhere in the app (e.g. `dashboardGlass`).
    func formGlassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    /// A subtler nested glass container for grouping one control (Categoría,
    /// Fecha) within the form card, so it reads as its own glass surface
    /// rather than a flat native control floating on the card.
    func formGlassField(cornerRadius: CGFloat = 14) -> some View {
        self
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
