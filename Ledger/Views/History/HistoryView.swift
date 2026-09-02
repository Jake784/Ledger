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
/// touches `ModelContext` directly, only through `HistoryViewModel`. `Currency` and
/// `Category` are read via `@Query`, the same read-only pattern those views already use.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.historial`.
struct HistoryView: View {
    @State private var viewModel: HistoryViewModel

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Category.name) private var allCategories: [Category]

    @State private var selectedType: TransactionType?
    @State private var selectedCategory: Category?
    @State private var searchText: String = ""
    @State private var isDateFilterEnabled = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: HistoryViewModel(modelContext: modelContext))
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
                    filterBar
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
    }

    // MARK: - Filters

    private var filterBar: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Buscar por descripción", text: $searchText)
                    .textFieldStyle(.plain)

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
            dateRange: dateRange
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
                            TransactionRow(transaction: transaction, currency: currency)
                        }
                    }
                }
            }
        }
    }

    private func historySection(currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historial")
                .font(.headline)

            let groups = viewModel.groupedByMonth(filteredTransactions)

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
                                    TransactionRow(transaction: transaction, currency: currency)
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
