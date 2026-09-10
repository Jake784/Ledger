//
//  ProjectionsView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData
import Charts

/// FinVault's Proyecciones (Projections) module — annual "what-if" financial
/// simulations, compared against real transaction data as the year plays out.
///
/// **Important, checked against `ProjectionViewModel` rather than assumed:** a
/// projection is scoped to a full calendar year (months 1–12), not an arbitrary
/// N-month horizon — `createProjection(name:year:startingCapitalMode:simulatedStartingCapital:)`
/// only takes a year. Its "time horizon" control here is therefore the year picker
/// on creation, plus switching between existing projections. Recurrence for a
/// projection item is modeled by `ProjectionItem.appliedMonths` (an explicit list of
/// months 1–12 it applies to) — `RecurrenceRule` is never referenced by
/// `ProjectionViewModel` at all; that model belongs to actual pending Transactions
/// in Income/Expenses, not to projections.
///
/// Uses Swift Charts for the projected-vs-real balance trend, matching
/// `CategoryBreakdownChart`'s existing charting approach on the Dashboard.
///
/// Mirrors `DashboardView`/`IncomeView`/`ExpensesView`'s architecture: the view never
/// touches `ModelContext` directly, only through `ProjectionViewModel`.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.proyecciones`.
struct ProjectionsView: View {
    @State private var viewModel: ProjectionViewModel
    @State private var isPresentingCreateProjection = false
    @State private var isPresentingAddItem = false
    @State private var editingItem: ProjectionItem?
    @State private var itemPendingDeletion: ProjectionItem?
    @State private var isPresentingDeleteProjection = false

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Category.name) private var allCategories: [Category]

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: ProjectionViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            if viewModel.allProjections.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Aún no tienes proyecciones",
                    subtitle: "Crea una proyección anual para simular tu capital futuro.",
                    actionTitle: "Crear Proyección",
                    action: { isPresentingCreateProjection = true }
                )
                .padding(.top, 60)
            } else if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    projectionPicker

                    if viewModel.hasProjection {
                        summarySection(currency: currency)
                        accuracySection
                        chartSection(currency: currency)
                        itemsSection(currency: currency)
                    }
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Proyecciones")
        .toolbar {
            ToolbarItemGroup {
                if viewModel.hasProjection {
                    Button {
                        isPresentingAddItem = true
                    } label: {
                        Label("Agregar Concepto", systemImage: "plus")
                    }

                    Button(role: .destructive) {
                        isPresentingDeleteProjection = true
                    } label: {
                        Label("Eliminar Proyección", systemImage: "trash")
                    }
                }

                Button {
                    isPresentingCreateProjection = true
                } label: {
                    Label("Nueva Proyección", systemImage: "plus.rectangle.on.folder")
                }
            }
        }
        .onAppear {
            viewModel.loadAllProjections()
            if viewModel.currentProjection == nil, let first = viewModel.allProjections.first {
                viewModel.loadProjection(first)
            }
        }
        .sheet(isPresented: $isPresentingCreateProjection) {
            CreateProjectionSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isPresentingAddItem) {
            if let currency = displayCurrency {
                ProjectionItemFormSheet(viewModel: viewModel, currency: currency, allCategories: allCategories, editingItem: nil)
            }
        }
        .sheet(item: $editingItem) { item in
            if let currency = displayCurrency {
                ProjectionItemFormSheet(viewModel: viewModel, currency: currency, allCategories: allCategories, editingItem: item)
            }
        }
        .alert(
            "¿Eliminar este concepto?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { isPresented in if !isPresented { itemPendingDeletion = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) { itemPendingDeletion = nil }
            Button("Eliminar", role: .destructive) { confirmDeleteItem() }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .alert(
            "¿Eliminar \"\(viewModel.currentProjection?.name ?? "")\"?",
            isPresented: $isPresentingDeleteProjection
        ) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) { confirmDeleteProjection() }
        } message: {
            Text("Se eliminarán todos sus conceptos. Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Projection Picker

    private var projectionPicker: some View {
        Picker(
            "Proyección",
            selection: Binding(
                get: { viewModel.currentProjection },
                set: { newValue in
                    if let newValue {
                        viewModel.loadProjection(newValue)
                    }
                }
            )
        ) {
            ForEach(viewModel.allProjections) { projection in
                Text("\(projection.name) (\(String(projection.year)))").tag(Optional(projection))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    // MARK: - Summary

    private func summarySection(currency: Currency) -> some View {
        HStack(spacing: 16) {
            MetricCard(
                label: "Fin de Año Proyectado",
                value: viewModel.projectedYearEndBalance,
                currency: currency,
                color: .blue,
                icon: "flag.checkered",
                tinted: true
            )

            MetricCard(
                label: "Proyección Dinámica",
                value: viewModel.dynamicProjection,
                currency: currency,
                color: .purple,
                icon: "sparkles"
            )

            MetricCard(
                label: "Neto Estimado Anual",
                value: viewModel.estimatedAnnualNet,
                currency: currency,
                color: viewModel.estimatedAnnualNet >= 0 ? .green : .red,
                icon: viewModel.estimatedAnnualNet >= 0 ? "arrow.up.right" : "arrow.down.right"
            )
        }
    }

    private var accuracySection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Precisión del Modelo", systemImage: "scope")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(viewModel.modelAccuracy))%")
                        .font(.headline)
                        .foregroundStyle(accuracyColor)
                }

                ProgressBarView(value: viewModel.modelAccuracy / 100.0, color: accuracyColor)

                Text("Compara los meses ya transcurridos contra lo estimado.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accuracyColor: Color {
        if viewModel.modelAccuracy >= 80 {
            return .green
        } else if viewModel.modelAccuracy >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Chart

    private func chartSection(currency: Currency) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Capital Proyectado vs. Real")
                    .font(.headline)

                Chart {
                    ForEach(viewModel.monthlyBreakdown, id: \.month) { entry in
                        LineMark(
                            x: .value("Mes", entry.month),
                            y: .value("Monto", entry.projectedBalance)
                        )
                        .foregroundStyle(by: .value("Serie", "Proyectado"))
                        .symbol(by: .value("Serie", "Proyectado"))
                    }

                    ForEach(viewModel.monthlyBreakdown, id: \.month) { entry in
                        LineMark(
                            x: .value("Mes", entry.month),
                            y: .value("Monto", entry.realBalance)
                        )
                        .foregroundStyle(by: .value("Serie", "Real"))
                        .symbol(by: .value("Serie", "Real"))
                    }
                }
                .chartForegroundStyleScale([
                    "Proyectado": Color.blue,
                    "Real": Color.green
                ])
                .chartXAxis {
                    AxisMarks(values: Array(1...12)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let month = value.as(Int.self), month >= 1, month <= 12 {
                                Text(Self.monthAbbreviations[month - 1])
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
    }

    private static let monthAbbreviations = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]

    // MARK: - Items

    private func itemsSection(currency: Currency) -> some View {
        let grouped = viewModel.itemsGroupedByType()

        return VStack(alignment: .leading, spacing: 24) {
            itemGroup(title: "Ingresos Fijos", icon: "arrow.down.circle", tint: .green, items: grouped[.fixedIncome] ?? [], currency: currency)
            itemGroup(title: "Ingresos Variables", icon: "arrow.down.circle.dotted", tint: .green, items: grouped[.variableIncome] ?? [], currency: currency)
            itemGroup(title: "Gastos Fijos", icon: "arrow.up.circle", tint: .red, items: grouped[.fixedExpense] ?? [], currency: currency)
            itemGroup(title: "Gastos Variables", icon: "arrow.up.circle.dotted", tint: .red, items: grouped[.variableExpense] ?? [], currency: currency)
        }
    }

    @ViewBuilder
    private func itemGroup(title: String, icon: String, tint: Color, items: [ProjectionItem], currency: Currency) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(tint)

                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider()
                            }
                            itemRow(item, currency: currency)
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ item: ProjectionItem, currency: Currency) -> some View {
        HStack(spacing: 12) {
            if let category = item.category {
                Image(systemName: category.icon)
                    .font(.body)
                    .foregroundStyle(Color(hex: category.color))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: category.color).opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.concept)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(appliedMonthsLabel(item.appliedMonths))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CurrencyText(amount: item.estimatedMonthly, currency: currency, size: .regular)

            Button {
                editingItem = item
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Editar concepto")

            Button {
                itemPendingDeletion = item
            } label: {
                Image(systemName: "trash.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Eliminar concepto")
        }
        .padding(.vertical, 2)
    }

    private func appliedMonthsLabel(_ months: [Int]) -> String {
        if months.count == 12 {
            return "Todo el año"
        }
        return months
            .sorted()
            .compactMap { month in
                (month >= 1 && month <= 12) ? Self.monthAbbreviations[month - 1] : nil
            }
            .joined(separator: ", ")
    }

    // MARK: - Deletion

    private func confirmDeleteItem() {
        guard let item = itemPendingDeletion else { return }
        try? viewModel.deleteProjectionItem(item)
        itemPendingDeletion = nil
    }

    private func confirmDeleteProjection() {
        guard let projection = viewModel.currentProjection else { return }
        try? viewModel.deleteProjection(projection)
    }

    // MARK: - Derived Data

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

// MARK: - Create Projection Sheet

/// Form for creating a new annual projection. Calls straight through to
/// `ProjectionViewModel.createProjection`, then loads it so it becomes the
/// active projection — that method itself only reloads `allProjections`.
private struct CreateProjectionSheet: View {
    let viewModel: ProjectionViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var startingCapitalMode: CapitalMode = .actualCapital
    @State private var simulatedStartingCapital: Decimal = 0
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var yearOptions: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 1)...(current + 5))
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                Text("Nueva Proyección")
                    .font(.title2.weight(.bold))
            }

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nombre")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Ej. Escenario Conservador", text: $name)
                            .textFieldStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Año")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Año", selection: $year) {
                            ForEach(yearOptions, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Capital Inicial")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Capital Inicial", selection: $startingCapitalMode) {
                            Text("Capital Actual").tag(CapitalMode.actualCapital)
                            Text("Capital Simulado").tag(CapitalMode.simulatedCapital)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    if startingCapitalMode == .simulatedCapital {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monto Simulado")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            TextField("0.00", value: $simulatedStartingCapital, format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.plain)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

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
                        Text("Crear")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(32)
        .frame(width: 420)
    }

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try viewModel.createProjection(
                name: trimmedName,
                year: year,
                startingCapitalMode: startingCapitalMode,
                simulatedStartingCapital: startingCapitalMode == .simulatedCapital ? simulatedStartingCapital : nil
            )

            if let created = viewModel.allProjections.first(where: { $0.name == trimmedName && $0.year == year }) {
                viewModel.loadProjection(created)
            }

            dismiss()
        } catch {
            isSaving = false
            errorMessage = "No se pudo crear la proyección. Inténtalo de nuevo."
        }
    }
}

// MARK: - Projection Item Form Sheet

/// Form for adding a new concept to the current projection, or editing an existing
/// one. Calls straight through to `ProjectionViewModel.addProjectionItem`/
/// `.updateProjectionItem` — this sheet only collects input. Matches the app's
/// established pattern of locking classification fields on edit:
/// `updateProjectionItem` doesn't take `itemType` or `category`, so those show as
/// fixed labels rather than pickers when editing.
private struct ProjectionItemFormSheet: View {
    let viewModel: ProjectionViewModel
    let currency: Currency
    let allCategories: [Category]
    let editingItem: ProjectionItem?

    @Environment(\.dismiss) private var dismiss

    @State private var concept: String
    @State private var isIncome: Bool
    @State private var isFixed: Bool
    @State private var selectedCategory: Category?
    @State private var estimatedMonthly: Decimal
    @State private var appliedMonths: Set<Int>
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let monthAbbreviations = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]

    init(viewModel: ProjectionViewModel, currency: Currency, allCategories: [Category], editingItem: ProjectionItem?) {
        self.viewModel = viewModel
        self.currency = currency
        self.allCategories = allCategories
        self.editingItem = editingItem

        _concept = State(initialValue: editingItem?.concept ?? "")
        _estimatedMonthly = State(initialValue: editingItem?.estimatedMonthly ?? 0)
        _appliedMonths = State(initialValue: Set(editingItem?.appliedMonths ?? []))

        let itemType = editingItem?.itemType ?? .fixedExpense
        _isIncome = State(initialValue: itemType == .fixedIncome || itemType == .variableIncome)
        _isFixed = State(initialValue: itemType == .fixedIncome || itemType == .fixedExpense)
        _selectedCategory = State(initialValue: editingItem?.category)
    }

    private var isEditing: Bool { editingItem != nil }

    private var availableCategories: [Category] {
        let type: CategoryType = isIncome ? .income : .expense
        return allCategories.filter { $0.type == type }
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                Text(isEditing ? "Editar Concepto" : "Nuevo Concepto")
                    .font(.title2.weight(.bold))
            }

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    classificationSection
                    conceptField
                    categorySection
                    amountField
                    monthsGrid
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
        .frame(width: 460)
    }

    // MARK: - Sections

    @ViewBuilder
    private var classificationSection: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tipo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(classificationLabel)
                    .font(.body)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Ingreso o Gasto", selection: $isIncome) {
                    Text("Ingreso").tag(true)
                    Text("Gasto").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: isIncome) { _, _ in selectedCategory = nil }

                Picker("Fijo o Variable", selection: $isFixed) {
                    Text("Fijo").tag(true)
                    Text("Variable").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var classificationLabel: String {
        let kind = isIncome ? "Ingreso" : "Gasto"
        let frequency = isFixed ? "Fijo" : "Variable"
        return "\(kind) \(frequency)"
    }

    private var conceptField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Concepto")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Ej. Salario Base", text: $concept)
                .textFieldStyle(.plain)
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 8) {
                Text("Categoría")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(editingItem?.category?.name ?? "Sin categoría")
                    .font(.body)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Categoría")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Categoría", selection: $selectedCategory) {
                    Text("Sin categoría").tag(Category?.none)
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
            Text("Monto Mensual Estimado")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currency.symbol)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.blue)

                TextField("0.00", value: $estimatedMonthly, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }
        }
    }

    private var monthsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Meses Aplicables")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(appliedMonths.count == 12 ? "Ninguno" : "Todo el año") {
                    appliedMonths = appliedMonths.count == 12 ? [] : Set(1...12)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    monthToggle(month)
                }
            }
        }
    }

    private func monthToggle(_ month: Int) -> some View {
        let isSelected = appliedMonths.contains(month)
        return Button {
            if isSelected {
                appliedMonths.remove(month)
            } else {
                appliedMonths.insert(month)
            }
        } label: {
            Text(Self.monthAbbreviations[month - 1])
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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
            .disabled(isSaving || concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appliedMonths.isEmpty)
        }
    }

    // MARK: - Actions

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        let trimmedConcept = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedMonths = appliedMonths.sorted()

        do {
            if let editingItem {
                try viewModel.updateProjectionItem(
                    editingItem,
                    concept: trimmedConcept,
                    estimatedMonthly: estimatedMonthly,
                    appliedMonths: sortedMonths
                )
            } else if let category = selectedCategory {
                let itemType: ProjectionItemType = isIncome
                    ? (isFixed ? .fixedIncome : .variableIncome)
                    : (isFixed ? .fixedExpense : .variableExpense)

                try viewModel.addProjectionItem(
                    concept: trimmedConcept,
                    category: category,
                    itemType: itemType,
                    estimatedMonthly: estimatedMonthly,
                    appliedMonths: sortedMonths
                )
            } else {
                isSaving = false
                errorMessage = "Selecciona una categoría."
                return
            }
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "No se pudo guardar el concepto. Inténtalo de nuevo."
        }
    }
}

// MARK: - Previews

#Preview("Projections") {
    let container = ProjectionsPreviewContainer.make()

    return NavigationStack {
        ProjectionsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 1000, height: 900)
}

#Preview("Projections - Empty State") {
    let container = ProjectionsPreviewContainer.make(seedProjection: false)

    return NavigationStack {
        ProjectionsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `ProjectionsView`.
private enum ProjectionsPreviewContainer {
    static func make(seedProjection: Bool = true) -> ModelContainer {
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

        guard seedProjection else {
            try? context.save()
            return container
        }

        let categories = try! context.fetch(FetchDescriptor<Category>())
        let salaryCategory = categories.first { $0.name == "Salario" }
        let foodCategory = categories.first { $0.name == "Alimentación" }

        let year = Calendar.current.component(.year, from: Date())

        let salaryItem = ProjectionItem(
            concept: "Salario Base",
            category: salaryCategory,
            itemType: .fixedIncome,
            estimatedMonthly: 8000,
            appliedMonths: Array(1...12)
        )
        let foodItem = ProjectionItem(
            concept: "Supermercado",
            category: foodCategory,
            itemType: .fixedExpense,
            estimatedMonthly: 1800,
            appliedMonths: Array(1...12)
        )

        let projection = Projection(
            name: "Escenario Base",
            year: year,
            startingCapitalMode: .actualCapital,
            items: [salaryItem, foodItem]
        )

        context.insert(salaryItem)
        context.insert(foodItem)
        context.insert(projection)

        let currentMonth = Calendar.current.component(.month, from: Date())
        if currentMonth > 1, let salary = salaryCategory {
            let realIncome = Transaction(
                type: .income,
                unitPrice: 7800,
                amount: 7800,
                currency: currency,
                descriptionText: "Salario",
                category: salary,
                date: Date(),
                isPending: false
            )
            context.insert(realIncome)
        }

        try? context.save()
        return container
    }
}
