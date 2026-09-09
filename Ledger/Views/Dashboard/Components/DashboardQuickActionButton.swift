//
//  DashboardQuickActionButton.swift
//  FinVault
//

import SwiftUI

/// A glass pill button for the Dashboard's quick-actions row (e.g. "Agregar
/// Ingreso", "Agregar Gasto"). Mirrors `DashboardMetricCard`'s neutral-glass
/// + colored-border treatment so the row reads as part of the same bento
/// system, but stays a `Button` since these trigger an action rather than
/// display a figure.
///
/// **Where Used:**
/// - `DashboardView`'s quick-actions row, below the hero cards.
struct DashboardQuickActionButton: View {
    let title: String
    let icon: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .dashboardGlass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accentColor.opacity(0.3), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Dashboard Quick Action Buttons") {
    HStack(spacing: 16) {
        DashboardQuickActionButton(
            title: "Agregar Ingreso",
            icon: "arrow.down.circle.fill",
            accentColor: .green,
            action: {}
        )

        DashboardQuickActionButton(
            title: "Agregar Gasto",
            icon: "arrow.up.circle.fill",
            accentColor: .red,
            action: {}
        )
    }
    .padding()
    .frame(width: 500)
}
