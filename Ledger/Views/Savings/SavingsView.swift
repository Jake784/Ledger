//
//  SavingsView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Ahorro (Savings) module — every savings fund (standalone or goal-linked),
/// its running balance, and its full deposit/withdrawal history.
///
/// **Savings is a "caja chica" — separate from Capital.** Per `DashboardViewModel`'s
/// documented product decision, savings and capital are two INDEPENDENT figures that are
/// never combined or subtracted from each other. This view only ever shows fund balances
/// and movements — it does not read or display `DashboardViewModel.currentCapital`.
///
/// Shows funds linked to a `Goal` alongside standalone ones (tagged with a badge) so this
/// stays the single place to manage ANY fund's movements — matching `SavingsViewModel`'s
/// own documented ownership split: it manages deposits/withdrawals on every fund, while
/// `GoalViewModel` only creates/deletes goal-linked funds.
///
/// Mirrors `DashboardView`/`IncomeView`/`ExpensesView`'s architecture: the view never
/// touches `ModelContext` directly, only through `SavingsViewModel`.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.ahorro`.
struct SavingsView: View {
    @State private var viewModel: SavingsViewModel
    @State private var isPresentingCreateFund = false
    @State private var movementFund: SavingsFund?
    @State private var fundPendingDeletion: SavingsFund?

    @Query(sort: \Currency.code) private var currencies: [Currency]
    @Query private var userProfiles: [UserProfile]

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: SavingsViewModel(modelContext: modelContext))
    }

    var body: some View {
        ScrollView {
            if viewModel.savingsFunds.isEmpty {
                EmptyStateView(
                    icon: "banknote",
                    title: "Aún no tienes ahorros",
                    subtitle: "Crea un fondo de ahorro para comenzar a guardar dinero aparte de tu capital.",
                    actionTitle: "Crear Fondo",
                    action: { isPresentingCreateFund = true }
                )
                .padding(.top, 60)
            } else if let currency = displayCurrency {
                VStack(alignment: .leading, spacing: 24) {
                    MetricCard(
                        label: "Ahorro Total",
                        value: viewModel.totalSavings,
                        currency: currency,
                        color: .blue,
                        icon: "banknote",
                        tinted: true
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Fondos")
                            .font(.headline)

                        ForEach(viewModel.savingsFunds) { fund in
                            fundCard(fund, currency: currency)
                        }
                    }
                }
                .padding(24)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Ahorro")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingCreateFund = true
                } label: {
                    Label("Crear Fondo", systemImage: "plus")
                }
            }
        }
        .onAppear {
            viewModel.loadSavingsFunds()
        }
        .sheet(isPresented: $isPresentingCreateFund) {
            CreateFundSheet(viewModel: viewModel)
        }
        .sheet(item: $movementFund) { fund in
            if let currency = displayCurrency {
                MovementFormSheet(viewModel: viewModel, fund: fund, currency: currency)
            }
        }
        .alert(
            "¿Eliminar este fondo?",
            isPresented: Binding(
                get: { fundPendingDeletion != nil },
                set: { isPresented in if !isPresented { fundPendingDeletion = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                fundPendingDeletion = nil
            }
            Button("Eliminar", role: .destructive) {
                confirmDeleteFund()
            }
        } message: {
            Text("Se perderá todo su historial de movimientos. Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Fund Card

    private func fundCard(_ fund: SavingsFund, currency: Currency) -> some View {
        let isLinked = viewModel.isLinkedToGoal(fund)
        let movements = viewModel.movementHistory(for: fund)

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "banknote.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Circle())

                    Text(fund.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isLinked {
                        StatusBadge(text: "Vinculado a meta", color: .purple, icon: "target")
                    }

                    Spacer()

                    CurrencyText(amount: fund.currentAmount, currency: currency, size: .medium)
                }

                HStack(spacing: 12) {
                    Button("Registrar Movimiento") {
                        movementFund = fund
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if !isLinked {
                        Button {
                            fundPendingDeletion = fund
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Eliminar fondo")
                    }
                }

                if movements.isEmpty {
                    EmptyStateView(icon: "clock", title: "Sin movimientos aún", compact: true)
                } else {
                    Divider()

                    VStack(spacing: 0) {
                        ForEach(Array(movements.enumerated()), id: \.element.id) { index, movement in
                            if index > 0 {
                                Divider()
                            }
                            movementRow(movement, currency: currency)
                        }
                    }
                }
            }
        }
    }

    private func movementRow(_ movement: SavingsMovement, currency: Currency) -> some View {
        let isDeposit = movement.type == .deposit

        return HStack(spacing: 12) {
            Image(systemName: isDeposit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(isDeposit ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDeposit ? "Depósito" : "Retiro")
                    .font(.subheadline)

                HStack(spacing: 6) {
                    if let note = movement.note, !note.isEmpty {
                        Text(note)
                    }
                    Text(Self.dateFormatter.string(from: movement.date))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            SignedCurrencyText(
                amount: isDeposit ? movement.amount : -movement.amount,
                currency: currency,
                size: .regular
            )
        }
        .padding(.vertical, 2)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    // MARK: - Deletion

    private func confirmDeleteFund() {
        guard let fund = fundPendingDeletion else { return }
        try? viewModel.deleteFund(fund)
        fundPendingDeletion = nil
    }

    // MARK: - Derived Data

    /// The currency used across this view, resolved the same way `DashboardView` does.
    private var displayCurrency: Currency? {
        userProfiles.first?.preferredCurrency
            ?? currencies.first(where: { $0.isDefault })
            ?? currencies.first
    }
}

// MARK: - Create Fund Sheet

/// Form for creating a new standalone savings fund (not linked to a goal).
///
/// Calls straight through to `SavingsViewModel.createStandaloneFund` — this sheet
/// only collects input. Goal-linked funds are created exclusively via
/// `GoalViewModel.createGoal`, per that method's own documentation.
private struct CreateFundSheet: View {
    let viewModel: SavingsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                Text("Nuevo Fondo de Ahorro")
                    .font(.title2.weight(.bold))
            }

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Ej. Fondo de Emergencia", text: $name)
                        .textFieldStyle(.plain)
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
        .frame(width: 400)
    }

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        do {
            try viewModel.createStandaloneFund(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "No se pudo crear el fondo. Inténtalo de nuevo."
        }
    }
}

// MARK: - Movement Form Sheet

/// Form for recording a deposit or withdrawal against one fund.
///
/// Calls straight through to `SavingsViewModel.deposit`/`.withdraw` — this sheet
/// only collects input, including surfacing `SavingsViewModelError.insufficientFunds`
/// from `withdraw` as a friendly message rather than reimplementing that validation.
private struct MovementFormSheet: View {
    let viewModel: SavingsViewModel
    let fund: SavingsFund
    let currency: Currency

    @Environment(\.dismiss) private var dismiss

    private enum MovementKind: String, CaseIterable, Identifiable {
        case deposit = "Depositar"
        case withdrawal = "Retirar"
        var id: String { rawValue }
    }

    @State private var kind: MovementKind = .deposit
    @State private var amount: Decimal = 0
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                Text(fund.name)
                    .font(.title2.weight(.bold))

                CurrencyText(amount: fund.currentAmount, currency: currency, size: .medium)
                    .foregroundStyle(.secondary)
            }

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Tipo", selection: $kind) {
                        ForEach(MovementKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monto")
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nota (Opcional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Ej. Ahorro del mes", text: $note)
                            .textFieldStyle(.plain)
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
        .frame(width: 420)
    }

    private func handleSave() {
        isSaving = true
        errorMessage = nil

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch kind {
            case .deposit:
                try viewModel.deposit(to: fund, amount: amount, note: trimmedNote.isEmpty ? nil : trimmedNote)
            case .withdrawal:
                try viewModel.withdraw(from: fund, amount: amount, note: trimmedNote.isEmpty ? nil : trimmedNote)
            }
            dismiss()
        } catch let error as SavingsViewModelError {
            isSaving = false
            switch error {
            case .insufficientFunds:
                errorMessage = "Fondos insuficientes para este retiro."
            case .cannotDeleteLinkedFund:
                errorMessage = "No se pudo completar la operación."
            }
        } catch {
            isSaving = false
            errorMessage = "No se pudo guardar el movimiento. Inténtalo de nuevo."
        }
    }
}

// MARK: - Previews

#Preview("Savings") {
    let container = SavingsPreviewContainer.make()

    return NavigationStack {
        SavingsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 800)
}

#Preview("Savings - Empty State") {
    let container = SavingsPreviewContainer.make(seedFunds: false)

    return NavigationStack {
        SavingsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 700)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `SavingsView`.
private enum SavingsPreviewContainer {
    static func make(seedFunds: Bool = true) -> ModelContainer {
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

        guard seedFunds else {
            try? context.save()
            return container
        }

        let deposit1 = SavingsMovement(type: .deposit, amount: 3000, date: Date(), note: "Ahorro inicial")
        let deposit2 = SavingsMovement(type: .deposit, amount: 1500, date: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date())
        let withdrawal1 = SavingsMovement(type: .withdrawal, amount: 500, date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), note: "Emergencia")

        let emergencyFund = SavingsFund(name: "Fondo de Emergencia", movements: [deposit1, deposit2, withdrawal1])
        context.insert(emergencyFund)
        context.insert(deposit1)
        context.insert(deposit2)
        context.insert(withdrawal1)

        let goalDeposit = SavingsMovement(type: .deposit, amount: 800, date: Date())
        let vacationFund = SavingsFund(name: "Vacaciones", movements: [goalDeposit])
        let vacationGoal = Goal(name: "Vacaciones", targetAmount: 5000, targetDate: Date().addingTimeInterval(60 * 60 * 24 * 90), linkedSavingsFund: vacationFund)
        vacationFund.linkedGoal = vacationGoal
        context.insert(vacationFund)
        context.insert(goalDeposit)
        context.insert(vacationGoal)

        try? context.save()
        return container
    }
}
