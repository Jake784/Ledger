//
//  LedgerApp.swift
//  Ledger
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

@main
struct LedgerApp: App {
    let modelContainer: ModelContainer = {
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
        return try! ModelContainer(for: schema)
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

/// Decides whether to show onboarding (`WelcomeView` → `InitialCapitalView`) or the
/// main `ContentView` shell, based on whether a `UserProfile` already exists.
///
/// Also seeds reference data (`Currency`, `Category`) once per launch — both
/// `WelcomeView.resolveDefaultCurrency()` and `DashboardView.displayCurrency` depend
/// on that data already existing, and nothing else in the app ran the seeders before.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var profileViewModel: ProfileViewModel?

    var body: some View {
        Group {
            if let profileViewModel {
                if profileViewModel.needsOnboarding {
                    WelcomeView {
                        profileViewModel.loadProfile()
                    }
                } else {
                    ContentView(onAccountDeleted: initializeProfile)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            guard profileViewModel == nil else { return }
            initializeProfile()
        }
    }

    /// Seeds reference data and (re)loads the profile — the app's first-launch
    /// initialization. Also called after `SettingsView`'s account deletion succeeds:
    /// `AccountSecurityViewModel.deleteAccountAndAllData()` wipes the `UserProfile` and
    /// every `Currency` row, but `SettingsView` holds its own `ProfileViewModel`
    /// instance, separate from this one — without re-running this, this view's
    /// `profileViewModel` would keep pointing at the deleted profile and `needsOnboarding`
    /// would never flip to `true`, so the app would neither quit nor return to
    /// onboarding, just sit on a broken `ContentView` with no currency (previously
    /// worked around by force-quitting the app, which this replaces).
    private func initializeProfile() {
        CurrencySeeder.seedIfNeeded(context: modelContext)
        CategorySeeder.seedIfNeeded(context: modelContext)

        let viewModel = ProfileViewModel(modelContext: modelContext)
        viewModel.loadProfile()
        profileViewModel = viewModel
    }
}
