//
//  TransactionRow.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// A single row summarizing one `Transaction`, shared by the Ingresos, Gastos, and
/// Historial modules.
///
/// Shows the category icon (tinted with the category's own color), description,
/// category name, date, and a signed amount — green for income, red for expense.
/// Pending and recurring transactions get their matching `StatusBadge`.
///
/// Clicking the row invokes `onEdit` (meant to present the row's transaction in the
/// existing Add Income/Add Expense sheet, in edit mode). A trash button reveals on
/// hover and a right-click context menu offers "Editar"/"Eliminar" — both invoke
/// `onEdit`/`onDelete`; this view never touches `ModelContext` itself, so the actual
/// update/delete call (and any confirmation alert before deleting) is the caller's
/// responsibility, matching every other view in the app that only mutates through
/// its own ViewModel.
///
/// Reuses `hoverHighlight()` (`ViewsSharedHoverEffect.swift`) for both the row body
/// and the delete button — `scale: 1.0` on the row itself so hovering doesn't scale
/// content out of alignment with the `Divider`s above/below it in a stacked list.
///
/// **Where Used:**
/// - `IncomeView`'s transaction history
/// - `ExpensesView`'s transaction history and pending list
/// - `HistoryView`'s pending and month-grouped sections
struct TransactionRow: View {
    let transaction: Transaction
    let currency: Currency
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var isIncome: Bool { transaction.type == .income }
    private var amountColor: Color { isIncome ? .green : .red }
    private var signedAmount: Decimal { isIncome ? transaction.amount : -transaction.amount }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onEdit) {
                rowContent
            }
            .buttonStyle(.plain)
            .hoverHighlight(scale: 1.0)

            deleteButton
        }
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    private var rowContent: some View {
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
        // Without this, taps only register on the icon/text/amount's own tight
        // glyph bounds — not the row's padding or the `Spacer`'s empty space.
        .contentShape(Rectangle())
    }

    /// Reserves its width always (rather than conditionally inserting the button)
    /// so the row's layout doesn't shift when the pointer enters/leaves — only its
    /// opacity and hit-testing toggle with `isHovered`.
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.body)
                .foregroundStyle(.red)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(scale: 1.0)
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
        .accessibilityLabel("Eliminar transacción")
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
            currency: currency,
            onEdit: {},
            onDelete: {}
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
            currency: currency,
            onEdit: {},
            onDelete: {}
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
            currency: currency,
            onEdit: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 420)
}
