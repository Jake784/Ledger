//
//  CardStyle.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// A view modifier that applies consistent card styling across the app.
///
/// Provides a subtle elevation effect with rounded corners, a hairline border,
/// and soft shadows, following Apple's native design principles while adding
/// purposeful depth. An optional `tint` washes the card's background and
/// border with a semantic or accent color at low opacity — used sparingly to
/// give a card (like the Dashboard's hero capital figure, or a signed metric)
/// more visual weight than its neutral neighbors. `topAccent` adds a thin
/// tint-colored stripe along the card's top edge for the same purpose; it's
/// composited and clipped as part of this same modifier (rather than an
/// external `.overlay`) so it can never visually detach from the card.
///
/// **Usage:**
/// ```swift
/// VStack {
///     // Content
/// }
/// .cardStyle()
///
/// // Or, for a card that should stand out:
/// VStack {
///     // Content
/// }
/// .cardStyle(tint: .accentColor, padding: 24, topAccent: true)
/// ```
///
/// **Where Used:**
/// - Dashboard metric cards
/// - Transaction list items
/// - Budget progress cards
/// - Goal cards
/// - Settings sections
struct CardStyleModifier: ViewModifier {
    var tint: Color? = nil
    var padding: CGFloat = 16
    var topAccent: Bool = false

    private var borderColor: Color { tint ?? .primary }
    private var borderOpacity: Double { tint != nil ? 0.16 : 0.08 }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    Rectangle().fill(.regularMaterial)
                    if let tint {
                        Rectangle().fill(tint.opacity(0.05))
                    }
                }
            )
            .overlay(alignment: .top) {
                if topAccent, let tint {
                    Rectangle()
                        .fill(tint.opacity(0.8))
                        .frame(height: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

extension View {
    /// Applies card styling to any view.
    /// - Parameters:
    ///   - tint: An optional semantic/accent color to wash the background and border with.
    ///   - padding: Internal padding; defaults to the standard card padding.
    ///   - topAccent: Adds a thin tint-colored stripe along the card's top edge. Ignored if `tint` is nil.
    func cardStyle(tint: Color? = nil, padding: CGFloat = 16, topAccent: Bool = false) -> some View {
        modifier(CardStyleModifier(tint: tint, padding: padding, topAccent: topAccent))
    }
}

/// A convenience wrapper for card content.
///
/// Provides a cleaner syntax when building card-based layouts.
///
/// **Usage:**
/// ```swift
/// Card {
///     VStack {
///         // Card content
///     }
/// }
///
/// // A tinted, more prominent card:
/// Card(tint: .accentColor, padding: 24) {
///     VStack {
///         // Hero content
///     }
/// }
/// ```
struct Card<Content: View>: View {
    let tint: Color?
    let padding: CGFloat
    let topAccent: Bool
    let content: Content

    init(
        tint: Color? = nil,
        padding: CGFloat = 16,
        topAccent: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.padding = padding
        self.topAccent = topAccent
        self.content = content()
    }

    var body: some View {
        content
            .cardStyle(tint: tint, padding: padding, topAccent: topAccent)
    }
}

/// A specialized card for displaying key financial metrics.
///
/// Shows a large number with a descriptive label, used prominently
/// on the dashboard and summary screens.
///
/// **Usage:**
/// ```swift
/// MetricCard(
///     label: "Capital Actual",
///     value: 25750.50,
///     currency: gtqCurrency,
///     color: .blue
/// )
///
/// // With a soft background wash of `color`, for cards that should read
/// // as semantically colored surfaces rather than just colored text:
/// MetricCard(
///     label: "Ingresos del Mes",
///     value: 15000.00,
///     currency: gtqCurrency,
///     color: .green,
///     icon: "arrow.down.circle",
///     tinted: true
/// )
/// ```
///
/// **Where Used:**
/// - Dashboard capital/savings cards
/// - Monthly totals
/// - Budget summary
/// - Goal progress indicators
struct MetricCard: View {
    let label: String
    let value: Decimal
    let currency: Currency
    let color: Color
    let icon: String?
    let tinted: Bool

    init(
        label: String,
        value: Decimal,
        currency: Currency,
        color: Color = .accentColor,
        icon: String? = nil,
        tinted: Bool = false
    ) {
        self.label = label
        self.value = value
        self.currency = currency
        self.color = color
        self.icon = icon
        self.tinted = tinted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            CurrencyText(
                amount: value,
                currency: currency,
                size: .large,
                color: color
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(tint: tinted ? color : nil)
    }
}

// MARK: - Previews

#Preview("Card Styles") {
    ScrollView {
        VStack(spacing: 24) {
            // Basic Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Basic Card")
                    .font(.headline)

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transacción")
                            .font(.headline)
                        Text("Compra de supermercado")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Spacer()
                            Text("Q 450.00")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            // Metric Cards
            VStack(alignment: .leading, spacing: 8) {
                Text("Metric Cards")
                    .font(.headline)

                let currency = Currency(code: "GTQ", symbol: "Q")

                HStack(spacing: 16) {
                    MetricCard(
                        label: "Capital Actual",
                        value: 25750.50,
                        currency: currency,
                        color: .blue,
                        icon: "chart.line.uptrend.xyaxis"
                    )

                    MetricCard(
                        label: "Ahorros Totales",
                        value: 12500.00,
                        currency: currency,
                        color: .green,
                        icon: "banknote"
                    )
                }
            }

            // Dashboard example
            VStack(alignment: .leading, spacing: 8) {
                Text("Dashboard Layout Example")
                    .font(.headline)

                let currency = Currency(code: "GTQ", symbol: "Q")

                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        MetricCard(
                            label: "Ingresos del Mes",
                            value: 15000.00,
                            currency: currency,
                            color: .green,
                            icon: "arrow.down.circle",
                            tinted: true
                        )

                        MetricCard(
                            label: "Gastos del Mes",
                            value: 8750.00,
                            currency: currency,
                            color: .red,
                            icon: "arrow.up.circle",
                            tinted: true
                        )
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Balance Mensual")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            SignedCurrencyText(
                                amount: 6250.00,
                                currency: currency,
                                size: .large
                            )
                        }
                    }
                }
            }

            // Tinted / Hero Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Tinted Hero Card")
                    .font(.headline)

                let currency = Currency(code: "GTQ", symbol: "Q")

                Card(tint: .accentColor, padding: 24, topAccent: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Capital Actual")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        CurrencyText(
                            amount: 25750.50,
                            currency: currency,
                            size: .large
                        )
                    }
                }
            }
        }
        .padding()
    }
    .frame(width: 600)
}
