//
//  GoalViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages financial goals and their lifecycle.
///
/// **Goal ↔ SavingsFund Relationship (1-to-1):**
/// Every Goal automatically creates and owns a linked SavingsFund:
/// - Creating a Goal creates its SavingsFund (same name)
/// - Deleting a Goal cascade-deletes its SavingsFund and all movements
/// - Goal progress is derived from its fund's currentAmount
///
/// **Ownership Responsibilities:**
/// - **GoalViewModel (THIS)**: Creates/deletes goals and their linked funds
/// - **SavingsViewModel**: Manages deposits/withdrawals on the funds
///
/// This design ensures:
/// - Goals always have a place to accumulate savings
/// - Goal/fund pairs are created and deleted atomically
/// - Progress tracking is automatic via the fund's balance
///
/// **Important:** Deleting a goal is DESTRUCTIVE. It permanently removes:
/// - The goal itself
/// - Its linked savings fund
/// - All deposit/withdrawal history
/// - All accumulated savings
///
/// The UI should confirm this action with users before calling `deleteGoal()`.
///
/// **Usage:**
/// ```swift
/// struct GoalsView: View {
///     @State private var viewModel: GoalViewModel
///     @State private var savingsViewModel: SavingsViewModel
///
///     var body: some View {
///         List(viewModel.goals) { goal in
///             GoalRow(
///                 goal: goal,
///                 progress: viewModel.progress(for: goal),
///                 isOverdue: viewModel.isOverdue(goal),
///                 savingsViewModel: savingsViewModel
///             )
///         }
///     }
/// }
/// ```
@Observable
final class GoalViewModel {
    
    // MARK: - Properties
    
    /// All financial goals, sorted by target date ascending (soonest deadline first).
    private(set) var goals: [Goal] = []
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the GoalViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Loading
    
    /// Loads all goals from SwiftData.
    ///
    /// Goals are sorted by target date ascending, showing soonest deadlines first.
    /// Call this method when the view appears or after performing mutations.
    func loadGoals() {
        let fetchDescriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.targetDate, order: .forward)]
        )
        
        do {
            goals = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to load goals: \(error)")
            goals = []
        }
    }
    
    // MARK: - Create
    
    /// Creates a new financial goal with its linked savings fund.
    ///
    /// This method atomically creates both:
    /// 1. A Goal with the specified target amount and date
    /// 2. A SavingsFund with the same name (starts at 0 balance)
    ///
    /// The goal and fund are automatically linked via the 1-to-1 relationship.
    /// Users can then deposit into the fund (via SavingsViewModel) to track progress.
    ///
    /// - Parameters:
    ///   - name: The name for both the goal and its linked fund.
    ///   - targetAmount: The target savings amount to reach.
    ///   - targetDate: The deadline for achieving this goal.
    /// - Throws: An error if the save operation fails.
    func createGoal(
        name: String,
        targetAmount: Decimal,
        targetDate: Date
    ) throws {
        // Create the linked savings fund first
        let savingsFund = SavingsFund(
            name: name,
            movements: [],
            linkedGoal: nil // Will be set when goal is created
        )
        
        // Create the goal and link it to the fund
        let goal = Goal(
            name: name,
            targetAmount: targetAmount,
            targetDate: targetDate,
            linkedSavingsFund: savingsFund
        )
        
        // Set the inverse relationship
        savingsFund.linkedGoal = goal
        
        modelContext.insert(savingsFund)
        modelContext.insert(goal)
        
        do {
            try modelContext.save()
            loadGoals()
        } catch {
            print("Failed to save goal: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    /// Deletes a goal and its linked savings fund.
    ///
    /// **⚠️ DESTRUCTIVE OPERATION:**
    /// This permanently deletes:
    /// - The goal
    /// - The linked savings fund (cascade delete)
    /// - All deposit/withdrawal movements in the fund
    /// - All accumulated savings
    ///
    /// **Important:** The UI MUST confirm this action with the user before calling this method.
    /// Consider showing:
    /// - The current fund balance that will be lost
    /// - The number of movements that will be deleted
    /// - A clear warning that this action cannot be undone
    ///
    /// **Example Confirmation:**
    /// ```
    /// "Delete goal '\(goal.name)'?"
    /// "This will permanently delete \(fund.currentAmount) in savings and \(movements.count) transactions."
    /// "This action cannot be undone."
    /// ```
    ///
    /// - Parameter goal: The goal to delete.
    /// - Throws: An error if the save operation fails.
    func deleteGoal(_ goal: Goal) throws {
        // SwiftData will cascade-delete the linked fund and its movements
        // due to the .cascade delete rule on Goal.linkedSavingsFund
        modelContext.delete(goal)
        
        do {
            try modelContext.save()
            loadGoals()
        } catch {
            print("Failed to delete goal: \(error)")
            throw error
        }
    }
    
    // MARK: - Progress Tracking
    
    /// Calculates the progress toward a goal.
    ///
    /// Progress is based on the linked fund's current balance compared to the target amount.
    /// Percentage is capped at 100% even if savings exceed the target.
    ///
    /// - Parameter goal: The goal to calculate progress for.
    /// - Returns: A tuple containing the current amount saved and the percentage progress (0-100).
    func progress(for goal: Goal) -> (currentAmount: Decimal, percentage: Double) {
        guard let fund = goal.linkedSavingsFund else {
            return (0, 0.0)
        }
        
        let currentAmount = fund.currentAmount
        
        // Avoid division by zero
        guard goal.targetAmount > 0 else {
            return (currentAmount, 0.0)
        }
        
        // Calculate percentage
        let rawPercentage = (Double(truncating: currentAmount as NSDecimalNumber) /
                            Double(truncating: goal.targetAmount as NSDecimalNumber)) * 100.0
        
        // Cap at 100%
        let percentage = min(rawPercentage, 100.0)
        
        return (currentAmount, percentage)
    }
    
    /// Checks if a goal is overdue.
    ///
    /// A goal is considered overdue if:
    /// - Its target date is in the past
    /// - AND progress is less than 100%
    ///
    /// - Parameter goal: The goal to check.
    /// - Returns: `true` if the goal is overdue, `false` otherwise.
    func isOverdue(_ goal: Goal) -> Bool {
        let now = Date()
        
        // Check if target date has passed
        guard goal.targetDate < now else {
            return false
        }
        
        // Check if goal is incomplete
        let (_, percentage) = progress(for: goal)
        return percentage < 100.0
    }
    
    // MARK: - Utility
    
    /// Returns all completed goals (100% or more progress).
    var completedGoals: [Goal] {
        goals.filter { goal in
            let (_, percentage) = progress(for: goal)
            return percentage >= 100.0
        }
    }
    
    /// Returns all active goals (less than 100% progress, not overdue).
    var activeGoals: [Goal] {
        goals.filter { goal in
            let (_, percentage) = progress(for: goal)
            return percentage < 100.0 && !isOverdue(goal)
        }
    }
    
    /// Returns all overdue goals (deadline passed, less than 100% progress).
    var overdueGoals: [Goal] {
        goals.filter { isOverdue($0) }
    }
    
    /// Returns the total amount needed to complete all active goals.
    var totalRemainingAmount: Decimal {
        activeGoals.reduce(Decimal(0)) { total, goal in
            let (currentAmount, _) = progress(for: goal)
            let remaining = goal.targetAmount - currentAmount
            return total + max(remaining, 0)
        }
    }
    
    /// Returns the number of days until a goal's deadline.
    ///
    /// - Parameter goal: The goal to check.
    /// - Returns: Number of days (positive for future, negative for past).
    func daysUntilDeadline(for goal: Goal) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: goal.targetDate)
        return components.day ?? 0
    }
    
    /// Returns whether a goal is approaching its deadline (within specified days).
    ///
    /// - Parameters:
    ///   - goal: The goal to check.
    ///   - days: Number of days to consider "approaching" (default 30).
    /// - Returns: `true` if the deadline is within the specified number of days.
    func isApproachingDeadline(_ goal: Goal, within days: Int = 30) -> Bool {
        let daysRemaining = daysUntilDeadline(for: goal)
        return daysRemaining > 0 && daysRemaining <= days
    }
}
