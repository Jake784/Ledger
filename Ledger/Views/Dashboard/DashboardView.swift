//
//  DashboardView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's main Panel screen — the first thing the user sees after onboarding.
///
/// Shows current capital and total savings as two INDEPENDENT figures (per
/// `DashboardViewModel`'s documented product decision), this month's income/expense
/// summary, and a calm category breakdown for both.
///
/// **Data Synchronization:** `DashboardViewModel` does not auto-sync, so this view
/// reloads it on `.onAppear` and again after the capital adjustment sheet dismisses.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.panel`.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: DashboardViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    capitalSection(currency: currency)
                    summaryCardsRow(currency: currency)
                    breakdownSection(currency: currency)
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Panel")
        .onAppear {
            viewModel.loadDashboardData()
        }
    }

    // MARK: - Sections

    private func capitalSection(currency: Currency) -> some View {
        HStack(alignment: .top, spacing: 16) {
            CapitalHeaderCard(
                currentCapital: viewModel.currentCapital,
                currency: currency,
                modelContext: modelContext,
                onAdjusted: { viewModel.loadDashboardData() }
            )
            .layoutPriority(1)

            SavingsSummaryCard(
                totalSavings: viewModel.totalSavings,
                currency: currency
            )
            .frame(width: 220)
        }
    }

    private func summaryCardsRow(currency: Currency) -> some View {
        HStack(spacing: 16) {
            MetricCard(
                label: "Ingresos del Mes",
                value: viewModel.monthlyIncome,
                currency: currency,
                color: .green,
                icon: "arrow.down.circle",
                tinted: true
            )

            MetricCard(
                label: "Gastos del Mes",
                value: viewModel.monthlyExpenses,
                currency: currency,
                color: .red,
                icon: "arrow.up.circle",
                tinted: true
            )
        }
    }

    private func breakdownSection(currency: Currency) -> some View {
        HStack(alignment: .top, spacing: 16) {
            CategoryBreakdownChart(
                title: "Gastos por Categoría",
                icon: "chart.pie",
                data: viewModel.topExpenseCategories(),
                currency: currency,
                emptyStateMessage: "Aún no tienes gastos este mes."
            )

            CategoryBreakdownChart(
                title: "Ingresos por Categoría",
                icon: "chart.pie",
                data: viewModel.topIncomeCategories(),
                currency: currency,
                emptyStateMessage: "Aún no tienes ingresos este mes."
            )
        }
    }

    // MARK: - Currency Resolution

    /// The currency used to render every figure on the Dashboard.
    ///
    /// `DashboardViewModel`'s totals are plain `Decimal`s with no currency attached,
    /// so the view resolves one the same way `InitialCapitalView` does: the user's
    /// preferred currency, falling back to whichever `Currency` `CurrencySeeder`
    /// marked as default, falling back to the first one found.
    private var displayCurrency: Currency? {
        userProfiles.first?.preferredCurrency
            ?? currencies.first(where: { $0.isDefault })
            ?? currencies.first
    }
}

// MARK: - Previews

#Preview("Dashboard") {
    let container = DashboardPreviewContainer.make()

    return NavigationStack {
        DashboardView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

#Preview("Dashboard - Empty State") {
    let container = DashboardPreviewContainer.make(seedTransactions: false)

    return NavigationStack {
        DashboardView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `DashboardView`
/// with realistic sample data.
private enum DashboardPreviewContainer {
    static func make(seedTransactions: Bool = true) -> ModelContainer {
        let schema = Schema([
            Budget.self,
            BudgetCategoryLimit.self,
            Category.self,
            Currency.self,
            Goal.self,
            Projection.self,
            ProjectionItem.self,
            RecurrenceRule.self,
            SavingsFund.self,
            SavingsMovement.self,
            Transaction.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        CurrencySeeder.seedIfNeeded(context: context)
        CategorySeeder.seedIfNeeded(context: context)

        let currency = try! context.fetch(FetchDescriptor<Currency>()).first!
        let categories = try! context.fetch(FetchDescriptor<Category>())

        let profile = UserProfile(
            name: "Luis",
            avatarSystemImage: "star.circle.fill",
            preferredCurrency: currency
        )
        context.insert(profile)

        guard seedTransactions else {
            try? context.save()
            return container
        }

        let salaryCategory = categories.first { $0.type == .income }
        let groceriesCategory = categories.first { $0.name.lowercased().contains("comida") || $0.name.lowercased().contains("aliment") } ?? categories.first { $0.type == .expense }
        let transportCategory = categories.filter { $0.type == .expense }.dropFirst().first ?? categories.first { $0.type == .expense }

        let sampleTransactions: [Transaction] = [
            Transaction(
                type: .capitalAdjustment,
                unitPrice: 20000,
                quantity: 1,
                amount: 20000,
                currency: currency,
                descriptionText: "Capital Adjustment",
                category: nil,
                date: Date(),
                isPending: false,
                note: "Capital inicial"
            ),
            Transaction(
                type: .income,
                unitPrice: 15000,
                quantity: 1,
                amount: 15000,
                currency: currency,
                descriptionText: "Salario",
                category: salaryCategory,
                date: Date(),
                isPending: false
            ),
            Transaction(
                type: .expense,
                unitPrice: 1250,
                quantity: 1,
                amount: 1250,
                currency: currency,
                descriptionText: "Supermercado",
                category: groceriesCategory,
                date: Date(),
                isPending: false
            ),
            Transaction(
                type: .expense,
                unitPrice: 650,
                quantity: 1,
                amount: 650,
                currency: currency,
                descriptionText: "Gasolina",
                category: transportCategory,
                date: Date(),
                isPending: false
            )
        ]

        sampleTransactions.forEach { context.insert($0) }

        let movement = SavingsMovement(type: .deposit, amount: 8500, date: Date())
        let fund = SavingsFund(name: "Fondo de Emergencia", movements: [movement])
        context.insert(fund)
        context.insert(movement)

        try? context.save()

        return container
    }
}
