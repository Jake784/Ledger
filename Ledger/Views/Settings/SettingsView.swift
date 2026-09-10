//
//  SettingsView.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI
import SwiftData

/// FinVault's Configuración (Settings) module — profile editing, preferred currency,
/// notification authorization status, and the biometric-gated account deletion flow.
///
/// **Biometric gate placement — checked, not assumed:** `WelcomeView`/`InitialCapitalView`
/// (onboarding) never call `BiometricAuthService`; `InitialCapitalView`'s own comment
/// documents that as a deliberate exception, since there's nothing to protect yet on
/// first-time data entry. `CapitalHeaderCard`'s capital-adjustment sheet is the one place
/// outside onboarding that already gates behind it. This view is the second: account
/// deletion goes through `AccountSecurityViewModel.deleteAccountAndAllData()`, which
/// performs Face ID/Touch ID/passcode authentication itself, BEFORE deleting anything —
/// this view never touches `BiometricAuthService` directly, and never shows any
/// biometric prompt anywhere except behind the "Eliminar Cuenta" confirmation below.
///
/// Mirrors `DashboardView`/`IncomeView`/`ExpensesView`'s architecture: the view never
/// touches `ModelContext` directly, only through `ProfileViewModel`/`AccountSecurityViewModel`.
///
/// **Checked and deliberately NOT wired here:** `ExportService`'s own doc comment scopes
/// its use cases to Historial/Proyecciones/Presupuestos, not Configuración, and those are
/// already-built modules out of scope this turn — so no export UI lives here.
/// `NotificationService` has no persisted user preference to bind a toggle to (no such
/// field exists on `UserProfile`); this view only surfaces its real, already-exposed
/// `isAuthorized()`/`requestAuthorization()` — it doesn't invent a fake persisted setting.
///
/// **Where Used:**
/// - `ContentView`'s detail switch, for `SidebarModule.configuracion`.
struct SettingsView: View {
    @State private var profileViewModel: ProfileViewModel
    @State private var securityViewModel: AccountSecurityViewModel
    private let notificationService = NotificationService()

    /// Called after account deletion succeeds, so `RootView` (in `LedgerApp.swift`) can
    /// reseed reference data and reload its own profile state, returning to onboarding
    /// instead of the app quitting. Defaults to a no-op for previews.
    var onAccountDeleted: () -> Void = {}

    @Query(sort: \Currency.code) private var currencies: [Currency]

    @State private var name: String = ""
    @State private var selectedAvatar: String = SettingsView.avatarOptions[0]
    @State private var isSavingProfile = false
    @State private var profileErrorMessage: String?

    @State private var isNotificationAuthorized = false
    @State private var isRequestingNotifications = false

    @State private var isPresentingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deletionErrorMessage: String?

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

    init(modelContext: ModelContext, onAccountDeleted: @escaping () -> Void = {}) {
        _profileViewModel = State(initialValue: ProfileViewModel(modelContext: modelContext))
        _securityViewModel = State(initialValue: AccountSecurityViewModel(modelContext: modelContext))
        self.onAccountDeleted = onAccountDeleted
    }

    var body: some View {
        ScrollView {
            if let profile = profileViewModel.userProfile {
                VStack(alignment: .leading, spacing: 24) {
                    profileSection(profile)
                    currencySection
                    notificationsSection
                    dangerZoneSection
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .navigationTitle("Configuración")
        .onAppear {
            profileViewModel.loadProfile()
            if let profile = profileViewModel.userProfile {
                name = profile.name
                selectedAvatar = profile.avatarSystemImage
            }
            Task {
                isNotificationAuthorized = await notificationService.isAuthorized()
            }
        }
        .alert(
            "¿Eliminar tu cuenta?",
            isPresented: $isPresentingDeleteConfirmation
        ) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar Todo", role: .destructive) {
                performDeletion()
            }
        } message: {
            Text("Esto eliminará permanentemente todas tus transacciones, categorías personalizadas, presupuestos, metas, ahorros y proyecciones. Se te pedirá autenticación biométrica para confirmar. Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Profile Section

    private func profileSection(_ profile: UserProfile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Perfil", systemImage: "person.crop.circle")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Tu nombre", text: $name)
                        .textFieldStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Avatar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 8), spacing: 12) {
                        ForEach(Self.avatarOptions, id: \.self) { symbol in
                            avatarButton(symbol)
                        }
                    }
                }

                Text("Miembro desde \(Self.dateFormatter.string(from: profile.createdAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let profileErrorMessage {
                    Text(profileErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    handleSaveProfile()
                } label: {
                    if isSavingProfile {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Guardar Cambios")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220)
                .disabled(isSavingProfile || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasProfileChanges(profile))
            }
        }
    }

    private func avatarButton(_ symbol: String) -> some View {
        let isSelected = symbol == selectedAvatar
        return Button {
            selectedAvatar = symbol
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.accentColor, lineWidth: isSelected ? 0 : 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func hasProfileChanges(_ profile: UserProfile) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines) != profile.name || selectedAvatar != profile.avatarSystemImage
    }

    private func handleSaveProfile() {
        isSavingProfile = true
        profileErrorMessage = nil

        do {
            try profileViewModel.updateProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarSystemImage: selectedAvatar
            )
            isSavingProfile = false
        } catch {
            isSavingProfile = false
            profileErrorMessage = "No se pudieron guardar los cambios. Inténtalo de nuevo."
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    // MARK: - Currency Section

    private var currencySection: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("Moneda Preferida", systemImage: "banknote")
                    .font(.headline)

                Picker(
                    "Moneda",
                    selection: Binding(
                        get: { profileViewModel.userProfile?.preferredCurrency },
                        set: { newValue in
                            if let newValue {
                                try? profileViewModel.updatePreferredCurrency(newValue)
                            }
                        }
                    )
                ) {
                    ForEach(currencies) { currency in
                        Text("\(currency.code) (\(currency.symbol))").tag(Optional(currency))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Notificaciones", systemImage: "bell")
                    .font(.headline)

                HStack(spacing: 8) {
                    Image(systemName: isNotificationAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(isNotificationAuthorized ? .green : .secondary)

                    Text(isNotificationAuthorized ? "Autorizadas" : "No autorizadas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !isNotificationAuthorized {
                        Button {
                            requestNotificationAuthorization()
                        } label: {
                            if isRequestingNotifications {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Activar")
                            }
                        }
                        .buttonStyle(CompactButtonStyle())
                        .disabled(isRequestingNotifications)
                    }
                }

                Text("Usadas para recordatorios de transacciones pendientes y fechas límite de metas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestNotificationAuthorization() {
        isRequestingNotifications = true
        Task {
            let granted = (try? await notificationService.requestAuthorization()) ?? false
            isNotificationAuthorized = granted
            isRequestingNotifications = false
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        Card(tint: .red) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Zona de Peligro", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                let biometricInfo = securityViewModel.biometricInfo
                Text(
                    biometricInfo.available
                        ? "Eliminar tu cuenta requiere confirmación con \(biometricInfo.type)."
                        : "Eliminar tu cuenta requiere confirmación con tu contraseña del sistema."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let deletionErrorMessage {
                    Text(deletionErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    isPresentingDeleteConfirmation = true
                } label: {
                    if isDeletingAccount {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Eliminar Cuenta y Todos los Datos")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(DestructiveButtonStyle())
                .disabled(isDeletingAccount)
            }
        }
    }

    private func performDeletion() {
        isDeletingAccount = true
        deletionErrorMessage = nil

        Task {
            do {
                try await securityViewModel.deleteAccountAndAllData()
                isDeletingAccount = false
                // Deletion wiped the profile (and every Currency row) — hand off to
                // RootView to reseed and reload, falling back into onboarding. This
                // view is about to be torn down as ContentView is swapped for
                // WelcomeView, so there's nothing further to show here.
                onAccountDeleted()
            } catch let error as AccountSecurityError {
                isDeletingAccount = false
                switch error {
                case .authenticationCancelled:
                    deletionErrorMessage = "Autenticación cancelada. No se eliminó ningún dato."
                case .authenticationFailed:
                    deletionErrorMessage = "No se pudo verificar tu identidad. Inténtalo de nuevo."
                case .deletionFailed:
                    deletionErrorMessage = "No se pudo eliminar la cuenta. Inténtalo de nuevo."
                }
            } catch {
                isDeletingAccount = false
                deletionErrorMessage = "Ocurrió un error inesperado."
            }
        }
    }
}

// MARK: - Previews

#Preview("Settings") {
    let container = SettingsPreviewContainer.make()

    return NavigationStack {
        SettingsView(modelContext: container.mainContext)
    }
    .modelContainer(container)
    .frame(width: 900, height: 900)
}

/// Self-contained in-memory `ModelContainer` factory for previewing `SettingsView`.
private enum SettingsPreviewContainer {
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
        let context = container.mainContext

        CurrencySeeder.seedIfNeeded(context: context)

        let currency = try! context.fetch(FetchDescriptor<Currency>()).first!
        let profile = UserProfile(
            name: "Luis",
            avatarSystemImage: "star.circle.fill",
            preferredCurrency: currency,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        )
        context.insert(profile)

        try? context.save()
        return container
    }
}
