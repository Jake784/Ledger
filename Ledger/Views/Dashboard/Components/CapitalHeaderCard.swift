//
//  CapitalHeaderCard.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// The Dashboard's headline figure: current capital, shown large and prominent,
/// with a secondary action to adjust it.
///
/// Adjusting capital outside onboarding is a sensitive operation, so the sheet
/// this card presents authenticates via `BiometricAuthService` **before** calling
/// `DashboardViewModel.createCapitalAdjustment` — see that method's doc comment
/// for why this gate is mandatory here (unlike `InitialCapitalView`, which is the
/// one documented exception).
///
/// **Where Used:**
/// - `DashboardView`, as the first element of the Panel screen.
struct CapitalHeaderCard: View {
    let currentCapital: Decimal
    let currency: Currency
    let modelContext: ModelContext

    /// Called after a capital adjustment sheet is dismissed, successful or not,
    /// so the caller can reload `DashboardViewModel` (which does not auto-sync).
    let onAdjusted: () -> Void

    @State private var isPresentingAdjustment = false

    var body: some View {
        Card(tint: .accentColor, padding: 24, topAccent: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Capital Actual", systemImage: "wallet.pass.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .labelStyle(.capitalHeader)

                    Spacer()

                    Button {
                        isPresentingAdjustment = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ajustar capital")
                }

                CurrencyText(
                    amount: currentCapital,
                    currency: currency,
                    size: .large
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isPresentingAdjustment, onDismiss: onAdjusted) {
            CapitalAdjustmentSheet(modelContext: modelContext, currency: currency)
        }
    }
}

/// Matches the icon's tint to the accent color while keeping the label text
/// in the caller's chosen style, since the default `Label` style ties both
/// icon and text color together.
private struct CapitalHeaderLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundStyle(Color.accentColor)
            configuration.title
        }
    }
}

private extension LabelStyle where Self == CapitalHeaderLabelStyle {
    static var capitalHeader: CapitalHeaderLabelStyle { CapitalHeaderLabelStyle() }
}

/// Sheet that authenticates the user, then records a capital adjustment transaction.
///
/// Presented only from `CapitalHeaderCard`, i.e. only outside onboarding — so this
/// is exactly the "later manual correction from the Dashboard" case that
/// `DashboardViewModel.createCapitalAdjustment`'s doc comment requires to be
/// authenticated first.
private struct CapitalAdjustmentSheet: View {
    let modelContext: ModelContext
    let currency: Currency

    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal = 0
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let authService = BiometricAuthService()

    var body: some View {
        VStack(spacing: 24) {
            header

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    amountField
                    noteField
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
            Image(systemName: "faceid")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)

            Text("Ajustar Capital")
                .font(.title2.weight(.bold))

            Text("Este cambio requiere autenticación biométrica para proteger tu capital.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monto del Ajuste")
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

            Text("Usa un valor negativo para disminuir tu capital.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nota (Opcional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Ej. Corrección manual", text: $note)
                .textFieldStyle(.plain)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Cancelar") {
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                handleConfirm()
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Confirmar")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving || amount == 0)
        }
    }

    // MARK: - Actions

    private func handleConfirm() {
        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }

            do {
                let authenticated = try await authService.authenticate(
                    reason: "Confirma para ajustar tu capital"
                )

                guard authenticated else { return }

                let viewModel = DashboardViewModel(modelContext: modelContext)
                try viewModel.createCapitalAdjustment(
                    amount: amount,
                    note: note.isEmpty ? nil : note,
                    currency: currency
                )

                dismiss()
            } catch {
                errorMessage = "No se pudo ajustar el capital. Inténtalo de nuevo."
            }
        }
    }
}

// MARK: - Previews

#Preview("Capital Header Card") {
    let container = OnboardingPreviewContainer.make()
    let currency = try! container.mainContext.fetch(FetchDescriptor<Currency>()).first!

    return CapitalHeaderCard(
        currentCapital: 25750.50,
        currency: currency,
        modelContext: container.mainContext,
        onAdjusted: {}
    )
    .padding()
    .frame(width: 400)
    .modelContainer(container)
}
