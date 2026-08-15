//
//  AccountSecurityViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages account security operations, including account deletion.
///
/// **Security Design:**
/// All destructive operations require biometric authentication (Face ID, Touch ID, or device passcode)
/// via BiometricAuthService. Authentication is performed BEFORE any data modification occurs.
///
/// **Account Deletion - DESTRUCTIVE OPERATION:**
/// The `deleteAccountAndAllData()` method performs a complete data wipe:
/// - Deletes ALL transactions (income, expense, capital adjustments)
/// - Deletes ALL categories (custom categories only; predefined ones will be reseeded)
/// - Deletes ALL projections and their items
/// - Deletes ALL budgets and their category limits
/// - Deletes ALL goals and their linked savings funds
/// - Deletes ALL standalone savings funds
/// - Deletes the user profile
///
/// This is irreversible. The app returns to a first-launch state (onboarding required).
///
/// **Usage:**
/// ```swift
/// struct AccountSecurityView: View {
///     @State private var viewModel: AccountSecurityViewModel
///     @State private var showDeleteConfirmation = false
///
///     var body: some View {
///         Form {
///             Section("Danger Zone") {
///                 Button("Delete Account", role: .destructive) {
///                     showDeleteConfirmation = true
///                 }
///             }
///         }
///         .confirmationDialog("Delete Account?", isPresented: $showDeleteConfirmation) {
///             Button("Delete Everything", role: .destructive) {
///                 Task {
///                     do {
///                         try await viewModel.deleteAccountAndAllData()
///                         // Navigate to onboarding
///                     } catch {
///                         print("Error: \(error)")
///                     }
///                 }
///             }
///         } message: {
///             Text("This will permanently delete all your financial data. This action cannot be undone.")
///         }
///     }
/// }
/// ```
@Observable
final class AccountSecurityViewModel {
    
    // MARK: - Properties
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    /// Biometric authentication service.
    private let authService: BiometricAuthService
    
    // MARK: - Initialization
    
    /// Initializes the AccountSecurityViewModel.
    ///
    /// - Parameters:
    ///   - modelContext: The ModelContext to use for data operations.
    ///   - authService: Optional BiometricAuthService (defaults to new instance).
    init(modelContext: ModelContext, authService: BiometricAuthService = BiometricAuthService()) {
        self.modelContext = modelContext
        self.authService = authService
    }
    
    // MARK: - Account Deletion
    
    /// Deletes the user account and ALL associated data.
    ///
    /// **⚠️ EXTREMELY DESTRUCTIVE OPERATION:**
    /// This method:
    /// 1. Requires biometric authentication (Face ID/Touch ID/Passcode)
    /// 2. If authenticated, deletes EVERYTHING:
    ///    - All transactions
    ///    - All custom categories
    ///    - All projections and items
    ///    - All budgets and limits
    ///    - All goals and savings funds
    ///    - All savings movements
    ///    - User profile
    /// 3. Returns app to first-launch state (requires onboarding)
    ///
    /// **Authentication:**
    /// The method authenticates BEFORE deleting anything. If authentication fails
    /// or is cancelled, no data is modified and an error is thrown.
    ///
    /// **Error Handling:**
    /// - Throws `AccountSecurityError.authenticationFailed` if biometric auth is denied
    /// - Throws `AccountSecurityError.authenticationCancelled` if user cancels
    /// - Rethrows any deletion errors from SwiftData
    ///
    /// **Important:** The UI MUST confirm this action before calling this method.
    /// Show clear warnings about data loss.
    ///
    /// - Throws: Authentication or deletion errors.
    func deleteAccountAndAllData() async throws {
        // Step 1: Authenticate FIRST (before touching any data)
        do {
            let authenticated = try await authService.authenticate(
                reason: "Confirm to delete your account and all data"
            )
            
            guard authenticated else {
                throw AccountSecurityError.authenticationCancelled
            }
            
        } catch let error as BiometricAuthError {
            // Map BiometricAuthError to our custom error
            switch error {
            case .userCancelled:
                throw AccountSecurityError.authenticationCancelled
            default:
                throw AccountSecurityError.authenticationFailed(reason: error.localizedDescription)
            }
        } catch {
            throw AccountSecurityError.authenticationFailed(reason: error.localizedDescription)
        }
        
        // Step 2: User is authenticated - proceed with deletion
        do {
            // Delete all data in reverse dependency order to avoid foreign key issues
            
            // 1. Delete all savings movements
            let movementDescriptor = FetchDescriptor<SavingsMovement>()
            let movements = try modelContext.fetch(movementDescriptor)
            for movement in movements {
                modelContext.delete(movement)
            }
            
            // 2. Delete all goals (cascade deletes linked savings funds)
            let goalDescriptor = FetchDescriptor<Goal>()
            let goals = try modelContext.fetch(goalDescriptor)
            for goal in goals {
                modelContext.delete(goal)
            }
            
            // 3. Delete remaining standalone savings funds
            let fundDescriptor = FetchDescriptor<SavingsFund>()
            let funds = try modelContext.fetch(fundDescriptor)
            for fund in funds {
                modelContext.delete(fund)
            }
            
            // 4. Delete all budget category limits
            let limitDescriptor = FetchDescriptor<BudgetCategoryLimit>()
            let limits = try modelContext.fetch(limitDescriptor)
            for limit in limits {
                modelContext.delete(limit)
            }
            
            // 5. Delete all budgets
            let budgetDescriptor = FetchDescriptor<Budget>()
            let budgets = try modelContext.fetch(budgetDescriptor)
            for budget in budgets {
                modelContext.delete(budget)
            }
            
            // 6. Delete all projection items
            let itemDescriptor = FetchDescriptor<ProjectionItem>()
            let items = try modelContext.fetch(itemDescriptor)
            for item in items {
                modelContext.delete(item)
            }
            
            // 7. Delete all projections
            let projectionDescriptor = FetchDescriptor<Projection>()
            let projections = try modelContext.fetch(projectionDescriptor)
            for projection in projections {
                modelContext.delete(projection)
            }
            
            // 8. Delete all recurrence rules
            let ruleDescriptor = FetchDescriptor<RecurrenceRule>()
            let rules = try modelContext.fetch(ruleDescriptor)
            for rule in rules {
                modelContext.delete(rule)
            }
            
            // 9. Delete all transactions
            let transactionDescriptor = FetchDescriptor<Transaction>()
            let transactions = try modelContext.fetch(transactionDescriptor)
            for transaction in transactions {
                modelContext.delete(transaction)
            }
            
            // 10. Delete all custom categories (keep predefined ones for reseeding)
            let categoryDescriptor = FetchDescriptor<Category>(
                predicate: #Predicate { category in
                    category.isCustom == true
                }
            )
            let customCategories = try modelContext.fetch(categoryDescriptor)
            for category in customCategories {
                modelContext.delete(category)
            }
            
            // 11. Delete user profile
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)
            for profile in profiles {
                modelContext.delete(profile)
            }
            
            // 12. Delete all currencies (they'll be recreated during onboarding)
            let currencyDescriptor = FetchDescriptor<Currency>()
            let currencies = try modelContext.fetch(currencyDescriptor)
            for currency in currencies {
                modelContext.delete(currency)
            }
            
            // Save all deletions
            try modelContext.save()
            
            print("Account and all data successfully deleted")
            
        } catch {
            print("Failed to delete account data: \(error)")
            throw AccountSecurityError.deletionFailed(reason: error.localizedDescription)
        }
    }
    
    // MARK: - Utility
    
    /// Returns information about available biometric authentication.
    var biometricInfo: (available: Bool, type: String) {
        authService.biometricType()
    }
}

// MARK: - Errors

/// Errors that can occur during account security operations.
enum AccountSecurityError: LocalizedError {
    case authenticationFailed(reason: String)
    case authenticationCancelled
    case deletionFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .authenticationCancelled:
            return "Authentication was cancelled. Account deletion aborted."
        case .deletionFailed(let reason):
            return "Failed to delete account data: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "Make sure Face ID, Touch ID, or your device passcode is set up correctly."
        case .authenticationCancelled:
            return "To delete your account, you must complete the authentication step."
        case .deletionFailed:
            return "Try restarting the app and attempting the deletion again. If the problem persists, contact support."
        }
    }
}
