//
//  IncomeView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Ingresos (Income) module — history of completed income transactions,
/// with monthly/yearly/historic totals and a form to record new income.
///
/// Mirrors `DashboardView`'s architecture: the view never touches `ModelContext`
/// directly for mutations, only through `TransactionListViewModel`. `Currency`
/// and `Category` are read via `@Query`, the same read-only pattern `DashboardView`
/// already uses for `Currency`/`UserProfile`.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.ingresos`.
struct IncomeView: View {
    @State private var viewModel: TransactionListViewModel
    @State private var isPresentingAddTransaction = false

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Category.name) private var allCategories: [Category]

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TransactionListViewModel(modelContext: modelContext, type: .income))
    }

    var body: some View {
        ScrollView {
            if viewModel.isEmpty {
                EmptyStateView(
                    icon: "arrow.down.circle",
                    title: "Aún no tienes ingresos este mes",
                    subtitle: "Registra tu primer ingreso para empezar a ver tu historial aquí.",
                    actionTitle: "Agregar Ingreso",
                    action: { isPresentingAddTransaction = true }
                )
                .padding(.top, 60)
            } else if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    summarySection(currency: currency)
                    historySection(currency: currency)
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Ingresos")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingAddTransaction = true
                } label: {
                    Label("Agregar Ingreso", systemImage: "plus")
                }
            }
        }
        .onAppear {
            viewModel.loadTransactions()
        }
        .sheet(isPresented: $isPresentingAddTransaction, onDismiss: { viewModel.loadTransactions() }) {
            if let currency = displayCurrency {
                AddIncomeSheet(viewModel: viewModel, currency: currency, categories: incomeCategories)
            }
        }
    }

    // MARK: - Sections

    private func summarySection(currency: Currency) -> some View {
        HStack(spacing: 16) {
            MetricCard(
                label: "Este Mes",
                value: viewModel.totalThisMonth,
                currency: currency,
                color: .green,
                icon: "calendar",
                tinted: true
            )

            MetricCard(
                label: "Este Año",
                value: viewModel.totalThisYear,
                currency: currency,
                color: .green,
                icon: "calendar.badge.clock"
            )

            MetricCard(
                label: "Histórico",
                value: viewModel.totalHistoric,
                currency: currency,
                color: .green,
                icon: "clock.arrow.circlepath"
            )
        }
    }

    private func historySection(currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historial")
                .font(.headline)

            ForEach(viewModel.transactionsGroupedByMonth(), id: \.month) { group in
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(group.month.capitalized)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()

                            CurrencyText(
                                amount: group.subtotal,
                                currency: currency,
                                size: .small,
                                color: .green
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

    // MARK: - Derived Data

    private var incomeCategories: [Category] {
        allCategories.filter { $0.type == .income }
    }

    /// The currency used across this view, resolved the same way `DashboardView` does.
    private var displayCurrency: Currency? {
        userProfiles.first?.preferredCurrency
            ?? currencies.first(where: { $0.isDefault })
            ?? currencies.first
    }
}

// MARK: - Add Income Sheet

/// Form for recording a new completed income transaction.
///
/// Calls straight through to `TransactionListViewModel.addTransaction`, which
/// already handles amount calculation and persistence — this sheet only collects input.
///
/// **Where Used:**
/// - `IncomeView`'s own "Agregar Ingreso" toolbar action.
/// - `DashboardView`'s "Agregar Ingreso" quick action, reusing this exact form
///   rather than duplicating it.
struct AddIncomeSheet: View {
    let viewModel: TransactionListViewModel
    let currency: Currency
    let categories: [Category]

    @Environment(\.dismiss) private var dismiss

    @State private var descriptionText: String = ""
    @State private var amount: Decimal = 0
    @State private var selectedCategory: Category?
    @State private var date: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// The keyboard-navigable fields, in Tab order. `category` needs an
    /// explicit case (not just auto-focus): a `.menu`-style `Picker` is
    /// backed by an `NSPopUpButton`, which macOS excludes from the default
    /// Tab loop unless the user has System Settings' Full Keyboard Access
    /// enabled — without `.focusable()` + this binding, Tab silently skips
    /// straight from Amount to Date.
    private enum Field: Hashable {
        case description
        case amount
        case category
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 24) {
            header

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    descriptionField
                    amountField
                    categoryPicker
                    datePicker
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
        .onAppear {
            focusedField = .description
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Nuevo Ingreso")
                .font(.title2.weight(.bold))
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descripción")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Ej. Salario de agosto", text: $descriptionText)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .description)
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monto")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currency.symbol)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.green)

                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .focused($focusedField, equals: .amount)
            }
        }
    }

    private var categoryPicker: some View {
        Picker("Categoría", selection: $selectedCategory) {
            Text("Sin categoría").tag(Category?.none)
            ForEach(categories) { category in
                Text(category.name).tag(Optional(category))
            }
        }
        .pickerStyle(.menu)
        // `.menu` pickers are backed by NSPopUpButton, which macOS leaves out
        // of the Tab key loop by default — `.focusable()` opts it back in so
        // Tab reaches Category without depending on the user's system-wide
        // Full Keyboard Access setting.
        .focusable()
        .focused($focusedField, equals: .category)
    }

    private var datePicker: some View {
        DatePicker("Fecha", selection: $date, displayedComponents: .date)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Cancelar") {
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)

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
            .disabled(isSaving || descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount <= 0)
            // Makes this the window's default button, so Return submits from
            // any field — standard macOS form behavior — without hijacking
            // Return in individual fields to mean "next field" instead.
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Actions

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        do {
            try viewModel.addTransaction(
                unitPrice: amount,
                quantity: 1,
                descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory,
                date: date,
                currency: currency
            )
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "No se pudo guardar el ingreso. Inténtalo de nuevo."
        }
    }
}

// MARK: - Previews

#Preview("Income") {
    let container = IncomePreviewContainer.make()

    return NavigationStack {
        IncomeView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

#Preview("Income - Empty State") {
    let container = IncomePreviewContainer.make(seedTransactions: false)

    return NavigationStack {
        IncomeView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `IncomeView`.
private enum IncomePreviewContainer {
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
                type: .income,
                unitPrice: 1200,
                amount: 1200,
                currency: currency,
                descriptionText: "Proyecto freelance",
                category: salaryCategory,
                date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                isPending: false
            )
        ]
        transactions.forEach { context.insert($0) }

        try? context.save()
        return container
    }
}
