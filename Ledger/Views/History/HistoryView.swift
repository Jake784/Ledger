//
//  HistoryView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Historial (History) module — a combined, chronological view of every
/// income and expense transaction, with filtering by type, category, description, and date.
///
/// Mirrors `DashboardView`/`IncomeView`/`ExpensesView`'s architecture: the view never
/// touches `ModelContext` directly, only through `HistoryViewModel` — plus, for editing
/// (see `incomeViewModel`/`expenseViewModel` below), the same per-type
/// `TransactionListViewModel` every other module already uses. `Currency` and `Category`
/// are read via `@Query`, the same read-only pattern those views already use.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.historial`.
struct HistoryView: View {
    @State private var viewModel: HistoryViewModel

    /// Held purely so `AddIncomeSheet`/`AddExpenseSheet` — typed to `TransactionListViewModel`,
    /// exactly like `DashboardView`'s own quick-action sheets — have something to save an
    /// edit through. Never used for reading/displaying data here; `viewModel.loadTransactions()`
    /// (called on the edit sheet's `onDismiss`) is what refreshes what this view actually shows.
    @State private var incomeViewModel: TransactionListViewModel
    @State private var expenseViewModel: TransactionListViewModel

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Category.name) private var allCategories: [Category]

    @State private var selectedType: TransactionType?
    @State private var selectedCategory: Category?
    @State private var searchText: String = ""
    @State private var isDateFilterEnabled = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    @State private var sortOrder: HistorySortOrder = .newestFirst
    @State private var isFilterPanelExpanded = false

    @State private var transactionBeingEdited: Transaction?
    @State private var transactionPendingDeletion: Transaction?

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: HistoryViewModel(modelContext: modelContext))
        _incomeViewModel = State(initialValue: TransactionListViewModel(modelContext: modelContext, type: .income))
        _expenseViewModel = State(initialValue: TransactionListViewModel(modelContext: modelContext, type: .expense))
    }

    var body: some View {
        ScrollView {
            if viewModel.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Aún no tienes historial de transacciones",
                    subtitle: "Registra ingresos y gastos para empezar a ver tu historial aquí."
                )
                .padding(.top, 60)
            } else if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    if isFilterPanelExpanded {
                        filterBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    pendingSection(currency: currency)
                    historySection(currency: currency)
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Historial")
        .onAppear {
            viewModel.loadTransactions()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbar
            }
        }
        .sheet(item: $transactionBeingEdited, onDismiss: { viewModel.loadTransactions() }) { transaction in
            if let currency = displayCurrency {
                editSheet(for: transaction, currency: currency)
            }
        }
        .alert(
            deleteAlertTitle,
            isPresented: Binding(
                get: { transactionPendingDeletion != nil },
                set: { if !$0 { transactionPendingDeletion = nil } }
            ),
            presenting: transactionPendingDeletion
        ) { transaction in
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                deleteTransaction(transaction)
            }
        } message: { _ in
            Text("Esta acción no se puede deshacer.")
        }
    }

    /// Routes to `AddIncomeSheet` or `AddExpenseSheet` based on the tapped transaction's
    /// own `type` — both already support edit mode via `existingTransaction`, and reuse
    /// the type-matching `incomeViewModel`/`expenseViewModel` held above to save the change.
    @ViewBuilder
    private func editSheet(for transaction: Transaction, currency: Currency) -> some View {
        switch transaction.type {
        case .income:
            AddIncomeSheet(
                viewModel: incomeViewModel,
                currency: currency,
                categories: allCategories.filter { $0.type == .income },
                existingTransaction: transaction
            )
        case .expense:
            AddExpenseSheet(
                viewModel: expenseViewModel,
                currency: currency,
                categories: allCategories.filter { $0.type == .expense },
                existingTransaction: transaction
            )
        case .capitalAdjustment:
            EmptyView()
        }
    }

    private var deleteAlertTitle: String {
        switch transactionPendingDeletion?.type {
        case .income: return "¿Eliminar este ingreso?"
        case .expense: return "¿Eliminar este gasto?"
        case .capitalAdjustment, .none: return "¿Eliminar esta transacción?"
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        try? viewModel.deleteTransaction(transaction)
    }

    // MARK: - Toolbar

    /// Hosted via `.toolbar(placement: .primaryAction)` above, so it sits inline with
    /// the "Historial" navigation title — the same native title-bar row Finder's own
    /// toolbar occupies — instead of as a separate row in the scrollable content.
    private var toolbar: some View {
        HistoryToolbar(
            sortOrder: $sortOrder,
            isFilterPanelExpanded: $isFilterPanelExpanded,
            searchText: $searchText,
            hasActiveFilters: hasActiveFilters
        )
    }

    // MARK: - Filters

    private var filterBar: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Tipo", selection: $selectedType) {
                    Text("Todos").tag(TransactionType?.none)
                    Text("Ingresos").tag(TransactionType?.some(.income))
                    Text("Gastos").tag(TransactionType?.some(.expense))
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 16) {
                    Picker("Categoría", selection: $selectedCategory) {
                        Text("Todas las categorías").tag(Category?.none)
                        ForEach(allCategories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Filtrar por fecha", isOn: $isDateFilterEnabled.animation())
                }

                if isDateFilterEnabled {
                    HStack(spacing: 16) {
                        DatePicker("Desde", selection: $startDate, in: ...endDate, displayedComponents: .date)
                        DatePicker("Hasta", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                if hasActiveFilters {
                    Button("Limpiar filtros") {
                        clearFilters()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var hasActiveFilters: Bool {
        selectedType != nil || selectedCategory != nil || !searchText.isEmpty || isDateFilterEnabled
    }

    private func clearFilters() {
        selectedType = nil
        selectedCategory = nil
        searchText = ""
        isDateFilterEnabled = false
    }

    private var dateRange: ClosedRange<Date>? {
        guard isDateFilterEnabled else { return nil }
        return startDate <= endDate ? startDate...endDate : endDate...startDate
    }

    private var filteredTransactions: [Transaction] {
        viewModel.filteredTransactions(
            type: selectedType,
            searchText: searchText,
            category: selectedCategory,
            dateRange: dateRange,
            sortAscending: sortOrder == .oldestFirst
        )
    }

    // MARK: - Sections

    @ViewBuilder
    private func pendingSection(currency: Currency) -> some View {
        if !viewModel.pendingTransactions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pendientes")
                    .font(.headline)

                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.pendingTransactions.enumerated()), id: \.element.id) { index, transaction in
                            if index > 0 {
                                Divider()
                            }
                            TransactionRow(
                                transaction: transaction,
                                currency: currency,
                                onEdit: { transactionBeingEdited = transaction },
                                onDelete: { transactionPendingDeletion = transaction }
                            )
                        }
                    }
                }
            }
        }
    }

    private func historySection(currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            let groups = viewModel.groupedByMonth(filteredTransactions, sortAscending: sortOrder == .oldestFirst)

            if groups.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Sin resultados",
                    subtitle: "Intenta con otros filtros.",
                    compact: true
                )
            } else {
                ForEach(groups, id: \.month) { group in
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(group.month.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                SignedCurrencyText(
                                    amount: group.netTotal,
                                    currency: currency,
                                    size: .small
                                )
                            }

                            VStack(spacing: 0) {
                                ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, transaction in
                                    if index > 0 {
                                        Divider()
                                    }
                                    TransactionRow(
                                        transaction: transaction,
                                        currency: currency,
                                        onEdit: { transactionBeingEdited = transaction },
                                        onDelete: { transactionPendingDeletion = transaction }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Derived Data

    /// The currency used across this view, resolved the same way `DashboardView` does.
    private var displayCurrency: Currency? {
        userProfiles.first?.preferredCurrency
            ?? currencies.first(where: { $0.isDefault })
            ?? currencies.first
    }
}

// MARK: - Previews

#Preview("History") {
    let container = HistoryPreviewContainer.make()

    return NavigationStack {
        HistoryView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 800)
}

#Preview("History - Empty State") {
    let container = HistoryPreviewContainer.make(seedTransactions: false)

    return NavigationStack {
        HistoryView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `HistoryView`.
private enum HistoryPreviewContainer {
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
        let profile = UserProfile(name: "Luis", avatarSystemImage: "star.circle.fill", preferredCurrency: currency)
        context.insert(profile)

        guard seedTransactions else {
            try? context.save()
            return container
        }

        let categories = try! context.fetch(FetchDescriptor<Category>())
        let salaryCategory = categories.first { $0.type == .income }
        let foodCategory = categories.first { $0.type == .expense }
        let housingCategory = categories.first { $0.name == "Vivienda" }

        let recurrenceRule = RecurrenceRule(frequency: .monthly, startDate: Date())
        context.insert(recurrenceRule)

        let transactions: [Transaction] = [
            Transaction(
                type: .income,
                unitPrice: 8000,
                amount: 8000,
                currency: currency,
                descriptionText: "Salario",
                category: salaryCategory,
                date: Date(),
                isPending: false
            ),
            Transaction(
                type: .expense,
                unitPrice: 900,
                amount: 900,
                currency: currency,
                descriptionText: "Supermercado",
                category: foodCategory,
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                isPending: false
            ),
            Transaction(
                type: .expense,
                unitPrice: 350,
                amount: 350,
                currency: currency,
                descriptionText: "Cine",
                category: foodCategory,
                date: Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date(),
                isPending: false
            ),
            Transaction(
                type: .expense,
                unitPrice: 3500,
                amount: 3500,
                currency: currency,
                descriptionText: "Renta",
                category: housingCategory,
                date: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                isPending: true,
                recurrenceRule: recurrenceRule
            )
        ]
        transactions.forEach { context.insert($0) }

        try? context.save()
        return container
    }
}
