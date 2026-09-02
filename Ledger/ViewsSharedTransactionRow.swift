//
//  TransactionRow.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// A single row summarizing one `Transaction`, shared by the Ingresos and Gastos modules.
///
/// Shows the category icon (tinted with the category's own color), description,
/// category name, date, and a signed amount — green for income, red for expense.
/// Pending and recurring transactions get their matching `StatusBadge`.
///
/// **Where Used:**
/// - `IncomeView`'s transaction history
/// - `ExpensesView`'s transaction history and pending list
struct TransactionRow: View {
    let transaction: Transaction
    let currency: Currency

    private var isIncome: Bool { transaction.type == .income }
    private var amountColor: Color { isIncome ? .green : .red }
    private var signedAmount: Decimal { isIncome ? transaction.amount : -transaction.amount }

    var body: some View {
        HStack(spacing: 12) {
            categoryIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.descriptionText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    if let category = transaction.category {
                        Text(category.name)
                    }
                    Text(Self.dateFormatter.string(from: transaction.date))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if transaction.isPending || transaction.recurrenceRule != nil {
                    HStack(spacing: 6) {
                        if transaction.isPending {
                            StatusBadge.pending()
                        }
                        if transaction.recurrenceRule != nil {
                            StatusBadge(text: "Recurrente", color: .indigo, icon: "arrow.clockwise")
                        }
                    }
                }
            }

            Spacer()

            SignedCurrencyText(
                amount: signedAmount,
                currency: currency,
                size: .regular
            )
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: some View {
        let color = transaction.category.map { Color(hex: $0.color) } ?? .gray

        return Image(systemName: transaction.category?.icon ?? "tag")
            .font(.body)
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

/// Resolves a `Category`'s hex color string into a SwiftUI `Color`.
/// Scoped to this file, matching `CategoryBreakdownChart.swift`'s own private
/// hex-to-Color helper — each display context that needs the conversion keeps its own copy.
private extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString.removeAll { $0 == "#" }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255,
            blue: Double(rgbValue & 0x0000FF) / 255
        )
    }
}

// MARK: - Previews

#Preview("Transaction Row") {
    let currency = Currency(code: "GTQ", symbol: "Q", isDefault: true)
    let salary = Category(name: "Salario", type: .income, icon: "banknote.fill", color: "#34C759")
    let food = Category(name: "Alimentación", type: .expense, icon: "fork.knife", color: "#FF3B30")

    return VStack(spacing: 0) {
        TransactionRow(
            transaction: Transaction(
                type: .income,
                unitPrice: 8000,
                amount: 8000,
                currency: currency,
                descriptionText: "Salario",
                category: salary,
                date: Date(),
                isPending: false
            ),
            currency: currency
        )

        Divider()

        TransactionRow(
            transaction: Transaction(
                type: .expense,
                unitPrice: 900,
                amount: 900,
                currency: currency,
                descriptionText: "Supermercado",
                category: food,
                date: Date(),
                isPending: false
            ),
            currency: currency
        )

        Divider()

        TransactionRow(
            transaction: Transaction(
                type: .expense,
                unitPrice: 350,
                amount: 350,
                currency: currency,
                descriptionText: "Renta",
                category: nil,
                date: Date(),
                isPending: true,
                recurrenceRule: RecurrenceRule(frequency: .monthly, startDate: Date())
            ),
            currency: currency
        )
    }
    .padding()
    .frame(width: 420)
}
