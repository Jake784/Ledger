//
//  CategoriesView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Categorías module — lists every category (predefined, seeded by
/// `CategorySeeder` at app launch, plus any user-created ones), split into
/// Gastos/Ingresos sections, with create/edit/delete for custom categories.
///
/// Predefined categories (`Category.isCustom == false`) are read-only: `CategoryViewModel`
/// already enforces this by throwing `CategoryViewModelError.cannotModifyPredefinedCategory`
/// from `updateCategory`/`deleteCategory`, so this view simply doesn't offer edit/delete
/// controls on rows where `isCustom` is `false`.
///
/// Mirrors `DashboardView`/`IncomeView`/`ExpensesView`'s architecture: the view never
/// touches `ModelContext` directly, only through `CategoryViewModel`.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.categorias`.
struct CategoriesView: View {
    @State private var viewModel: CategoryViewModel
    @State private var isPresentingAddCategory = false
    @State private var editingCategory: Category?
    @State private var categoryPendingDeletion: Category?
    @State private var pendingDeletionTransactionCount = 0

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: CategoryViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            if viewModel.expenseCategories.isEmpty && viewModel.incomeCategories.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "Aún no tienes categorías",
                    subtitle: "Crea tu primera categoría para organizar tus ingresos y gastos.",
                    actionTitle: "Agregar Categoría",
                    action: { isPresentingAddCategory = true }
                )
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    categorySection(title: "Gastos", icon: "arrow.up.circle", tint: .red, categories: viewModel.expenseCategories)
                    categorySection(title: "Ingresos", icon: "arrow.down.circle", tint: .green, categories: viewModel.incomeCategories)
                }
                .padding(24)
            }
        }
        .navigationTitle("Categorías")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingAddCategory = true
                } label: {
                    Label("Agregar Categoría", systemImage: "plus")
                }
            }
        }
        .onAppear {
            viewModel.loadCategories()
        }
        .sheet(isPresented: $isPresentingAddCategory, onDismiss: { viewModel.loadCategories() }) {
            CategoryFormSheet(viewModel: viewModel)
        }
        .sheet(item: $editingCategory, onDismiss: { viewModel.loadCategories() }) { category in
            CategoryFormSheet(viewModel: viewModel, editingCategory: category)
        }
        .alert(
            "¿Eliminar categoría?",
            isPresented: Binding(
                get: { categoryPendingDeletion != nil },
                set: { isPresented in if !isPresented { categoryPendingDeletion = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                categoryPendingDeletion = nil
            }
            Button("Eliminar", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text(deletionWarning)
        }
    }

    // MARK: - Sections

    private func categorySection(title: String, icon: String, tint: Color, categories: [Category]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)

            if categories.isEmpty {
                EmptyStateView(
                    icon: icon,
                    title: "Sin categorías de \(title.lowercased())",
                    compact: true
                )
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            if index > 0 {
                                Divider()
                            }
                            categoryRow(category)
                        }
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
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

            StatusBadge(
                text: category.isCustom ? "Personalizada" : "Predefinida",
                color: category.isCustom ? .blue : .gray
            )

            Spacer()

            if category.isCustom {
                Button {
                    editingCategory = category
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Editar categoría")

                Button {
                    requestDelete(category)
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eliminar categoría")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Deletion

    private func requestDelete(_ category: Category) {
        pendingDeletionTransactionCount = viewModel.transactionCount(for: category)
        categoryPendingDeletion = category
    }

    private func confirmDelete() {
        guard let category = categoryPendingDeletion else { return }
        try? viewModel.deleteCategory(category)
        categoryPendingDeletion = nil
    }

    private var deletionWarning: String {
        guard let category = categoryPendingDeletion else { return "" }

        if pendingDeletionTransactionCount > 0 {
            return "\(pendingDeletionTransactionCount) transacción(es) usan \"\(category.name)\" y quedarán sin categoría. Esta acción no se puede deshacer."
        }
        return "Esta acción no se puede deshacer."
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

// MARK: - Category Form Sheet

/// Form for creating a new custom category, or editing an existing custom one.
///
/// Calls straight through to `CategoryViewModel.addCustomCategory` or
/// `.updateCategory` — this sheet only collects input. `type` can only be set
/// at creation time: `updateCategory` doesn't take a `type` parameter, since
/// changing a category's type out from under existing transactions would be
/// misleading, so editing keeps the original type fixed.
private struct CategoryFormSheet: View {
    let viewModel: CategoryViewModel
    let editingCategory: Category?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var type: CategoryType
    @State private var icon: String
    @State private var color: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let iconOptions = [
        "tag.fill", "cart.fill", "house.fill", "car.fill",
        "fork.knife", "heart.fill", "gift.fill", "bolt.fill",
        "book.fill", "gamecontroller.fill", "airplane", "briefcase.fill"
    ]

    private static let colorOptions = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#5AC8FA", "#007AFF", "#5856D6", "#AF52DE",
        "#FF2D55", "#A2845E", "#8E8E93", "#00C7BE"
    ]

    init(viewModel: CategoryViewModel, editingCategory: Category? = nil) {
        self.viewModel = viewModel
        self.editingCategory = editingCategory
        _name = State(initialValue: editingCategory?.name ?? "")
        _type = State(initialValue: editingCategory?.type ?? .expense)
        _icon = State(initialValue: editingCategory?.icon ?? Self.iconOptions[0])
        _color = State(initialValue: editingCategory?.color ?? Self.colorOptions[0])
    }

    private var isEditing: Bool { editingCategory != nil }

    var body: some View {
        VStack(spacing: 24) {
            header

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    nameField
                    if !isEditing {
                        typePicker
                    }
                    iconPicker
                    colorPicker
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

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(Color(hex: color))
                .frame(width: 64, height: 64)
                .background(Color(hex: color).opacity(0.15))
                .clipShape(Circle())

            Text(isEditing ? "Editar Categoría" : "Nueva Categoría")
                .font(.title2.weight(.bold))
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nombre")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Ej. Mascotas", text: $name)
                .textFieldStyle(.plain)
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tipo")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Tipo", selection: $type) {
                Text("Gasto").tag(CategoryType.expense)
                Text("Ingreso").tag(CategoryType.income)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ícono")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(Self.iconOptions, id: \.self) { symbol in
                    iconButton(symbol)
                }
            }
        }
    }

    private func iconButton(_ symbol: String) -> some View {
        let isSelected = symbol == icon
        return Button {
            icon = symbol
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? .white : Color(hex: color))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color(hex: color) : Color(hex: color).opacity(0.12))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color(hex: color), lineWidth: isSelected ? 0 : 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(Self.colorOptions, id: \.self) { hex in
                    colorSwatch(hex)
                }
            }
        }
    }

    private func colorSwatch(_ hex: String) -> some View {
        let isSelected = hex == color
        return Button {
            color = hex
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .opacity(isSelected ? 1 : 0)
                )
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.6), lineWidth: isSelected ? 2 : 0)
                        .padding(-2)
                )
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
            .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Actions

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let editingCategory {
                try viewModel.updateCategory(editingCategory, name: trimmedName, icon: icon, color: color)
            } else {
                try viewModel.addCustomCategory(name: trimmedName, type: type, icon: icon, color: color)
            }
            dismiss()
        } catch {
            isSaving = false
            errorMessage = isEditing
                ? "No se pudo actualizar la categoría. Inténtalo de nuevo."
                : "No se pudo guardar la categoría. Inténtalo de nuevo."
        }
    }
}

// MARK: - Previews

#Preview("Categories") {
    let container = CategoriesPreviewContainer.make()

    return NavigationStack {
        CategoriesView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

#Preview("Categories - Empty State") {
    let container = CategoriesPreviewContainer.make(seedCategories: false)

    return NavigationStack {
        CategoriesView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `CategoriesView`.
private enum CategoriesPreviewContainer {
    static func make(seedCategories: Bool = true) -> ModelContainer {
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

        guard seedCategories else {
            try? context.save()
            return container
        }

        CategorySeeder.seedIfNeeded(context: context)

        let customCategory = Category(
            name: "Suscripciones de Streaming",
            type: .expense,
            icon: "gamecontroller.fill",
            color: "#AF52DE",
            isCustom: true
        )
        context.insert(customCategory)

        try? context.save()
        return container
    }
}
