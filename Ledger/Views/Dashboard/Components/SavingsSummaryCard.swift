//
//  SavingsSummaryCard.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// Displays `totalSavings` as a distinctly separate figure from current capital.
///
/// **Important Product Decision (see `DashboardViewModel`):** Total Savings and
/// Current Capital are INDEPENDENT figures and must never be visually combined
/// or subtracted from one another. This card exists specifically to keep that
/// separation obvious. It is paired with `CapitalHeaderCard` at equal visual
/// hierarchy (same hero glass treatment, same figure size) rather than reading
/// as a secondary tile.
///
/// When `goalsTargetAmount` is known (i.e. the user has at least one goal),
/// this card also renders a ring showing progress of `totalSavings` toward
/// that combined target — the only place on the Dashboard a savings figure
/// gets visual, at-a-glance context instead of just a number.
///
/// **Where Used:**
/// - `DashboardView`, alongside `CapitalHeaderCard`.
struct SavingsSummaryCard: View {
    let totalSavings: Decimal
    let currency: Currency
    let goalsTargetAmount: Decimal

    private var progress: Double {
        guard goalsTargetAmount > 0 else { return 0 }
        let saved = Double(truncating: totalSavings as NSDecimalNumber)
        let target = Double(truncating: goalsTargetAmount as NSDecimalNumber)
        return max(saved / target, 0)
    }

    private var formattedTargetAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","

        let amountString = formatter.string(from: goalsTargetAmount as NSDecimalNumber) ?? "0.00"
        return "\(currency.symbol) \(amountString)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "banknote.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Ahorros")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                CurrencyText(
                    amount: totalSavings,
                    currency: currency,
                    size: .large
                )

                if goalsTargetAmount > 0 {
                    Text("Meta: \(formattedTargetAmount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if goalsTargetAmount > 0 {
                SavingsProgressRing(progress: progress)
            }
        }
        .padding(24)
        .dashboardHeroGlass(cornerRadius: 20)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: totalSavings)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: goalsTargetAmount)
    }
}

/// A compact circular gauge showing `progress` (0...1+) toward a savings goal.
///
/// Color reflects how far along the goal is — red while just getting started,
/// amber while in progress, and green once the target is met or exceeded —
/// consistent with the semantic colors used elsewhere on the Dashboard
/// (green for income, red for expenses).
private struct SavingsProgressRing: View {
    let progress: Double

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    private var ringColor: Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.4 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 7)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if progress >= 1.0 {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Text("\(Int((clampedProgress * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: 60, height: 60)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Progreso hacia la meta de ahorro")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) por ciento")
    }
}

// MARK: - Previews

#Preview("Savings Summary Card") {
    let currency = Currency(code: "GTQ", symbol: "Q", isDefault: true)

    return VStack(spacing: 16) {
        SavingsSummaryCard(totalSavings: 12500.00, currency: currency, goalsTargetAmount: 20000.00)
        SavingsSummaryCard(totalSavings: 8500.00, currency: currency, goalsTargetAmount: 8000.00)
        SavingsSummaryCard(totalSavings: 0, currency: currency, goalsTargetAmount: 0)
    }
    .padding()
    .frame(width: 420)
}
