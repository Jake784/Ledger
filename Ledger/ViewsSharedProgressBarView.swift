//
//  ProgressBarView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// A horizontal progress bar for visualizing completion or usage.
///
/// Displays a filled progress indicator with customizable color.
/// The caller determines the semantic color based on context
/// (green for goals, red/amber for budget warnings).
///
/// **Usage:**
/// ```swift
/// ProgressBarView(
///     value: 0.65,
///     color: .blue
/// )
/// ```
///
/// **Where Used:**
/// - Budget spending progress (spent vs. limit)
/// - Goal savings progress (saved vs. target)
/// - Monthly budget utilization
/// - Category spending indicators
struct ProgressBarView: View {
    let value: Double // 0...1
    let color: Color
    let height: CGFloat
    let showPercentage: Bool

    init(
        value: Double,
        color: Color = .accentColor,
        height: CGFloat = 8,
        showPercentage: Bool = false
    ) {
        self.value = min(max(value, 0), 1) // Clamp to 0...1
        self.color = color
        self.height = height
        self.showPercentage = showPercentage
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))

                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: geometry.size.width * value)
                        .animation(.easeInOut(duration: 0.3), value: value)
                }
            }
            .frame(height: height)

            if showPercentage {
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
        }
    }
}

/// A progress bar with labels showing the current value vs. target.
///
/// **Usage:**
/// ```swift
/// LabeledProgressBarView(
///     current: 7500,
///     target: 10000,
///     currency: gtqCurrency,
///     color: .green
/// )
/// ```
struct LabeledProgressBarView: View {
    let current: Decimal
    let target: Decimal
    let currency: Currency
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        let value = Double(truncating: current as NSDecimalNumber) /
                   Double(truncating: target as NSDecimalNumber)
        return min(max(value, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CurrencyText(
                    amount: current,
                    currency: currency,
                    size: .regular,
                    color: color
                )

                Spacer()

                CurrencyText(
                    amount: target,
                    currency: currency,
                    size: .small
                )
                .foregroundStyle(.secondary)
            }

            ProgressBarView(
                value: progress,
                color: color,
                height: 8
            )

            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)

                Spacer()

                if current < target {
                    Text("Restante: \(currency.symbol) \(formatRemaining(target - current))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatRemaining(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }
}

/// A segmented progress bar showing multiple categories as proportional slices.
///
/// Useful for budget breakdowns or category spending visualization.
struct SegmentedProgressBarView: View {
    let segments: [(label: String, value: Double, color: Color)]
    let height: CGFloat

    init(
        segments: [(label: String, value: Double, color: Color)],
        height: CGFloat = 12
    ) {
        // Normalize segments to sum to 1.0
        let total = segments.reduce(0.0) { $0 + $1.value }
        if total > 0 {
            self.segments = segments.map { (label: $0.label, value: $0.value / total, color: $0.color) }
        } else {
            self.segments = segments
        }
        self.height = height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(segment.color)
                            .frame(width: geometry.size.width * segment.value)
                    }
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: height / 2))

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 8, height: 8)

                        Text(segment.label)
                            .font(.caption)

                        Spacer()

                        Text("\(Int(segment.value * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Progress Bars") {
    ScrollView {
        VStack(spacing: 32) {
            let currency = Currency(code: "GTQ", symbol: "Q")

            // Basic Progress Bars
            VStack(alignment: .leading, spacing: 16) {
                Text("Basic Progress Bars")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Goal Progress (65%)")
                        .font(.subheadline)
                    ProgressBarView(value: 0.65, color: .blue, height: 8)

                    Text("Budget Safe (45%)")
                        .font(.subheadline)
                    ProgressBarView(value: 0.45, color: .green, height: 8)

                    Text("Budget Warning (85%)")
                        .font(.subheadline)
                    ProgressBarView(value: 0.85, color: .orange, height: 8)

                    Text("Budget Over (110%)")
                        .font(.subheadline)
                    ProgressBarView(value: 1.1, color: .red, height: 8)
                }
                .cardStyle()
            }

            // Progress with Percentage
            VStack(alignment: .leading, spacing: 16) {
                Text("With Percentage Display")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    ProgressBarView(value: 0.33, color: .purple, height: 10, showPercentage: true)
                    ProgressBarView(value: 0.67, color: .indigo, height: 10, showPercentage: true)
                    ProgressBarView(value: 0.90, color: .teal, height: 10, showPercentage: true)
                }
                .cardStyle()
            }

            // Labeled Progress Bars
            VStack(alignment: .leading, spacing: 16) {
                Text("Labeled Progress (Goals/Budgets)")
                    .font(.headline)

                Card {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ahorro para Vacaciones")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            LabeledProgressBarView(
                                current: 37500,
                                target: 50000,
                                currency: currency,
                                color: .green
                            )
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Presupuesto Mensual de Comida")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            LabeledProgressBarView(
                                current: 2100,
                                target: 2500,
                                currency: currency,
                                color: .orange
                            )
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ejemplo Excedido")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            LabeledProgressBarView(
                                current: 3500,
                                target: 3000,
                                currency: currency,
                                color: .red
                            )
                        }
                    }
                }
            }

            // Segmented Progress
            VStack(alignment: .leading, spacing: 16) {
                Text("Segmented Progress (Category Breakdown)")
                    .font(.headline)

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presupuesto por Categoría")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SegmentedProgressBarView(
                            segments: [
                                (label: "Vivienda", value: 0.35, color: .blue),
                                (label: "Alimentación", value: 0.25, color: .green),
                                (label: "Transporte", value: 0.20, color: .orange),
                                (label: "Entretenimiento", value: 0.12, color: .purple),
                                (label: "Otros", value: 0.08, color: .gray)
                            ]
                        )
                    }
                }
            }
        }
        .padding()
    }
    .frame(width: 500)
}
