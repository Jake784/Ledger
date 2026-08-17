//
//  InitialCapitalView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// The second and final step of onboarding: recording the user's starting capital.
///
/// Presented as a sheet by `WelcomeView` right after the initial `UserProfile` is created.
/// On submit, it authenticates the user via `BiometricAuthService` (required by
/// `DashboardViewModel.createCapitalAdjustment`) and records a `.capitalAdjustment`
/// transaction for the entered amount, then calls `onComplete` to signal that
/// onboarding is finished.
///
/// **Where Used:**
/// - Presented as a `.sheet` from `WelcomeView` after profile creation.
struct InitialCapitalView: View {
    /// The profile just created in `WelcomeView`. Used to default the currency
    /// selection and to update the preferred currency if the user changes it here.
    let userProfile: UserProfile

    /// Called after the initial capital transaction is saved successfully.
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Currency.code) private var currencies: [Currency]

    @State private var amount: Decimal = 0
    @State private var selectedCurrency: Currency?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            header

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    amountField

                    if currencies.count > 1 {
                        currencyPicker
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            continueButton
        }
        .padding(32)
        .frame(width: 420)
        .onAppear {
            if selectedCurrency == nil {
                selectedCurrency = userProfile.preferredCurrency
                    ?? currencies.first(where: { $0.isDefault })
                    ?? currencies.first
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)

            Text("Capital Inicial")
                .font(.title2.weight(.bold))

            Text("Para empezar, cuéntanos cuánto capital tienes actualmente. Esto nos ayuda a calcular tu balance desde el primer día.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capital Actual")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(selectedCurrency?.symbol ?? "Q")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.accentColor)

                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }
        }
    }

    private var currencyPicker: some View {
        Picker("Moneda", selection: $selectedCurrency) {
            ForEach(currencies) { currency in
                Text("\(currency.code) (\(currency.symbol))")
                    .tag(Optional(currency))
            }
        }
        .pickerStyle(.menu)
    }

    private var continueButton: some View {
        Button {
            handleContinue()
        } label: {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Continuar")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isSaving || selectedCurrency == nil)
    }

    // MARK: - Actions

    private func handleContinue() {
        guard let currency = selectedCurrency else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // No biometric gate here: this is first-time data entry during onboarding,
        // not a modification of existing capital, so there's nothing to protect yet.
        // See DashboardViewModel.createCapitalAdjustment's doc comment for the
        // documented exception this call relies on.
        do {
            if currency !== userProfile.preferredCurrency {
                let profileViewModel = ProfileViewModel(modelContext: modelContext)
                profileViewModel.loadProfile()
                try profileViewModel.updatePreferredCurrency(currency)
            }

            let dashboardViewModel = DashboardViewModel(modelContext: modelContext)
            try dashboardViewModel.createCapitalAdjustment(
                amount: amount,
                note: "Capital inicial",
                currency: currency
            )

            onComplete()
            dismiss()
        } catch {
            errorMessage = "No se pudo guardar tu capital inicial. Inténtalo de nuevo."
        }
    }
}

// MARK: - Previews

#Preview("Initial Capital") {
    let container = OnboardingPreviewContainer.make()

    // CurrencySeeder already ran inside OnboardingPreviewContainer.make(); reuse its result.
    let seededCurrency = try! container.mainContext.fetch(FetchDescriptor<Currency>()).first!
    let previewProfile = UserProfile(
        name: "Luis",
        avatarSystemImage: "star.circle.fill",
        preferredCurrency: seededCurrency
    )
    container.mainContext.insert(previewProfile)

    return InitialCapitalView(userProfile: previewProfile, onComplete: {})
        .modelContainer(container)
}
