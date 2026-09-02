//
//  WelcomeView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// The very first screen a new user sees.
///
/// Introduces FinVault, collects the user's name and avatar choice, then creates
/// the initial `UserProfile` via `ProfileViewModel.createInitialProfile()` before
/// presenting `InitialCapitalView` as a sheet to complete onboarding.
///
/// **Where Used:**
/// - App entry point, shown when `ProfileViewModel.needsOnboarding` is `true`
///   (see the proposed root integration snippet at the bottom of this file).
struct WelcomeView: View {
    /// Called once the entire onboarding flow (profile + initial capital) is complete.
    let onOnboardingComplete: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var selectedAvatar: String = WelcomeView.avatarOptions[0]
    @State private var createdProfile: UserProfile?
    @State private var errorMessage: String?

    /// A small curated set of SF Symbols offered as avatar choices.
    private static let avatarOptions = [
        "person.circle.fill",
        "star.circle.fill",
        "leaf.circle.fill",
        "moon.stars.circle.fill",
        "flame.circle.fill",
        "bolt.circle.fill",
        "heart.circle.fill",
        "pawprint.circle.fill"
    ]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                hero

                Card {
                    VStack(alignment: .leading, spacing: 20) {
                        nameField
                        avatarGrid
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Comenzar") {
                    handleGetStarted()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmedName.isEmpty)
                .frame(maxWidth: 260)
            }
            .padding(40)
            .frame(maxWidth: 480)
        }
        .frame(minWidth: 520, minHeight: 640)
        .sheet(item: $createdProfile) { profile in
            InitialCapitalView(userProfile: profile, onComplete: onOnboardingComplete)
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Bienvenido a Ledger")
                .font(.largeTitle.weight(.bold))

            Text("Tu espacio personal para organizar ingresos, gastos y metas con claridad.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("¿Cómo te llamas?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Tu nombre", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var avatarGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elige un avatar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Self.avatarOptions, id: \.self) { symbol in
                    avatarButton(symbol)
                }
            }
        }
    }

    private func avatarButton(_ symbol: String) -> some View {
        let isSelected = symbol == selectedAvatar
        return Button {
            selectedAvatar = symbol
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(width: 48, height: 48)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.accentColor, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleGetStarted() {
        errorMessage = nil

        do {
            let currency = try resolveDefaultCurrency()
            let profileViewModel = ProfileViewModel(modelContext: modelContext)
            try profileViewModel.createInitialProfile(
                name: trimmedName,
                avatarSystemImage: selectedAvatar,
                preferredCurrency: currency
            )
            createdProfile = profileViewModel.userProfile
        } catch {
            errorMessage = "No se pudo crear tu perfil. Inténtalo de nuevo."
        }
    }

    /// Resolves the app's default currency, seeded by `CurrencySeeder` at app launch.
    private func resolveDefaultCurrency() throws -> Currency {
        let descriptor = FetchDescriptor<Currency>(
            predicate: #Predicate<Currency> { $0.isDefault == true }
        )
        guard let currency = try modelContext.fetch(descriptor).first else {
            throw OnboardingError.missingDefaultCurrency
        }
        return currency
    }
}

/// Errors surfaced by the onboarding flow.
enum OnboardingError: LocalizedError {
    case missingDefaultCurrency

    var errorDescription: String? {
        switch self {
        case .missingDefaultCurrency:
            return "No default currency was found. CurrencySeeder should have run at app launch."
        }
    }
}

// MARK: - Previews

#Preview("Welcome") {
    WelcomeView(onOnboardingComplete: {})
        .modelContainer(OnboardingPreviewContainer.make())
}

/// Shared in-memory `ModelContainer` factory for onboarding previews.
enum OnboardingPreviewContainer {
    static func make() -> ModelContainer {
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

        // Mirror the real app's launch sequence so previews behave the same way
        // (see LedgerApp.swift, which runs both seeders at startup).
        CurrencySeeder.seedIfNeeded(context: container.mainContext)

        return container
    }
}

// This view does not check for an existing profile itself — that decision belongs to
// the app's entry point. See `RootView` in LedgerApp.swift, which shows this view only
// when `ProfileViewModel.needsOnboarding` is true.
