//
//  SavingsViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages savings fund operations and movement history.
///
/// **Goal ↔ SavingsFund Relationship:**
/// Goals and SavingsFunds have a 1-to-1 relationship:
/// - A Goal automatically creates its linked SavingsFund (managed by GoalViewModel)
/// - A SavingsFund can exist standalone (not linked to any goal)
/// - Deposits/withdrawals happen on SavingsFunds (managed by THIS ViewModel)
/// - Goal progress is derived from its linked fund's currentAmount
///
/// **Ownership Responsibilities:**
/// - **GoalViewModel**: Creates/deletes goals and their linked funds
/// - **SavingsViewModel**: Manages deposits/withdrawals on ANY fund (standalone or goal-linked)
///
/// This separation allows users to:
/// - Save money toward specific goals
/// - Maintain general savings funds (e.g., "Emergency Fund", "Vacation")
/// - Track all savings in one unified view
///
/// **Usage:**
/// ```swift
/// struct SavingsView: View {
///     @State private var viewModel: SavingsViewModel
///
///     init(modelContext: ModelContext) {
///         _viewModel = State(initialValue: SavingsViewModel(modelContext: modelContext))
///     }
///
///     var body: some View {
///         List(viewModel.savingsFunds) { fund in
///             SavingsFundRow(fund: fund, viewModel: viewModel)
///         }
///     }
/// }
/// ```
@Observable
final class SavingsViewModel {
    
    // MARK: - Properties
    
    /// All savings funds (standalone and goal-linked), sorted alphabetically by name.
    private(set) var savingsFunds: [SavingsFund] = []
    
    /// Total balance across all savings funds.
    private(set) var totalSavings: Decimal = 0
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the SavingsViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Loading
    
    /// Loads all savings funds from SwiftData and recalculates total savings.
    ///
    /// Call this method when the view appears or after performing mutations.
    func loadSavingsFunds() {
        let fetchDescriptor = FetchDescriptor<SavingsFund>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        
        do {
            savingsFunds = try modelContext.fetch(fetchDescriptor)
            
            // Calculate total savings
            totalSavings = savingsFunds.reduce(Decimal(0)) { total, fund in
                total + fund.currentAmount
            }
            
        } catch {
            print("Failed to load savings funds: \(error)")
            savingsFunds = []
            totalSavings = 0
        }
    }
    
    // MARK: - Create
    
    /// Creates a standalone savings fund not linked to any goal.
    ///
    /// Use this for general savings that aren't tied to a specific financial goal
    /// (e.g., "Emergency Fund", "Vacation Savings", "Caja Chica").
    ///
    /// **Note:** To create a fund linked to a goal, use `GoalViewModel.createGoal()` instead,
    /// which automatically creates both the goal and its linked fund.
    ///
    /// - Parameter name: The name for this savings fund.
    /// - Throws: An error if the save operation fails.
    func createStandaloneFund(name: String) throws {
        let newFund = SavingsFund(
            name: name,
            movements: [],
            linkedGoal: nil
        )
        
        modelContext.insert(newFund)
        
        do {
            try modelContext.save()
            loadSavingsFunds()
        } catch {
            print("Failed to save standalone fund: \(error)")
            throw error
        }
    }
    
    // MARK: - Movements
    
    /// Deposits money into a savings fund.
    ///
    /// Works for both standalone funds and goal-linked funds.
    ///
    /// - Parameters:
    ///   - fund: The savings fund to deposit into.
    ///   - amount: The amount to deposit (must be positive).
    ///   - note: Optional note describing the deposit.
    /// - Throws: An error if the save operation fails.
    func deposit(to fund: SavingsFund, amount: Decimal, note: String?) throws {
        let movement = SavingsMovement(
            type: .deposit,
            amount: amount,
            date: Date(),
            note: note
        )
        
        fund.movements.append(movement)
        modelContext.insert(movement)
        
        do {
            try modelContext.save()
            loadSavingsFunds()
        } catch {
            print("Failed to save deposit: \(error)")
            throw error
        }
    }
    
    /// Withdraws money from a savings fund.
    ///
    /// Validates that the fund has sufficient balance before allowing the withdrawal.
    ///
    /// - Parameters:
    ///   - fund: The savings fund to withdraw from.
    ///   - amount: The amount to withdraw (must not exceed current balance).
    ///   - note: Optional note describing the withdrawal.
    /// - Throws: `SavingsViewModelError.insufficientFunds` if the withdrawal amount
    ///           exceeds the fund's current balance, or a save error if persistence fails.
    func withdraw(from fund: SavingsFund, amount: Decimal, note: String?) throws {
        // Validate sufficient funds
        guard amount <= fund.currentAmount else {
            throw SavingsViewModelError.insufficientFunds(
                available: fund.currentAmount,
                requested: amount
            )
        }
        
        let movement = SavingsMovement(
            type: .withdrawal,
            amount: amount,
            date: Date(),
            note: note
        )
        
        fund.movements.append(movement)
        modelContext.insert(movement)
        
        do {
            try modelContext.save()
            loadSavingsFunds()
        } catch {
            print("Failed to save withdrawal: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    /// Deletes a standalone savings fund.
    ///
    /// **Important:** Only standalone funds (not linked to a goal) can be deleted here.
    /// To delete a goal-linked fund, you must delete the goal via `GoalViewModel.deleteGoal()`,
    /// which will cascade-delete the linked fund and all its movements.
    ///
    /// This restriction ensures goal-fund pairs are deleted atomically, preventing orphaned data.
    ///
    /// - Parameter fund: The savings fund to delete.
    /// - Throws: `SavingsViewModelError.cannotDeleteLinkedFund` if the fund is linked to a goal,
    ///           or a save error if persistence fails.
    func deleteFund(_ fund: SavingsFund) throws {
        // Only allow deletion of standalone funds
        guard fund.linkedGoal == nil else {
            throw SavingsViewModelError.cannotDeleteLinkedFund
        }
        
        modelContext.delete(fund)
        
        do {
            try modelContext.save()
            loadSavingsFunds()
        } catch {
            print("Failed to delete fund: \(error)")
            throw error
        }
    }
    
    // MARK: - Utility
    
    /// Returns the movement history for a specific fund, sorted by date descending.
    ///
    /// - Parameter fund: The savings fund to get movements for.
    /// - Returns: Array of movements sorted by most recent first.
    func movementHistory(for fund: SavingsFund) -> [SavingsMovement] {
        fund.movements.sorted { $0.date > $1.date }
    }
    
    /// Returns all standalone funds (not linked to goals).
    var standaloneFunds: [SavingsFund] {
        savingsFunds.filter { $0.linkedGoal == nil }
    }
    
    /// Returns all goal-linked funds.
    var goalLinkedFunds: [SavingsFund] {
        savingsFunds.filter { $0.linkedGoal != nil }
    }
    
    /// Returns whether a fund is linked to a goal.
    ///
    /// - Parameter fund: The fund to check.
    /// - Returns: `true` if linked to a goal, `false` if standalone.
    func isLinkedToGoal(_ fund: SavingsFund) -> Bool {
        fund.linkedGoal != nil
    }
}

// MARK: - Errors

/// Errors that can occur during savings operations.
enum SavingsViewModelError: LocalizedError {
    case insufficientFunds(available: Decimal, requested: Decimal)
    case cannotDeleteLinkedFund
    
    var errorDescription: String? {
        switch self {
        case .insufficientFunds(let available, let requested):
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            
            let availableStr = formatter.string(from: available as NSDecimalNumber) ?? "\(available)"
            let requestedStr = formatter.string(from: requested as NSDecimalNumber) ?? "\(requested)"
            
            return "Insufficient funds. Available: \(availableStr), Requested: \(requestedStr)"
            
        case .cannotDeleteLinkedFund:
            return "Cannot delete a fund linked to a goal. Delete the goal instead to remove both the goal and its fund."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientFunds:
            return "Reduce the withdrawal amount or deposit more funds first."
        case .cannotDeleteLinkedFund:
            return "Use the Goals view to delete the associated goal, which will also remove this fund."
        }
    }
}
