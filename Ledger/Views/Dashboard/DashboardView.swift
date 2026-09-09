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

    /// Owned only for its read-only `goals` (summed into `goalsTargetAmount`, for
    /// the Ahorros card's progress ring) — the Dashboard never creates, edits, or
    /// deletes goals, so this mirrors `DashboardViewModel`'s own manual-refresh
    /// pattern rather than duplicating any of `GoalViewModel`'s logic.
    @State private var goalViewModel: GoalViewModel

    /// Owned only so the Dashboard's "Agregar Ingreso" / "Agregar Gasto" quick
    /// actions can present `IncomeView`/`ExpensesView`'s own add sheets unchanged —
    /// the Dashboard never lists or otherwise reads these view models' state.
    @State private var incomeViewModel: TransactionListViewModel
    @State private var expenseViewModel: TransactionListViewModel

    @State private var isPresentingAddIncome = false
    @State private var isPresentingAddExpense = false

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Category.name) private var allCategories: [Category]

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: DashboardViewModel(modelContext: modelContext))
        _goalViewModel = State(initialValue: GoalViewModel(modelContext: modelContext))
        _incomeViewModel = State(initialValue: TransactionListViewModel(modelContext: modelContext, type: .income))
        _expenseViewModel = State(initialValue: TransactionListViewModel(modelContext: modelContext, type: .expense))
    }

    var body: some View {
        ScrollView {
            if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    capitalSection(currency: currency)
                    quickActionsRow
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
            goalViewModel.loadGoals()
        }
        .sheet(isPresented: $isPresentingAddIncome, onDismiss: { viewModel.loadDashboardData() }) {
            if let currency = displayCurrency {
                AddIncomeSheet(viewModel: incomeViewModel, currency: currency, categories: incomeCategories)
            }
        }
        .sheet(isPresented: $isPresentingAddExpense, onDismiss: { viewModel.loadDashboardData() }) {
            if let currency = displayCurrency {
                AddExpenseSheet(viewModel: expenseViewModel, currency: currency, categories: expenseCategories)
            }
        }
    }

    // MARK: - Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    private var userName: String { userProfiles.first?.name ?? "" }

    private var userInitials: String {
        let letters = userName.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(userName.isEmpty ? greeting : "\(greeting), \(userName)")
                    .font(.title2.weight(.semibold))

                Text(Date.now.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: Locale(identifier: "es"))))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            avatarView
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))

            if userInitials.isEmpty {
                Image(systemName: userProfiles.first?.avatarSystemImage ?? "person.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Text(userInitials)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }

    // MARK: - Bento Sections

    /// "Capital Actual" and "Ahorros" as a paired, equal-hierarchy hero
    /// row — side by side when there's room, stacked with equal weight
    /// otherwise — grouped in one `GlassEffectContainer` since they're
    /// adjacent glass surfaces that should render/refract as a single cluster.
    private func capitalSection(currency: Currency) -> some View {
        GlassEffectContainer {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    capitalHeaderCard(currency: currency)
                    savingsSummaryCard(currency: currency)
                }

                VStack(spacing: 16) {
                    capitalHeaderCard(currency: currency)
                    savingsSummaryCard(currency: currency)
                }
            }
        }
    }

    private func capitalHeaderCard(currency: Currency) -> some View {
        CapitalHeaderCard(
            currentCapital: viewModel.currentCapital,
            currency: currency,
            modelContext: modelContext,
            onAdjusted: { viewModel.loadDashboardData() }
        )
        .frame(maxWidth: .infinity)
    }

    private func savingsSummaryCard(currency: Currency) -> some View {
        SavingsSummaryCard(
            totalSavings: viewModel.totalSavings,
            currency: currency,
            goalsTargetAmount: goalsTargetAmount
        )
        .frame(maxWidth: .infinity)
    }

    private var quickActionsRow: some View {
        GlassEffectContainer {
            HStack(spacing: 16) {
                DashboardQuickActionButton(
                    title: "Agregar Ingreso",
                    icon: "arrow.down.circle.fill",
                    accentColor: .green,
                    action: { isPresentingAddIncome = true }
                )

                DashboardQuickActionButton(
                    title: "Agregar Gasto",
                    icon: "arrow.up.circle.fill",
                    accentColor: .red,
                    action: { isPresentingAddExpense = true }
                )
            }
        }
    }

    private func summaryCardsRow(currency: Currency) -> some View {
        GlassEffectContainer {
            HStack(spacing: 16) {
                DashboardMetricCard(
                    label: "Ingresos del Mes",
                    value: viewModel.monthlyIncome,
                    currency: currency,
                    accentColor: .green,
                    icon: "arrow.down.circle"
                )

                DashboardMetricCard(
                    label: "Gastos del Mes",
                    value: viewModel.monthlyExpenses,
                    currency: currency,
                    accentColor: .red,
                    icon: "arrow.up.circle"
                )
            }
        }
    }

    private func breakdownSection(currency: Currency) -> some View {
        GlassEffectContainer {
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
    }

    // MARK: - Derived Data

    /// Combined target amount across every goal, used by `SavingsSummaryCard`
    /// to render its progress ring. Zero (no ring shown) when the user has no goals.
    private var goalsTargetAmount: Decimal {
        goalViewModel.goals.reduce(Decimal(0)) { $0 + $1.targetAmount }
    }

    private var incomeCategories: [Category] {
        allCategories.filter { $0.type == .income }
    }

    private var expenseCategories: [Category] {
        allCategories.filter { $0.type == .expense }
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
