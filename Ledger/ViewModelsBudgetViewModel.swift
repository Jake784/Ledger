//
//  BudgetViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages monthly budgets and tracks spending against category limits.
///
/// **Budget vs. Projection - Key Distinction:**
///
/// **Budgets (THIS ViewModel):**
/// - Track REAL spending against planned limits
/// - Use actual Transaction data (type == .expense, non-pending)
/// - Show what you've ACTUALLY spent vs. what you budgeted
/// - Month-by-month spending control tool
///
/// **Projections (ProjectionViewModel):**
/// - Use SIMULATED/ESTIMATED data for planning
/// - Create "what-if" scenarios for future years
/// - Don't track real transactions, just planned amounts
/// - Annual financial forecasting tool
///
/// Both modules help with planning, but Budgets are retrospective (comparing reality to plan)
/// while Projections are prospective (modeling future scenarios).
///
/// **Budget Workflow:**
/// 1. Create a monthly budget with category limits
/// 2. As expenses occur, they automatically count toward those limits
/// 3. View progress: spent vs. limit for each category
/// 4. Copy to next month for recurring budgets
///
/// **Usage:**
/// ```swift
/// struct BudgetView: View {
///     @State private var viewModel: BudgetViewModel
///
///     var body: some View {
///         VStack {
///             if let budget = viewModel.currentBudget {
///                 ForEach(viewModel.categoryProgress, id: \.limit.id) { progress in
///                     CategoryProgressRow(progress: progress)
///                 }
///             } else {
///                 Text("No hay presupuesto para este mes")
///             }
///         }
///         .onAppear {
///             let calendar = Calendar.current
///             let now = Date()
///             viewModel.loadBudget(
///                 month: calendar.component(.month, from: now),
///                 year: calendar.component(.year, from: now)
///             )
///         }
///     }
/// }
/// ```
@Observable
final class BudgetViewModel {
    
    // MARK: - Properties
    
    /// The budget for the currently loaded month/year, if one exists.
    private(set) var currentBudget: Budget?
    
    /// Progress for each category limit in the current budget.
    /// Includes actual spending, remaining budget, and percentage used.
    private(set) var categoryProgress: [(limit: BudgetCategoryLimit, spent: Decimal, remaining: Decimal, percentageUsed: Double)] = []
    
    /// Total budgeted amount across all category limits.
    private(set) var totalBudget: Decimal = 0
    
    /// Total actually spent across all categories in the current month.
    private(set) var totalSpent: Decimal = 0
    
    /// The month currently loaded (1-12).
    private(set) var currentMonth: Int = 0
    
    /// The year currently loaded.
    private(set) var currentYear: Int = 0
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the BudgetViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Loading
    
    /// Loads the budget for a specific month and year, and calculates spending progress.
    ///
    /// If no budget exists for the specified month/year, sets `currentBudget` to `nil`.
    /// Otherwise, calculates real spending for each category limit by querying transactions.
    ///
    /// - Parameters:
    ///   - month: The month to load (1-12).
    ///   - year: The year to load.
    func loadBudget(month: Int, year: Int) {
        currentMonth = month
        currentYear = year
        
        // Fetch budget for this month/year
        let fetchDescriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { budget in
                budget.month == month && budget.year == year
            }
        )
        
        do {
            let budgets = try modelContext.fetch(fetchDescriptor)
            currentBudget = budgets.first
            
            if let budget = currentBudget {
                calculateCategoryProgress(for: budget)
            } else {
                // No budget exists for this month
                categoryProgress = []
                totalBudget = 0
                totalSpent = 0
            }
            
        } catch {
            print("Failed to load budget: \(error)")
            currentBudget = nil
            categoryProgress = []
            totalBudget = 0
            totalSpent = 0
        }
    }
    
    /// Calculates spending progress for each category in the budget.
    private func calculateCategoryProgress(for budget: Budget) {
        var progress: [(limit: BudgetCategoryLimit, spent: Decimal, remaining: Decimal, percentageUsed: Double)] = []
        var totalBudgetAmount: Decimal = 0
        var totalSpentAmount: Decimal = 0
        
        for limit in budget.categoryLimits {
            guard let category = limit.category else { continue }
            
            // Calculate actual spending in this category for this month/year
            let spent = calculateSpending(for: category, month: currentMonth, year: currentYear)
            
            // Calculate remaining and percentage
            let remaining = limit.limitAmount - spent
            let percentageUsed = limit.limitAmount > 0
                ? (Double(truncating: spent as NSDecimalNumber) /
                   Double(truncating: limit.limitAmount as NSDecimalNumber)) * 100.0
                : 0.0
            
            progress.append((
                limit: limit,
                spent: spent,
                remaining: remaining,
                percentageUsed: percentageUsed
            ))
            
            totalBudgetAmount += limit.limitAmount
            totalSpentAmount += spent
        }
        
        // Sort by percentage used descending (most overspent/used first)
        categoryProgress = progress.sorted { $0.percentageUsed > $1.percentageUsed }
        totalBudget = totalBudgetAmount
        totalSpent = totalSpentAmount
    }
    
    /// Calculates actual spending in a category for a specific month/year.
    private func calculateSpending(for category: Category, month: Int, year: Int) -> Decimal {
        // Fetch all expense transactions in this category for this month/year
        let expenseRawValue = TransactionType.expense.rawValue
        let categoryID = category.id
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.type.rawValue == expenseRawValue &&
                transaction.isPending == false &&
                transaction.category?.id == categoryID
            }
        )
        
        do {
            let transactions = try modelContext.fetch(fetchDescriptor)
            let calendar = Calendar.current
            
            // Filter to current month/year and sum amounts
            let total = transactions
                .filter { transaction in
                    let components = calendar.dateComponents([.month, .year], from: transaction.date)
                    return components.month == month && components.year == year
                }
                .reduce(Decimal(0)) { $0 + $1.amount }
            
            return total
            
        } catch {
            print("Failed to calculate spending for category \(category.name): \(error)")
            return 0
        }
    }
    
    // MARK: - Create
    
    /// Creates a new budget for a specific month and year.
    ///
    /// - Parameters:
    ///   - month: The month for this budget (1-12).
    ///   - year: The year for this budget.
    ///   - categoryLimits: Array of category-limit pairs to include in the budget.
    /// - Throws: `BudgetViewModelError.budgetAlreadyExists` if a budget already exists for this month/year,
    ///           or a save error if persistence fails.
    func createBudget(
        month: Int,
        year: Int,
        categoryLimits: [(category: Category, limitAmount: Decimal)]
    ) throws {
        // Check if budget already exists
        let fetchDescriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { budget in
                budget.month == month && budget.year == year
            }
        )
        
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            
            if !existing.isEmpty {
                throw BudgetViewModelError.budgetAlreadyExists(month: month, year: year)
            }
            
            // Create category limit objects
            var limits: [BudgetCategoryLimit] = []
            
            for (category, amount) in categoryLimits {
                let limit = BudgetCategoryLimit(
                    category: category,
                    limitAmount: amount
                )
                limits.append(limit)
                modelContext.insert(limit)
            }
            
            // Create the budget
            let budget = Budget(
                month: month,
                year: year,
                categoryLimits: limits
            )
            
            modelContext.insert(budget)
            
            try modelContext.save()
            
            // Reload to show the new budget
            loadBudget(month: month, year: year)
            
        } catch let error as BudgetViewModelError {
            throw error
        } catch {
            print("Failed to create budget: \(error)")
            throw error
        }
    }
    
    // MARK: - Update
    
    /// Updates the limit amount for a category in the current budget.
    ///
    /// - Parameters:
    ///   - limit: The category limit to update.
    ///   - newAmount: The new limit amount.
    /// - Throws: An error if the save operation fails.
    func updateCategoryLimit(_ limit: BudgetCategoryLimit, newAmount: Decimal) throws {
        limit.limitAmount = newAmount
        
        do {
            try modelContext.save()
            // Recalculate with new limit
            if let budget = currentBudget {
                calculateCategoryProgress(for: budget)
            }
        } catch {
            print("Failed to update category limit: \(error)")
            throw error
        }
    }
    
    /// Adds a new category limit to the current budget.
    ///
    /// - Parameters:
    ///   - category: The category to add a limit for.
    ///   - limitAmount: The limit amount for this category.
    /// - Throws: `BudgetViewModelError.noBudgetLoaded` if no budget is currently loaded,
    ///           `BudgetViewModelError.categoryAlreadyBudgeted` if the category already has a limit,
    ///           or a save error if persistence fails.
    func addCategoryToBudget(_ category: Category, limitAmount: Decimal) throws {
        guard let budget = currentBudget else {
            throw BudgetViewModelError.noBudgetLoaded
        }
        
        // Check if category already has a limit
        let alreadyExists = budget.categoryLimits.contains { limit in
            limit.category?.id == category.id
        }
        
        if alreadyExists {
            throw BudgetViewModelError.categoryAlreadyBudgeted(categoryName: category.name)
        }
        
        let newLimit = BudgetCategoryLimit(
            category: category,
            limitAmount: limitAmount
        )
        
        budget.categoryLimits.append(newLimit)
        modelContext.insert(newLimit)
        
        do {
            try modelContext.save()
            // Recalculate with new category
            calculateCategoryProgress(for: budget)
        } catch {
            print("Failed to add category to budget: \(error)")
            throw error
        }
    }
    
    /// Removes a category limit from the current budget.
    ///
    /// - Parameter limit: The category limit to remove.
    /// - Throws: `BudgetViewModelError.noBudgetLoaded` if no budget is currently loaded,
    ///           or a save error if persistence fails.
    func removeCategoryFromBudget(_ limit: BudgetCategoryLimit) throws {
        guard let budget = currentBudget else {
            throw BudgetViewModelError.noBudgetLoaded
        }
        
        budget.categoryLimits.removeAll { $0.id == limit.id }
        modelContext.delete(limit)
        
        do {
            try modelContext.save()
            // Recalculate without this category
            calculateCategoryProgress(for: budget)
        } catch {
            print("Failed to remove category from budget: \(error)")
            throw error
        }
    }
    
    // MARK: - Copy to Next Month
    
    /// Copies the current budget to the next month with the same category limits.
    ///
    /// This is a convenience method for recurring monthly budgets. It creates a new budget
    /// for the following month/year with identical categories and limit amounts.
    ///
    /// - Throws: `BudgetViewModelError.noBudgetLoaded` if no budget is currently loaded,
    ///           `BudgetViewModelError.budgetAlreadyExists` if the next month already has a budget,
    ///           or a save error if persistence fails.
    func copyBudgetToNextMonth() throws {
        guard let currentBudget = currentBudget else {
            throw BudgetViewModelError.noBudgetLoaded
        }
        
        // Calculate next month/year
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = currentMonth
        components.year = currentYear
        components.day = 1
        
        guard let currentDate = calendar.date(from: components),
              let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: currentDate) else {
            throw BudgetViewModelError.noBudgetLoaded
        }
        
        let nextMonth = calendar.component(.month, from: nextMonthDate)
        let nextYear = calendar.component(.year, from: nextMonthDate)
        
        // Check if next month's budget already exists
        let fetchDescriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { budget in
                budget.month == nextMonth && budget.year == nextYear
            }
        )
        
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            
            if !existing.isEmpty {
                throw BudgetViewModelError.budgetAlreadyExists(month: nextMonth, year: nextYear)
            }
            
            // Copy category limits
            var newLimits: [BudgetCategoryLimit] = []
            
            for limit in currentBudget.categoryLimits {
                guard let category = limit.category else { continue }
                
                let newLimit = BudgetCategoryLimit(
                    category: category,
                    limitAmount: limit.limitAmount
                )
                newLimits.append(newLimit)
                modelContext.insert(newLimit)
            }
            
            // Create new budget
            let newBudget = Budget(
                month: nextMonth,
                year: nextYear,
                categoryLimits: newLimits
            )
            
            modelContext.insert(newBudget)
            
            try modelContext.save()
            
            // Optionally load the new budget
            loadBudget(month: nextMonth, year: nextYear)
            
        } catch let error as BudgetViewModelError {
            throw error
        } catch {
            print("Failed to copy budget to next month: \(error)")
            throw error
        }
    }
    
    // MARK: - Utility
    
    /// Returns whether the current budget exists.
    var hasBudget: Bool {
        currentBudget != nil
    }
    
    /// Returns the overall budget utilization percentage.
    var overallPercentageUsed: Double {
        guard totalBudget > 0 else { return 0 }
        return (Double(truncating: totalSpent as NSDecimalNumber) /
                Double(truncating: totalBudget as NSDecimalNumber)) * 100.0
    }
    
    /// Returns whether spending is within budget (not exceeded).
    var isWithinBudget: Bool {
        totalSpent <= totalBudget
    }
    
    /// Returns categories that are over budget.
    var overBudgetCategories: [(limit: BudgetCategoryLimit, spent: Decimal, remaining: Decimal, percentageUsed: Double)] {
        categoryProgress.filter { $0.percentageUsed > 100.0 }
    }
    
    /// Returns categories at risk (80%+ of budget used).
    var atRiskCategories: [(limit: BudgetCategoryLimit, spent: Decimal, remaining: Decimal, percentageUsed: Double)] {
        categoryProgress.filter { $0.percentageUsed >= 80.0 && $0.percentageUsed < 100.0 }
    }
    
    /// Returns the total amount over budget (0 if within budget).
    var totalOverBudget: Decimal {
        max(totalSpent - totalBudget, 0)
    }
    
    /// Returns the total remaining budget (0 if over budget).
    var totalRemaining: Decimal {
        max(totalBudget - totalSpent, 0)
    }
}

// MARK: - Errors

/// Errors that can occur during budget operations.
enum BudgetViewModelError: LocalizedError {
    case budgetAlreadyExists(month: Int, year: Int)
    case noBudgetLoaded
    case categoryAlreadyBudgeted(categoryName: String)
    
    var errorDescription: String? {
        switch self {
        case .budgetAlreadyExists(let month, let year):
            let monthName = DateFormatter().monthSymbols[month - 1]
            return "A budget already exists for \(monthName) \(year)."
            
        case .noBudgetLoaded:
            return "No budget is currently loaded. Load or create a budget first."
            
        case .categoryAlreadyBudgeted(let categoryName):
            return "The category '\(categoryName)' already has a limit in this budget."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .budgetAlreadyExists:
            return "Load the existing budget to edit it, or choose a different month."
            
        case .noBudgetLoaded:
            return "Create a new budget or load an existing one from a different month."
            
        case .categoryAlreadyBudgeted:
            return "Update the existing limit for this category instead of adding a new one."
        }
    }
}
