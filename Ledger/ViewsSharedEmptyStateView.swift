//
//  EmptyStateView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// A reusable empty state placeholder shown when a list or screen has no data yet.
///
/// Combines an icon, title, optional subtitle, and an optional call-to-action
/// button so every module can present a consistent "nothing here yet" screen.
///
/// **Usage:**
/// ```swift
/// EmptyStateView(
///     icon: "tray",
///     title: "Sin transacciones",
///     subtitle: "Registra tu primer ingreso o gasto para comenzar.",
///     actionTitle: "Agregar Transacción",
///     action: { /* present form */ }
/// )
///
/// // A tighter variant for smaller surfaces (e.g. a chart card) that
/// // shouldn't expand to fill all available height:
/// EmptyStateView(icon: "chart.pie", title: "Sin gastos este mes", compact: true)
/// ```
///
/// **Where Used:**
/// - Transaction history with no entries
/// - Goals list with no goals created
/// - Budgets list with no categories configured
/// - Savings funds list with no funds
/// - Search or filter results with no matches
/// - Dashboard category breakdown charts (compact variant)
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let compact: Bool

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        compact: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
        self.compact = compact
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            Image(systemName: icon)
                .font(.system(size: compact ? 28 : 44, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(title)
                    .font(compact ? .subheadline.weight(.medium) : .headline)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 220)
                    .padding(.top, 4)
            }
        }
        .padding(compact ? 20 : 40)
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity)
    }
}

// MARK: - Previews

#Preview("Empty States") {
    TabView {
        EmptyStateView(
            icon: "tray",
            title: "Sin transacciones",
            subtitle: "Registra tu primer ingreso o gasto para comenzar a ver tu historial aquí.",
            actionTitle: "Agregar Transacción",
            action: { print("Add transaction") }
        )
        .tabItem { Text("Con acción") }

        EmptyStateView(
            icon: "target",
            title: "Sin metas de ahorro",
            subtitle: "Crea una meta para hacer seguimiento de tu progreso."
        )
        .tabItem { Text("Sin acción") }

        EmptyStateView(
            icon: "magnifyingglass",
            title: "Sin resultados"
        )
        .tabItem { Text("Solo título") }

        EmptyStateView(
            icon: "chart.pie",
            title: "Sin gastos este mes",
            compact: true
        )
        .tabItem { Text("Compacto") }
    }
    .frame(width: 500, height: 400)
}
