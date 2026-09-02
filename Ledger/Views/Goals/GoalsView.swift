//
//  GoalsView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Metas (Goals) module — each financial goal with progress toward its
/// linked `SavingsFund` balance, a quick way to contribute, and goal creation.
///
/// Owns both a `GoalViewModel` and a `SavingsViewModel`, exactly as `GoalViewModel`'s
/// own doc comment illustrates: `GoalViewModel` creates/deletes goals and their linked
/// funds, while contributing money toward one is a deposit — `SavingsViewModel`'s
/// exclusive responsibility. Withdrawing from a goal's fund, or managing funds more
/// generally, lives in `SavingsView` (which lists every fund, including goal-linked ones).
///
/// Mirrors `DashboardView`/`IncomeView`/`ExpensesView`'s architecture: the view never
/// touches `ModelContext` directly, only through these two ViewModels.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.metas`.
struct GoalsView: View {
    @State private var goalViewModel: GoalViewModel
    @State private var savingsViewModel: SavingsViewModel
    @State private var isPresentingCreateGoal = false
    @State private var contributingGoal: Goal?
    @State private var goalPendingDeletion: Goal?

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]

    init(modelContext: ModelContext) {
        _goalViewModel = State(initialValue: GoalViewModel(modelContext: modelContext))
        _savingsViewModel = State(initialValue: SavingsViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            if goalViewModel.goals.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "Aún no tienes metas de ahorro",
                    subtitle: "Crea una meta para ahorrar con un objetivo y una fecha claros.",
                    actionTitle: "Crear Meta",
                    action: { isPresentingCreateGoal = true }
                )
                .padding(.top, 60)
            } else if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    MetricCard(
                        label: "Por Alcanzar",
                        value: goalViewModel.totalRemainingAmount,
                        currency: currency,
                        color: .blue,
                        icon: "target",
                        tinted: true
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Metas")
                            .font(.headline)

                        ForEach(goalViewModel.goals) { goal in
                            goalCard(goal, currency: currency)
                        }
                    }
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Metas")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingCreateGoal = true
                } label: {
                    Label("Crear Meta", systemImage: "plus")
                }
            }
        }
        .onAppear {
            goalViewModel.loadGoals()
            savingsViewModel.loadSavingsFunds()
        }
        .sheet(isPresented: $isPresentingCreateGoal) {
            CreateGoalSheet(viewModel: goalViewModel)
        }
        .sheet(item: $contributingGoal) { goal in
            if let currency = displayCurrency {
                ContributeSheet(viewModel: savingsViewModel, goal: goal, currency: currency)
            }
        }
        .alert(
            "¿Eliminar esta meta?",
            isPresented: Binding(
                get: { goalPendingDeletion != nil },
                set: { isPresented in if !isPresented { goalPendingDeletion = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                goalPendingDeletion = nil
            }
            Button("Eliminar", role: .destructive) {
                confirmDeleteGoal()
            }
        } message: {
            Text(deletionWarning)
        }
    }

    // MARK: - Goal Card

    private func goalCard(_ goal: Goal, currency: Currency) -> some View {
        let progress = goalViewModel.progress(for: goal)
        let isOverdue = goalViewModel.isOverdue(goal)
        let isAchieved = progress.percentage >= 100.0

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(deadlineLabel(for: goal))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isAchieved {
                        StatusBadge.achieved()
                    } else if isOverdue {
                        StatusBadge.overdue()
                    } else if goalViewModel.isApproachingDeadline(goal) {
                        StatusBadge(text: "Por vencer", color: .orange, icon: "clock")
                    }

                    Spacer()

                    Button {
                        contributingGoal = goal
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Añadir ahorro")

                    Button {
                        goalPendingDeletion = goal
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Eliminar meta")
                }

                LabeledProgressBarView(
                    current: progress.currentAmount,
                    target: goal.targetAmount,
                    currency: currency,
                    color: isAchieved ? .green : (isOverdue ? .red : .blue)
                )
            }
        }
    }

    private func deadlineLabel(for goal: Goal) -> String {
        let days = goalViewModel.daysUntilDeadline(for: goal)
        let dateText = Self.dateFormatter.string(from: goal.targetDate)

        if days < 0 {
            return "Meta: \(dateText) (vencida)"
        } else if days == 0 {
            return "Meta: \(dateText) (hoy)"
        } else {
            return "Meta: \(dateText) · faltan \(days) días"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    // MARK: - Deletion

    private func confirmDeleteGoal() {
        guard let goal = goalPendingDeletion else { return }
        try? goalViewModel.deleteGoal(goal)
        goalPendingDeletion = nil
    }

    private var deletionWarning: String {
        guard let goal = goalPendingDeletion, let currency = displayCurrency else {
            return "Esta acción no se puede deshacer."
        }
        let progress = goalViewModel.progress(for: goal)
        let movementCount = goal.linkedSavingsFund?.movements.count ?? 0
        let amountText = CurrencyFormatter.string(progress.currentAmount, currency: currency)
        return "Se eliminarán permanentemente \(amountText) en ahorro y \(movementCount) movimiento(s). Esta acción no se puede deshacer."
    }

    // MARK: - Derived Data

    /// The currency used across this view, resolved the same way `DashboardView` does.
    private var displayCurrency: Currency? {
        userProfiles.first?.preferredCurrency
            ?? currencies.first(where: { $0.isDefault })
            ?? currencies.first
    }
}

/// Formats a `Decimal` amount with a currency symbol for interpolation into plain
/// `Text`/alert-message strings, where `CurrencyText`'s view-based formatting can't be used.
/// Scoped to this file since only the deletion warning needs it.
private enum CurrencyFormatter {
    static func string(_ amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency.symbol) \(amountString)"
    }
}

// MARK: - Create Goal Sheet

/// Form for creating a new goal. Calls straight through to `GoalViewModel.createGoal`,
/// which already atomically creates the goal and its linked `SavingsFund` — this sheet
/// only collects input and doesn't touch `SavingsFund` itself.
private struct CreateGoalSheet: View {
    let viewModel: GoalViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var targetAmount: Decimal = 0
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                Text("Nueva Meta")
                    .font(.title2.weight(.bold))
            }

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nombre")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Ej. Vacaciones", text: $name)
                            .textFieldStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monto Objetivo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("0.00", value: $targetAmount, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.plain)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }

                    DatePicker("Fecha Meta", selection: $targetDate, in: Date()..., displayedComponents: .date)
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
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetAmount <= 0)
            }
        }
        .padding(32)
        .frame(width: 420)
    }

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        do {
            try viewModel.createGoal(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                targetAmount: targetAmount,
                targetDate: targetDate
            )
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "No se pudo crear la meta. Inténtalo de nuevo."
        }
    }
}

// MARK: - Contribute Sheet

/// A focused, deposit-only form for contributing toward one goal's linked fund.
/// Calls straight through to `SavingsViewModel.deposit` — the same method `SavingsView`
/// uses for any fund. Withdrawals and full movement history stay in `SavingsView`,
/// since pulling money back out isn't a "goal" action in the same sense as contributing.
private struct ContributeSheet: View {
    let viewModel: SavingsViewModel
    let goal: Goal
    let currency: Currency

    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal = 0
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)

                Text("Añadir Ahorro")
                    .font(.title2.weight(.bold))

                Text(goal.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monto")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(currency.symbol)
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.accentColor)

                        TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.plain)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
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
                        Text("Guardar")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || amount <= 0)
            }
        }
        .padding(32)
        .frame(width: 400)
    }

    private func handleSave() {
        guard let fund = goal.linkedSavingsFund else {
            errorMessage = "Esta meta no tiene un fondo vinculado."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try viewModel.deposit(to: fund, amount: amount, note: nil)
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "No se pudo guardar el ahorro. Inténtalo de nuevo."
        }
    }
}

// MARK: - Previews

#Preview("Goals") {
    let container = GoalsPreviewContainer.make()

    return NavigationStack {
        GoalsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

#Preview("Goals - Empty State") {
    let container = GoalsPreviewContainer.make(seedGoals: false)

    return NavigationStack {
        GoalsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `GoalsView`.
private enum GoalsPreviewContainer {
    static func make(seedGoals: Bool = true) -> ModelContainer {
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

        let currency = try! context.fetch(FetchDescriptor<Currency>()).first!
        let profile = UserProfile(name: "Luis", avatarSystemImage: "star.circle.fill", preferredCurrency: currency)
        context.insert(profile)

        guard seedGoals else {
            try? context.save()
            return container
        }

        let vacationMovement = SavingsMovement(type: .deposit, amount: 3200, date: Date())
        let vacationFund = SavingsFund(name: "Vacaciones", movements: [vacationMovement])
        let vacationGoal = Goal(
            name: "Vacaciones",
            targetAmount: 8000,
            targetDate: Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date(),
            linkedSavingsFund: vacationFund
        )
        vacationFund.linkedGoal = vacationGoal
        context.insert(vacationFund)
        context.insert(vacationMovement)
        context.insert(vacationGoal)

        let carMovement = SavingsMovement(type: .deposit, amount: 12000, date: Date())
        let carFund = SavingsFund(name: "Auto Nuevo", movements: [carMovement])
        let carGoal = Goal(
            name: "Auto Nuevo",
            targetAmount: 12000,
            targetDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            linkedSavingsFund: carFund
        )
        carFund.linkedGoal = carGoal
        context.insert(carFund)
        context.insert(carMovement)
        context.insert(carGoal)

        try? context.save()
        return container
    }
}
