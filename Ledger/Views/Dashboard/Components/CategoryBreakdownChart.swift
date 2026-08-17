//
//  CategoryBreakdownChart.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import Charts

/// A donut chart summarizing category totals, with a matching legend.
///
/// Reusable for both the expense and income breakdowns on the Dashboard —
/// parametrized by data, title, icon, and currency so the two callers only
/// differ in what they pass in. Each segment uses the `Category`'s own
/// `color` (a hex string on the model), kept calm by only ever charting a
/// handful of top categories (see `DashboardViewModel.topExpenseCategories`
/// / `topIncomeCategories`).
///
/// **Where Used:**
/// - `DashboardView`, once for `expensesByCategory` and once for `incomeByCategory`.
struct CategoryBreakdownChart: View {
    let title: String
    let icon: String
    let data: [(category: Category, total: Decimal)]
    let currency: Currency
    let emptyStateMessage: String

    private var total: Decimal {
        data.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)

                if data.isEmpty {
                    EmptyStateView(
                        icon: icon,
                        title: emptyStateMessage,
                        compact: true
                    )
                } else {
                    HStack(alignment: .center, spacing: 20) {
                        chart
                            .frame(width: 130, height: 130)

                        legend
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chart: some View {
        Chart(data, id: \.category.id) { entry in
            SectorMark(
                angle: .value("Total", NSDecimalNumber(decimal: entry.total).doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(Color(hex: entry.category.color))
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(data, id: \.category.id) { entry in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: entry.category.color))
                        .frame(width: 8, height: 8)

                    Text(entry.category.name)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    CurrencyText(
                        amount: entry.total,
                        currency: currency,
                        size: .small
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Resolves a `Category`'s hex color string (e.g. `"#FF3B30"`, as seeded by
/// `CategorySeeder`) into a SwiftUI `Color`. Scoped to this file since chart
/// segments are the only place that needs the conversion today.
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

#Preview("Category Breakdown Chart") {
    let currency = Currency(code: "GTQ", symbol: "Q", isDefault: true)

    let expenseCategories: [(category: Category, total: Decimal)] = [
        (Category(name: "Comida", type: .expense, icon: "fork.knife", color: "#FF3B30"), 1250.00),
        (Category(name: "Transporte", type: .expense, icon: "car.fill", color: "#007AFF"), 650.00),
        (Category(name: "Entretenimiento", type: .expense, icon: "film", color: "#AF52DE"), 320.00)
    ]

    return VStack(spacing: 16) {
        CategoryBreakdownChart(
            title: "Gastos por Categoría",
            icon: "chart.pie",
            data: expenseCategories,
            currency: currency,
            emptyStateMessage: "Sin gastos este mes"
        )

        CategoryBreakdownChart(
            title: "Ingresos por Categoría",
            icon: "chart.pie",
            data: [],
            currency: currency,
            emptyStateMessage: "Sin ingresos este mes"
        )
    }
    .padding()
    .frame(width: 420)
}
