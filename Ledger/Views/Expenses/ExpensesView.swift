//
//  ExpensesView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Gastos (Expense) module — history of completed expenses, a section
/// for pending (planned) expenses, and a form to record new ones.
///
/// **Recurring vs. pending, as modeled by `Transaction`/`RecurrenceRule`:**
/// "Pending" and "recurring" are independent, orthogonal attributes on `Transaction`:
/// - `isPending`: whether the transaction has actually occurred yet (`false` = completed).
/// - `recurrenceRule`: optional `RecurrenceRule` describing a repeating schedule
///   (monthly/weekly). A transaction can be pending without recurring (a one-off
///   planned expense) or recurring (always created as pending — see `RecurrenceRule`'s
///   cascade delete on `Transaction.recurrenceRule`).
///
/// Mirrors `DashboardView`'s architecture: the view never touches `ModelContext`
/// directly for mutations, only through `TransactionListViewModel`. `Currency`
/// and `Category` are read via `@Query`, the same read-only pattern `DashboardView`
/// already uses for `Currency`/`UserProfile`.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.gastos`.
struct ExpensesView: View {
    @State private var viewModel: TransactionListViewModel
    @State private var isPresentingAddTransaction = false
    @State private var transactionBeingEdited: Transaction?
    @State private var transactionPendingDeletion: Transaction?

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Category.name) private var allCategories: [Category]

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TransactionListViewModel(modelContext: modelContext, type: .expense))
    }

    var body: some View {
        ScrollView {
            if viewModel.isEmpty {
                EmptyStateView(
                    icon: "arrow.up.circle",
                    title: "Aún no tienes gastos este mes",
                    subtitle: "Registra tu primer gasto para empezar a ver tu historial aquí.",
                    actionTitle: "Agregar Gasto",
                    action: { isPresentingAddTransaction = true }
                )
                .padding(.top, 60)
            } else if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    summarySection(currency: currency)
                    pendingSection(currency: currency)
                    historySection(currency: currency)
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Gastos")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingAddTransaction = true
                } label: {
                    Label("Agregar Gasto", systemImage: "plus")
                }
            }
        }
        .onAppear {
            viewModel.loadTransactions()
        }
        .sheet(isPresented: $isPresentingAddTransaction, onDismiss: { viewModel.loadTransactions() }) {
            if let currency = displayCurrency {
                AddExpenseSheet(viewModel: viewModel, currency: currency, categories: expenseCategories)
            }
        }
        .sheet(item: $transactionBeingEdited, onDismiss: { viewModel.loadTransactions() }) { transaction in
            if let currency = displayCurrency {
                AddExpenseSheet(
                    viewModel: viewModel,
                    currency: currency,
                    categories: expenseCategories,
                    existingTransaction: transaction
                )
            }
        }
        .alert(
            "¿Eliminar este gasto?",
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

    // MARK: - Sections

    private func summarySection(currency: Currency) -> some View {
        HStack(spacing: 16) {
            MetricCard(
                label: "Este Mes",
                value: viewModel.totalThisMonth,
                currency: currency,
                color: .red,
                icon: "calendar",
                tinted: true
            )

            MetricCard(
                label: "Este Año",
                value: viewModel.totalThisYear,
                currency: currency,
                color: .red,
                icon: "calendar.badge.clock"
            )

            MetricCard(
                label: "Histórico",
                value: viewModel.totalHistoric,
                currency: currency,
                color: .red,
                icon: "clock.arrow.circlepath"
            )
        }
    }

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
                            pendingRow(transaction, currency: currency)
                        }
                    }
                }
            }
        }
    }

    private func pendingRow(_ transaction: Transaction, currency: Currency) -> some View {
        HStack {
            TransactionRow(
                transaction: transaction,
                currency: currency,
                onEdit: { transactionBeingEdited = transaction },
                onDelete: { transactionPendingDeletion = transaction }
            )

            Button {
                completePending(transaction)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Marcar como completado")
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
                                color: .red
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

    // MARK: - Actions

    private func completePending(_ transaction: Transaction) {
        try? viewModel.completePendingTransaction(transaction)
    }

    private func deleteTransaction(_ transaction: Transaction) {
        try? viewModel.deleteTransaction(transaction)
    }

    // MARK: - Derived Data

    private var expenseCategories: [Category] {
        allCategories.filter { $0.type == .expense }
    }

    /// The currency used across this view, resolved the same way `DashboardView` does.
    private var displayCurrency: Currency? {
        userProfiles.first?.preferredCurrency
            ?? currencies.first(where: { $0.isDefault })
            ?? currencies.first
    }
}

// MARK: - Add Expense Sheet

/// Form for recording a new expense — either completed now ("Puntual") or
/// planned for later ("Pendiente"), optionally on a recurring schedule.
///
/// Calls straight through to `TransactionListViewModel.addTransaction` or
/// `.addPendingTransaction`, which already handle amount calculation,
/// `RecurrenceRule` persistence, and reloading — this sheet only collects input.
///
/// **Where Used:**
/// - `ExpensesView`'s own "Agregar Gasto" toolbar action, and tapping an existing
///   row (edit mode, via `existingTransaction`).
/// - `DashboardView`'s "Agregar Gasto" quick action, reusing this exact form
///   rather than duplicating it.
/// - `HistoryView`, tapping an expense row (edit mode).
struct AddExpenseSheet: View {
    let viewModel: TransactionListViewModel
    let currency: Currency
    let categories: [Category]
    let existingTransaction: Transaction?

    @Environment(\.dismiss) private var dismiss

    private enum EntryKind: String, CaseIterable, Identifiable {
        case puntual = "Puntual"
        case pendiente = "Pendiente"
        var id: String { rawValue }
    }

    @State private var entryKind: EntryKind
    @State private var descriptionText: String
    @State private var amount: Decimal
    @State private var selectedCategory: Category?
    @State private var date: Date
    @State private var isRecurring = false
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isPresentingCalendar = false

    /// `existingTransaction`'s `unitPrice` (not `amount`) prefills `amount` below —
    /// this form always saves with `quantity: 1`, so `unitPrice` IS the number the
    /// user originally typed into this same field. `entryKind` prefills from
    /// `isPending` purely so `datePicker`'s "Fecha Prevista" vs. "Fecha" label stays
    /// accurate while editing — the picker itself is hidden in edit mode (see
    /// `entryKindPicker`'s call site in `body`), since converting between puntual
    /// and pendiente, or editing recurrence, isn't something `updateTransaction`
    /// supports (that's `completePendingTransaction`'s job elsewhere).
    init(
        viewModel: TransactionListViewModel,
        currency: Currency,
        categories: [Category],
        existingTransaction: Transaction? = nil
    ) {
        self.viewModel = viewModel
        self.currency = currency
        self.categories = categories
        self.existingTransaction = existingTransaction

        _entryKind = State(initialValue: existingTransaction?.isPending == true ? .pendiente : .puntual)
        _descriptionText = State(initialValue: existingTransaction?.descriptionText ?? "")
        _amount = State(initialValue: existingTransaction?.unitPrice ?? 0)
        _selectedCategory = State(initialValue: existingTransaction?.category)
        _date = State(initialValue: existingTransaction?.date ?? Date())
    }

    private var isEditing: Bool { existingTransaction != nil }

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

            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 16) {
                    if !isEditing {
                        entryKindPicker
                    }
                    descriptionField
                    amountField
                    categoryPicker
                    datePicker
                    if entryKind == .pendiente && !isEditing {
                        recurrenceToggle
                        if isRecurring {
                            frequencyPicker
                        }
                    }
                }
                .padding(20)
            }
            .formGlassCard()

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
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            Text(isEditing ? "Editar Gasto" : "Nuevo Gasto")
                .font(.title2.weight(.bold))
        }
    }

    /// A glass-pill segmented toggle for `entryKind`, replacing the native
    /// `.segmented` picker's flat blue fill — same glass-capsule-on-selection
    /// idiom as the sidebar's `SidebarRow` (`ViewsSharedNavigationSidebar.swift`),
    /// reused here for visual consistency rather than reinvented. No nested
    /// `GlassEffectContainer` needed — the whole form body already sits
    /// inside one (see `body`), which is where these glass effects render.
    private var entryKindPicker: some View {
        HStack(spacing: 4) {
            ForEach(EntryKind.allCases) { kind in
                EntryKindToggleButton(
                    title: kind.rawValue,
                    isSelected: entryKind == kind,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            entryKind = kind
                        }
                    }
                )
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tipo")
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descripción")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Ej. Renta de agosto", text: $descriptionText)
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
                    .foregroundStyle(.red)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .formGlassField()
    }

    /// Keeps the native date field (so typing a date still works exactly as
    /// before) and adds an explicit calendar button that opens a `.graphical`
    /// popover — closer to Calendar.app than the old plain stepper-only
    /// field. (`DatePickerStyle.compact` looks identical to `.automatic` for
    /// a date-only picker on macOS — it doesn't expose its own popover
    /// trigger here — so the popover is built explicitly instead of relying
    /// on that style.)
    private var datePicker: some View {
        HStack(spacing: 8) {
            DatePicker(entryKind == .pendiente ? "Fecha Prevista" : "Fecha", selection: $date, displayedComponents: .date)

            Spacer(minLength: 0)

            Button {
                isPresentingCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Elegir fecha en el calendario")
            .popover(isPresented: $isPresentingCalendar) {
                DatePicker(
                    entryKind == .pendiente ? "Fecha Prevista" : "Fecha",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .formGlassField()
    }

    private var recurrenceToggle: some View {
        Toggle("¿Es recurrente?", isOn: $isRecurring)
    }

    private var frequencyPicker: some View {
        Picker("Frecuencia", selection: $frequency) {
            Text("Mensual").tag(RecurrenceFrequency.monthly)
            Text("Semanal").tag(RecurrenceFrequency.weekly)
        }
        .pickerStyle(.segmented)
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

        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let existingTransaction {
                try viewModel.updateTransaction(
                    existingTransaction,
                    unitPrice: amount,
                    quantity: 1,
                    descriptionText: trimmedDescription,
                    category: selectedCategory,
                    date: date
                )
            } else {
                switch entryKind {
                case .puntual:
                    try viewModel.addTransaction(
                        unitPrice: amount,
                        quantity: 1,
                        descriptionText: trimmedDescription,
                        category: selectedCategory,
                        date: date,
                        currency: currency
                    )
                case .pendiente:
                    let recurrenceRule: RecurrenceRule? = isRecurring
                        ? RecurrenceRule(frequency: frequency, startDate: date)
                        : nil

                    try viewModel.addPendingTransaction(
                        unitPrice: amount,
                        quantity: 1,
                        descriptionText: trimmedDescription,
                        category: selectedCategory,
                        date: date,
                        currency: currency,
                        recurrenceRule: recurrenceRule
                    )
                }
            }
            dismiss()
        } catch {
            isSaving = false
            errorMessage = isEditing
                ? "No se pudo actualizar el gasto. Inténtalo de nuevo."
                : "No se pudo guardar el gasto. Inténtalo de nuevo."
        }
    }
}

/// A single segment of `AddExpenseSheet`'s `entryKindPicker`; becomes a
/// tinted glass capsule while selected. Mirrors `SidebarRow`
/// (`ViewsSharedNavigationSidebar.swift`) — including its `.contentShape`
/// fix, so this control doesn't reintroduce the same dead-zone click bug.
private struct EntryKindToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                label.glassEffect(.regular.tint(Color.accentColor.opacity(0.25)), in: .capsule)
            } else {
                label
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var label: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Expenses") {
    let container = ExpensesPreviewContainer.make()

    return NavigationStack {
        ExpensesView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

#Preview("Expenses - Empty State") {
    let container = ExpensesPreviewContainer.make(seedTransactions: false)

    return NavigationStack {
        ExpensesView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `ExpensesView`.
private enum ExpensesPreviewContainer {
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
        let foodCategory = categories.first { $0.type == .expense }
        let housingCategory = categories.first { $0.name == "Vivienda" }

        let completed = Transaction(
            type: .expense,
            unitPrice: 900,
            amount: 900,
            currency: currency,
            descriptionText: "Supermercado",
            category: foodCategory,
            date: Date(),
            isPending: false
        )
        context.insert(completed)

        let recurrenceRule = RecurrenceRule(frequency: .monthly, startDate: Date())
        context.insert(recurrenceRule)

        let pendingRecurring = Transaction(
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
        context.insert(pendingRecurring)

        try? context.save()
        return container
    }
}
