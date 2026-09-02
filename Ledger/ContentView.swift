//
//  ContentView.swift
//  Ledger
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's root view — hosts the primary `NavigationSplitView`, pairing
/// `NavigationSidebar` with each module's detail view based on the current
/// `SidebarModule` selection.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: SidebarModule? = .panel

    /// Called after `SettingsView`'s account deletion succeeds, so the app's root
    /// (`RootView` in `LedgerApp.swift`) can reseed reference data and reload its own
    /// profile state, falling back into onboarding instead of quitting.
    var onAccountDeleted: () -> Void = {}

    var body: some View {
        NavigationSplitView {
            NavigationSidebar(selection: $selection)
        } detail: {
            if let selection {
                switch selection {
                case .panel:
                    DashboardView(modelContext: modelContext)
                case .ingresos:
                    IncomeView(modelContext: modelContext)
                case .gastos:
                    ExpensesView(modelContext: modelContext)
                case .categorias:
                    CategoriesView(modelContext: modelContext)
                case .historial:
                    HistoryView(modelContext: modelContext)
                case .presupuestos:
                    BudgetView(modelContext: modelContext)
                case .metas:
                    GoalsView(modelContext: modelContext)
                case .ahorro:
                    SavingsView(modelContext: modelContext)
                case .proyecciones:
                    ProjectionsView(modelContext: modelContext)
                case .configuracion:
                    SettingsView(modelContext: modelContext, onAccountDeleted: onAccountDeleted)
                }
            } else {
                Text("Selecciona un módulo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    ContentView()
        .modelContainer(ContentViewPreviewContainer.make())
}

/// Self-contained in-memory `ModelContainer` factory for previewing `ContentView`.
private enum ContentViewPreviewContainer {
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

        CurrencySeeder.seedIfNeeded(context: container.mainContext)
        CategorySeeder.seedIfNeeded(context: container.mainContext)

        return container
    }
}
