//
//  BudgetView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Presupuestos (Budget) module — spending limits per expense category
/// for the current month, with real spending progress and over-budget/at-risk states.
///
/// Scoped to the current calendar month only (`BudgetViewModel.copyBudgetToNextMonth()`
/// exists for recurring budgets but isn't wired here — out of scope for this basic view).
///
/// Mirrors `DashboardView`/`IncomeView`/`ExpensesView`/`CategoriesView`'s architecture:
/// the view never touches `ModelContext` directly, only through `BudgetViewModel`.
/// `Currency` and `Category` are read via `@Query`, the same read-only pattern those
/// views already use.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.presupuestos`.
struct BudgetView: View {
    @State private var viewModel: BudgetViewModel
    @State private var isPresentingAddCategory = false
    @State private var editingLimit: BudgetCategoryLimit?
    @State private var limitPendingRemoval: BudgetCategoryLimit?

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Category.name) private var allCategories: [Category]

    private let month = Calendar.current.component(.month, from: Date())
    private let year = Calendar.current.component(.year, from: Date())

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: BudgetViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            if !viewModel.hasBudget {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "Aún no tienes un presupuesto para este mes",
                    subtitle: "Crea un presupuesto para controlar tus gastos por categoría.",
                    actionTitle: "Crear Presupuesto",
                    action: { isPresentingAddCategory = true }
                )
                .padding(.top, 60)
            } else if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    Text(monthYearLabel.capitalized)
                        .font(.title3.weight(.semibold))

                    summarySection(currency: currency)
                    categoriesSection(currency: currency)
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Presupuestos")
        .toolbar {
            if viewModel.hasBudget {
                ToolbarItem {
                    Button {
                        isPresentingAddCategory = true
                    } label: {
                        Label("Agregar Categoría", systemImage: "plus")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadBudget(month: month, year: year)
        }
        .sheet(isPresented: $isPresentingAddCategory) {
            if let currency = displayCurrency {
                CategoryLimitFormSheet(
                    viewModel: viewModel,
                    currency: currency,
                    month: month,
                    year: year,
                    availableCategories: unbudgetedExpenseCategories,
                    editingLimit: nil,
                    isInitialBudget: !viewModel.hasBudget
                )
            }
        }
        .sheet(item: $editingLimit) { limit in
            if let currency = displayCurrency {
                CategoryLimitFormSheet(
                    viewModel: viewModel,
                    currency: currency,
                    month: month,
                    year: year,
                    availableCategories: [],
                    editingLimit: limit,
                    isInitialBudget: false
                )
            }
        }
        .alert(
            "¿Quitar categoría del presupuesto?",
            isPresented: Binding(
                get: { limitPendingRemoval != nil },
                set: { isPresented in if !isPresented { limitPendingRemoval = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                limitPendingRemoval = nil
            }
            Button("Quitar", role: .destructive) {
                confirmRemoval()
            }
        } message: {
            Text("Se eliminará el límite establecido. Tus transacciones no se ven afectadas.")
        }
    }

    // MARK: - Sections

    private func summarySection(currency: Currency) -> some View {
        HStack(spacing: 16) {
            MetricCard(
                label: "Presupuestado",
                value: viewModel.totalBudget,
                currency: currency,
                color: .blue,
                icon: "chart.pie",
                tinted: true
            )

            MetricCard(
                label: "Gastado",
                value: viewModel.totalSpent,
                currency: currency,
                color: viewModel.isWithinBudget ? .blue : .red,
                icon: "arrow.up.circle"
            )

            MetricCard(
                label: viewModel.isWithinBudget ? "Restante" : "Excedido",
                value: viewModel.isWithinBudget ? viewModel.totalRemaining : viewModel.totalOverBudget,
                currency: currency,
                color: viewModel.isWithinBudget ? .green : .red,
                icon: viewModel.isWithinBudget ? "checkmark.circle" : "exclamationmark.triangle"
            )
        }
    }

    private func categoriesSection(currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categorías")
                .font(.headline)

            ForEach(viewModel.categoryProgress, id: \.limit.id) { progress in
                budgetRow(progress, currency: currency)
            }
        }
    }

    private func budgetRow(
        _ progress: (limit: BudgetCategoryLimit, spent: Decimal, remaining: Decimal, percentageUsed: Double),
        currency: Currency
    ) -> some View {
        Card {
            if let category = progress.limit.category {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.body)
                            .foregroundStyle(Color(hex: category.color))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: category.color).opacity(0.15))
                            .clipShape(Circle())

                        Text(category.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if progress.percentageUsed > 100 {
                            StatusBadge.overBudget()
                        } else if progress.percentageUsed >= 80 {
                            StatusBadge.atRisk()
                        }

                        Spacer()

                        Button {
                            editingLimit = progress.limit
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Editar límite")

                        Button {
                            limitPendingRemoval = progress.limit
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quitar categoría")
                    }

                    LabeledProgressBarView(
                        current: progress.spent,
                        target: progress.limit.limitAmount,
                        currency: currency,
                        color: severityColor(for: progress.percentageUsed)
                    )
                }
            } else {
                // The underlying Category was deleted; the limit persists (nullify delete rule)
                // but has nothing left to display or edit — only removal makes sense here.
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)

                    Text("Categoría eliminada")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        limitPendingRemoval = progress.limit
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quitar categoría")
                }
            }
        }
    }

    private func severityColor(for percentageUsed: Double) -> Color {
        if percentageUsed > 100 {
            return .red
        } else if percentageUsed >= 80 {
            return .orange
        } else {
            return .blue
        }
    }

    // MARK: - Removal

    private func confirmRemoval() {
        guard let limit = limitPendingRemoval else { return }
        try? viewModel.removeCategoryFromBudget(limit)
        limitPendingRemoval = nil
    }

    // MARK: - Derived Data

    private var unbudgetedExpenseCategories: [Category] {
        let budgetedCategoryIDs = Set(viewModel.currentBudget?.categoryLimits.compactMap { $0.category?.id } ?? [])
        return allCategories.filter { $0.type == .expense && !budgetedCategoryIDs.contains($0.id) }
    }

    private var monthYearLabel: String {
        var components = DateComponents()
        components.month = month
        components.year = year
        components.day = 1
        let date = Calendar.current.date(from: components) ?? Date()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// The currency used across this view, resolved the same way `DashboardView` does.
    private var displayCurrency: Currency? {
        userProfiles.first?.preferredCurrency
            ?? currencies.first(where: { $0.isDefault })
            ?? currencies.first
    }
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

// MARK: - Category Limit Form Sheet

/// Form for setting a category's budget limit — creates the month's first budget,
/// adds a category to an existing budget, or edits an existing limit's amount,
/// depending on which initializer parameters are supplied.
///
/// Calls straight through to `BudgetViewModel.createBudget`, `.addCategoryToBudget`,
/// or `.updateCategoryLimit` — this sheet only collects input. Matches
/// `CategoryFormSheet`'s precedent: the category itself can't be changed once a
/// limit exists (`updateCategoryLimit` only takes a new amount), so editing shows
/// the category as a fixed label rather than a picker.
private struct CategoryLimitFormSheet: View {
    let viewModel: BudgetViewModel
    let currency: Currency
    let month: Int
    let year: Int
    let availableCategories: [Category]
    let editingLimit: BudgetCategoryLimit?
    let isInitialBudget: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: Category?
    @State private var amount: Decimal
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        viewModel: BudgetViewModel,
        currency: Currency,
        month: Int,
        year: Int,
        availableCategories: [Category],
        editingLimit: BudgetCategoryLimit?,
        isInitialBudget: Bool
    ) {
        self.viewModel = viewModel
        self.currency = currency
        self.month = month
        self.year = year
        self.availableCategories = availableCategories
        self.editingLimit = editingLimit
        self.isInitialBudget = isInitialBudget
        _amount = State(initialValue: editingLimit?.limitAmount ?? 0)
        _selectedCategory = State(initialValue: editingLimit?.category ?? availableCategories.first)
    }

    private var isEditing: Bool { editingLimit != nil }

    var body: some View {
        VStack(spacing: 24) {
            header

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    categorySection
                    amountField
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            actions
        }
        .padding(32)
        .frame(width: 420)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            Text(isEditing ? "Editar Límite" : "Nuevo Límite de Categoría")
                .font(.title2.weight(.bold))
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 8) {
                Text("Categoría")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(editingLimit?.category?.name ?? "—")
                    .font(.body)
            }
        } else if availableCategories.isEmpty {
            Text("Ya tienes un límite para todas tus categorías de gasto.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Categoría")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Categoría", selection: $selectedCategory) {
                    ForEach(availableCategories) { category in
                        Text(category.name).tag(Optional(category))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Límite Mensual")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currency.symbol)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.blue)

                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Cancelar") {
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                handleSave()
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Guardar")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving || amount <= 0 || (!isEditing && selectedCategory == nil))
        }
    }

    // MARK: - Actions

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        do {
            if let editingLimit {
                try viewModel.updateCategoryLimit(editingLimit, newAmount: amount)
            } else if let category = selectedCategory {
                if isInitialBudget {
                    try viewModel.createBudget(month: month, year: year, categoryLimits: [(category: category, limitAmount: amount)])
                } else {
                    try viewModel.addCategoryToBudget(category, limitAmount: amount)
                }
            }
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "No se pudo guardar el límite. Inténtalo de nuevo."
        }
    }
}

// MARK: - Previews

#Preview("Budget") {
    let container = BudgetPreviewContainer.make()

    return NavigationStack {
        BudgetView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

#Preview("Budget - Empty State") {
    let container = BudgetPreviewContainer.make(seedBudget: false)

    return NavigationStack {
        BudgetView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `BudgetView`.
private enum BudgetPreviewContainer {
    static func make(seedBudget: Bool = true) -> ModelContainer {
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
        let profile = UserProfile(name: "Luis", avatarSystemImage: "star.circle.fill", preferredCurrency: currency)
        context.insert(profile)

        guard seedBudget else {
            try? context.save()
            return container
        }

        let categories = try! context.fetch(FetchDescriptor<Category>())
        let foodCategory = categories.first { $0.name == "Alimentación" }!
        let transportCategory = categories.first { $0.name == "Transporte" }!

        let now = Date()

        let foodExpense = Transaction(
            type: .expense,
            unitPrice: 1900,
            amount: 1900,
            currency: currency,
            descriptionText: "Supermercado",
            category: foodCategory,
            date: now,
            isPending: false
        )
        let transportExpense = Transaction(
            type: .expense,
            unitPrice: 850,
            amount: 850,
            currency: currency,
            descriptionText: "Gasolina",
            category: transportCategory,
            date: now,
            isPending: false
        )
        context.insert(foodExpense)
        context.insert(transportExpense)

        let foodLimit = BudgetCategoryLimit(category: foodCategory, limitAmount: 2000)
        let transportLimit = BudgetCategoryLimit(category: transportCategory, limitAmount: 700)
        context.insert(foodLimit)
        context.insert(transportLimit)

        let calendar = Calendar.current
        let budget = Budget(
            month: calendar.component(.month, from: now),
            year: calendar.component(.year, from: now),
            categoryLimits: [foodLimit, transportLimit]
        )
        context.insert(budget)

        try? context.save()
        return container
    }
}
