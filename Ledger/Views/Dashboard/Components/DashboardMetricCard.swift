//
//  DashboardMetricCard.swift
//  FinVault
//

import SwiftUI

/// A neutral-glass metric card with a colored inner border, used only for the
/// Dashboard's paired monthly income/expense figures.
///
/// Kept separate from the shared `MetricCard` (`ViewsSharedCardStyle.swift`),
/// which is reused as-is by Income, Expenses, Budget, Goals, Projections, and
/// Savings — this Liquid Glass + border treatment is intentionally Dashboard-only
/// so it doesn't leak into those other screens.
///
/// **Where Used:**
/// - `DashboardView`, for "Ingresos del Mes" and "Gastos del Mes".
struct DashboardMetricCard: View {
    let label: String
    let value: Decimal
    let currency: Currency
    let accentColor: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(accentColor)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            CurrencyText(
                amount: value,
                currency: currency,
                size: .large,
                color: accentColor
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dashboardGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1.5)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}

// MARK: - Previews

#Preview("Dashboard Metric Card") {
    let currency = Currency(code: "GTQ", symbol: "Q", isDefault: true)

    return HStack(spacing: 16) {
        DashboardMetricCard(
            label: "Ingresos del Mes",
            value: 15000.00,
            currency: currency,
            accentColor: .green,
            icon: "arrow.down.circle"
        )

        DashboardMetricCard(
            label: "Gastos del Mes",
            value: 8750.00,
            currency: currency,
            accentColor: .red,
            icon: "arrow.up.circle"
        )
    }
    .padding()
    .frame(width: 600)
}
