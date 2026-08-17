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
/// separation obvious — its own card, a lighter label weight than
/// `CapitalHeaderCard`'s, and a piggy bank icon distinguish it at a glance.
///
/// **Where Used:**
/// - `DashboardView`, alongside `CapitalHeaderCard`.
struct SavingsSummaryCard: View {
    let totalSavings: Decimal
    let currency: Currency

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "banknote")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Ahorros")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                CurrencyText(
                    amount: totalSavings,
                    currency: currency,
                    size: .medium,
                    color: .secondary
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview("Savings Summary Card") {
    let currency = Currency(code: "GTQ", symbol: "Q", isDefault: true)

    return HStack(alignment: .top, spacing: 16) {
        SavingsSummaryCard(totalSavings: 12500.00, currency: currency)
            .frame(width: 200)

        SavingsSummaryCard(totalSavings: 0, currency: currency)
            .frame(width: 200)
    }
    .padding()
}
