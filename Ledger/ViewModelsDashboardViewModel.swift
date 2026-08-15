//
//  DashboardViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages the main Dashboard (Panel) screen and core financial calculations.
///
/// **Core Financial Formula:**
/// ```
/// Current Capital = (Sum of Income) - (Sum of Expenses) + (Sum of Capital Adjustments)
/// ```
/// Only completed (non-pending) transactions are included in this calculation.
///
/// **Important Product Decision:**
/// Current Capital and Total Savings are two INDEPENDENT figures.
/// - **Current Capital**: Calculated from transaction history (income - expenses + adjustments)
/// - **Total Savings**: Sum of all savings fund balances
///
/// These are displayed SEPARATELY on the dashboard and are NEVER combined or subtracted
/// from each other. Savings are considered "set aside" money, while capital represents
/// the main account balance.
///
/// **Data Synchronization:**
/// This ViewModel does NOT automatically react to changes made in other ViewModels.
/// The View layer must call `loadDashboardData()` when:
/// - The dashboard view appears
/// - Returning to the dashboard tab from other modules
/// - After any transaction or savings mutation
///
/// This manual refresh is necessary because SwiftUI creates separate ViewModel instances
/// that don't share state automatically.
///
/// **Usage:**
/// ```swift
/// struct DashboardView: View {
///     @State private var viewModel: DashboardViewModel
///
///     init(modelContext: ModelContext) {
///         _viewModel = State(initialValue: DashboardViewModel(modelContext: modelContext))
///     }
///
///     var body: some View {
///         VStack {
///             // Capital and Savings Cards
///             // Monthly Income/Expense Summary
///             // Category Breakdown Charts
///         }
///         .onAppear {
///             viewModel.loadDashboardData()
///         }
///     }
/// }
/// ```
@Observable
final class DashboardViewModel {
    
    // MARK: - Properties
    
    /// Current capital calculated from all completed transactions.
    /// Formula: Income - Expenses + Capital Adjustments
    private(set) var currentCapital: Decimal = 0
    
    /// Total savings across all savings funds.
    /// This is SEPARATE from current capital (not added or subtracted).
    private(set) var totalSavings: Decimal = 0
    
    /// Total income for the current calendar month (completed transactions only).
    private(set) var monthlyIncome: Decimal = 0
    
    /// Total expenses for the current calendar month (completed transactions only).
    private(set) var monthlyExpenses: Decimal = 0
    
    /// Current month's expenses grouped by category, sorted by total descending.
    private(set) var expensesByCategory: [(category: Category, total: Decimal)] = []
    
    /// Current month's income grouped by category, sorted by total descending.
    private(set) var incomeByCategory: [(category: Category, total: Decimal)] = []
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the DashboardViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Loading
    
    /// Loads all dashboard data from SwiftData and recalculates financial metrics.
    ///
    /// This method should be called:
    /// - When the dashboard view first appears
    /// - When returning to the dashboard tab
    /// - After any transaction or savings mutations in other parts of the app
    ///
    /// **Note:** This is a manual refresh. SwiftUI ViewModels don't auto-sync with each other,
    /// so the View layer is responsible for calling this method at appropriate times.
    func loadDashboardData() {
        calculateCurrentCapital()
        calculateTotalSavings()
        calculateMonthlyTotals()
        calculateCategoryBreakdowns()
    }
    
    // MARK: - Capital Calculation
    
    /// Calculates current capital from all completed transactions.
    /// Formula: (Sum of Income) - (Sum of Expenses) + (Sum of Capital Adjustments)
    private func calculateCurrentCapital() {
        // Fetch all completed transactions
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.isPending == false
            }
        )
        
        do {
            let transactions = try modelContext.fetch(fetchDescriptor)
            
            var income: Decimal = 0
            var expenses: Decimal = 0
            var adjustments: Decimal = 0
            
            for transaction in transactions {
                switch transaction.type {
                case .income:
                    income += transaction.amount
                case .expense:
                    expenses += transaction.amount
                case .capitalAdjustment:
                    adjustments += transaction.amount
                }
            }
            
            // Capital = Income - Expenses + Adjustments
            currentCapital = income - expenses + adjustments
            
        } catch {
            print("Failed to calculate current capital: \(error)")
            currentCapital = 0
        }
    }
    
    /// Calculates total savings across all savings funds.
    /// Each fund's currentAmount is a computed property that sums its movements.
    private func calculateTotalSavings() {
        let fetchDescriptor = FetchDescriptor<SavingsFund>()
        
        do {
            let savingsFunds = try modelContext.fetch(fetchDescriptor)
            
            // Sum all fund balances
            totalSavings = savingsFunds.reduce(Decimal(0)) { total, fund in
                total + fund.currentAmount
            }
            
        } catch {
            print("Failed to calculate total savings: \(error)")
            totalSavings = 0
        }
    }
    
    // MARK: - Monthly Calculations
    
    /// Calculates income and expense totals for the current calendar month.
    private func calculateMonthlyTotals() {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // Fetch all completed transactions
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.isPending == false
            }
        )
        
        do {
            let transactions = try modelContext.fetch(fetchDescriptor)
            
            var income: Decimal = 0
            var expenses: Decimal = 0
            
            for transaction in transactions {
                let transactionMonth = calendar.component(.month, from: transaction.date)
                let transactionYear = calendar.component(.year, from: transaction.date)
                
                // Only count transactions from current month/year
                guard transactionMonth == currentMonth && transactionYear == currentYear else {
                    continue
                }
                
                switch transaction.type {
                case .income:
                    income += transaction.amount
                case .expense:
                    expenses += transaction.amount
                case .capitalAdjustment:
                    // Capital adjustments don't count toward monthly income/expenses
                    break
                }
            }
            
            monthlyIncome = income
            monthlyExpenses = expenses
            
        } catch {
            print("Failed to calculate monthly totals: \(error)")
            monthlyIncome = 0
            monthlyExpenses = 0
        }
    }
    
    /// Calculates category breakdowns for the current month.
    private func calculateCategoryBreakdowns() {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // Fetch all completed transactions for current month
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.isPending == false
            }
        )
        
        do {
            let transactions = try modelContext.fetch(fetchDescriptor)
            
            // Filter to current month only
            let currentMonthTransactions = transactions.filter { transaction in
                let transactionMonth = calendar.component(.month, from: transaction.date)
                let transactionYear = calendar.component(.year, from: transaction.date)
                return transactionMonth == currentMonth && transactionYear == currentYear
            }
            
            // Group by category for expenses
            var expenseGroups: [UUID: (category: Category, total: Decimal)] = [:]
            
            for transaction in currentMonthTransactions where transaction.type == .expense {
                guard let category = transaction.category else { continue }
                
                if let existing = expenseGroups[category.id] {
                    expenseGroups[category.id] = (category, existing.total + transaction.amount)
                } else {
                    expenseGroups[category.id] = (category, transaction.amount)
                }
            }
            
            // Group by category for income
            var incomeGroups: [UUID: (category: Category, total: Decimal)] = [:]
            
            for transaction in currentMonthTransactions where transaction.type == .income {
                guard let category = transaction.category else { continue }
                
                if let existing = incomeGroups[category.id] {
                    incomeGroups[category.id] = (category, existing.total + transaction.amount)
                } else {
                    incomeGroups[category.id] = (category, transaction.amount)
                }
            }
            
            // Convert to arrays and sort by total descending
            expensesByCategory = expenseGroups.values
                .map { $0 }
                .sorted { $0.total > $1.total }
            
            incomeByCategory = incomeGroups.values
                .map { $0 }
                .sorted { $0.total > $1.total }
            
        } catch {
            print("Failed to calculate category breakdowns: \(error)")
            expensesByCategory = []
            incomeByCategory = []
        }
    }
    
    // MARK: - Capital Adjustment
    
    /// Creates a capital adjustment transaction.
    ///
    /// **⚠️ SECURITY WARNING:**
    /// This method does NOT perform biometric authentication. The calling code MUST
    /// authenticate the user via BiometricAuthService BEFORE calling this method.
    ///
    /// Capital adjustments are sensitive operations that require explicit user confirmation
    /// via Face ID, Touch ID, or device passcode.
    ///
    /// **Proper Usage:**
    /// ```swift
    /// // In the View layer:
    /// let authService = BiometricAuthService()
    ///
    /// do {
    ///     // 1. Authenticate FIRST
    ///     let authenticated = try await authService.authenticate(
    ///         reason: "Confirm to adjust your capital"
    ///     )
    ///
    ///     guard authenticated else { return }
    ///
    ///     // 2. THEN create the adjustment
    ///     try viewModel.createCapitalAdjustment(
    ///         amount: adjustmentAmount,
    ///         note: "Manual correction",
    ///         currency: selectedCurrency
    ///     )
    /// } catch {
    ///     print("Error: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - amount: The adjustment amount (can be positive or negative).
    ///   - note: Optional note explaining the adjustment.
    ///   - currency: The currency for this adjustment.
    /// - Throws: An error if the save operation fails.
    func createCapitalAdjustment(
        amount: Decimal,
        note: String?,
        currency: Currency
    ) throws {
        let adjustment = Transaction(
            type: .capitalAdjustment,
            unitPrice: amount,
            quantity: 1,
            amount: amount,
            currency: currency,
            descriptionText: "Capital Adjustment",
            category: nil,
            date: Date(),
            isPending: false,
            recurrenceRule: nil,
            note: note
        )
        
        modelContext.insert(adjustment)
        
        do {
            try modelContext.save()
            // Reload dashboard data to reflect the new capital
            loadDashboardData()
        } catch {
            print("Failed to save capital adjustment: \(error)")
            throw error
        }
    }
    
    // MARK: - Utility
    
    /// Returns the net change (income - expenses) for the current month.
    var monthlyNetChange: Decimal {
        monthlyIncome - monthlyExpenses
    }
    
    /// Returns whether the user is in a surplus (positive net change) this month.
    var isInSurplusThisMonth: Bool {
        monthlyNetChange > 0
    }
    
    /// Returns the top N expense categories by spending for the current month.
    ///
    /// - Parameter limit: Maximum number of categories to return.
    /// - Returns: Top categories sorted by total descending.
    func topExpenseCategories(limit: Int = 5) -> [(category: Category, total: Decimal)] {
        Array(expensesByCategory.prefix(limit))
    }
    
    /// Returns the top N income categories for the current month.
    ///
    /// - Parameter limit: Maximum number of categories to return.
    /// - Returns: Top categories sorted by total descending.
    func topIncomeCategories(limit: Int = 5) -> [(category: Category, total: Decimal)] {
        Array(incomeByCategory.prefix(limit))
    }
    
    /// Returns the percentage of monthly income spent on expenses.
    ///
    /// - Returns: Percentage as Decimal (0-100), or 0 if no income.
    var expenseRatio: Decimal {
        guard monthlyIncome > 0 else { return 0 }
        return (monthlyExpenses / monthlyIncome) * 100
    }
    
    /// Returns the total amount spent in a specific category this month.
    ///
    /// - Parameter category: The category to check.
    /// - Returns: Total spent in that category, or 0 if none.
    func totalSpent(in category: Category) -> Decimal {
        expensesByCategory.first { $0.category.id == category.id }?.total ?? 0
    }
    
    /// Returns the total amount earned in a specific category this month.
    ///
    /// - Parameter category: The category to check.
    /// - Returns: Total earned in that category, or 0 if none.
    func totalEarned(in category: Category) -> Decimal {
        incomeByCategory.first { $0.category.id == category.id }?.total ?? 0
    }
}
