//
//  TransactionListViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages transaction data operations for Income and Expense modules.
///
/// This is the core ViewModel of FinVault, powering both the Ingresos (Income) and
/// Gastos (Expense) modules. Each module creates its own instance with the appropriate
/// TransactionType, providing module-specific data isolation while sharing identical logic.
///
/// **Module Instantiation:**
/// ```swift
/// // Income module
/// let incomeViewModel = TransactionListViewModel(
///     modelContext: context,
///     type: .income
/// )
///
/// // Expense module
/// let expenseViewModel = TransactionListViewModel(
///     modelContext: context,
///     type: .expense
/// )
/// ```
///
/// **Key Features:**
/// - Separates completed and pending transactions
/// - Provides monthly, yearly, and historic totals
/// - Supports recurring transactions via RecurrenceRule
/// - Enables search and filtering
/// - Groups transactions by month for timeline views
///
/// **Note:** Capital adjustments (.capitalAdjustment) are NOT handled by this ViewModel.
/// They have a dedicated flow with biometric authentication protection.
///
/// **SwiftData Integration:**
/// - All mutations automatically reload data to keep UI in sync
/// - Uses Decimal arithmetic for financial precision
/// - Respects relationship delete rules (nullify for categories, cascade for recurrence rules)
@Observable
final class TransactionListViewModel {
    
    // MARK: - Properties
    
    /// All completed (non-pending) transactions of this type, sorted by date descending.
    private(set) var transactions: [Transaction] = []
    
    /// All pending transactions of this type, sorted by date ascending (soonest due first).
    private(set) var pendingTransactions: [Transaction] = []
    
    /// Total amount for the current month (completed transactions only).
    private(set) var totalThisMonth: Decimal = 0
    
    /// Total amount for the current year (completed transactions only).
    private(set) var totalThisYear: Decimal = 0
    
    /// Total amount across all time (completed transactions only).
    private(set) var totalHistoric: Decimal = 0
    
    /// The transaction type this ViewModel manages (.income or .expense).
    private let type: TransactionType
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the TransactionListViewModel for a specific transaction type.
    ///
    /// - Parameters:
    ///   - modelContext: The ModelContext to use for data operations.
    ///   - type: The transaction type to manage (.income or .expense).
    init(modelContext: ModelContext, type: TransactionType) {
        self.modelContext = modelContext
        self.type = type
    }
    
    // MARK: - Data Loading
    
    /// Loads all transactions of this type from SwiftData and recalculates totals.
    ///
    /// Separates transactions into completed and pending arrays, then calculates
    /// monthly, yearly, and historic totals based on completed transactions only.
    func loadTransactions() {
        // Capture type in a local variable for predicate
        let transactionType = self.type
        
        // Fetch all transactions of this type
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.type == transactionType
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let allTransactions = try modelContext.fetch(fetchDescriptor)
            
            // Separate completed and pending transactions
            let completed = allTransactions.filter { !$0.isPending }
            let pending = allTransactions.filter { $0.isPending }
            
            // Sort completed by date descending (most recent first)
            self.transactions = completed.sorted { $0.date > $1.date }
            
            // Sort pending by date ascending (soonest due first)
            self.pendingTransactions = pending.sorted { $0.date < $1.date }
            
            // Calculate totals from completed transactions only
            calculateTotals()
            
        } catch {
            print("Failed to load transactions: \(error)")
            transactions = []
            pendingTransactions = []
            totalThisMonth = 0
            totalThisYear = 0
            totalHistoric = 0
        }
    }
    
    /// Recalculates monthly, yearly, and historic totals from completed transactions.
    private func calculateTotals() {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        var monthTotal: Decimal = 0
        var yearTotal: Decimal = 0
        var historicTotal: Decimal = 0
        
        for transaction in transactions {
            let transactionMonth = calendar.component(.month, from: transaction.date)
            let transactionYear = calendar.component(.year, from: transaction.date)
            
            // Add to historic total
            historicTotal += transaction.amount
            
            // Add to year total if in current year
            if transactionYear == currentYear {
                yearTotal += transaction.amount
                
                // Add to month total if in current month
                if transactionMonth == currentMonth {
                    monthTotal += transaction.amount
                }
            }
        }
        
        totalThisMonth = monthTotal
        totalThisYear = yearTotal
        totalHistoric = historicTotal
    }
    
    // MARK: - Create
    
    /// Adds a new completed (non-pending, non-recurring) transaction.
    ///
    /// This creates a "puntual" transaction — a one-time, already-completed entry.
    ///
    /// - Parameters:
    ///   - unitPrice: The price per unit.
    ///   - quantity: The number of units (default 1).
    ///   - descriptionText: A description of the transaction.
    ///   - category: The category to assign (optional, can be nil for uncategorized).
    ///   - date: The date the transaction occurred.
    ///   - currency: The currency used.
    /// - Throws: An error if the save operation fails.
    func addTransaction(
        unitPrice: Decimal,
        quantity: Int,
        descriptionText: String,
        category: Category?,
        date: Date,
        currency: Currency
    ) throws {
        let amount = unitPrice * Decimal(quantity)
        
        let newTransaction = Transaction(
            type: type,
            unitPrice: unitPrice,
            quantity: quantity,
            amount: amount,
            currency: currency,
            descriptionText: descriptionText,
            category: category,
            date: date,
            isPending: false,
            recurrenceRule: nil,
            note: nil
        )
        
        modelContext.insert(newTransaction)
        
        do {
            try modelContext.save()
            loadTransactions()
        } catch {
            print("Failed to save transaction: \(error)")
            throw error
        }
    }
    
    /// Adds a new pending (planned) transaction, optionally with a recurrence rule.
    ///
    /// Pending transactions represent future planned income/expenses that haven't
    /// occurred yet. They can be marked as completed later via `completePendingTransaction()`.
    ///
    /// - Parameters:
    ///   - unitPrice: The expected price per unit.
    ///   - quantity: The number of units (default 1).
    ///   - descriptionText: A description of the transaction.
    ///   - category: The category to assign (optional).
    ///   - date: The due date for this transaction.
    ///   - currency: The currency to use.
    ///   - recurrenceRule: Optional recurrence rule for repeating transactions.
    /// - Throws: An error if the save operation fails.
    func addPendingTransaction(
        unitPrice: Decimal,
        quantity: Int,
        descriptionText: String,
        category: Category?,
        date: Date,
        currency: Currency,
        recurrenceRule: RecurrenceRule?
    ) throws {
        let amount = unitPrice * Decimal(quantity)
        
        let newTransaction = Transaction(
            type: type,
            unitPrice: unitPrice,
            quantity: quantity,
            amount: amount,
            currency: currency,
            descriptionText: descriptionText,
            category: category,
            date: date,
            isPending: true,
            recurrenceRule: recurrenceRule,
            note: nil
        )
        
        modelContext.insert(newTransaction)
        
        do {
            try modelContext.save()
            loadTransactions()
        } catch {
            print("Failed to save pending transaction: \(error)")
            throw error
        }
    }
    
    // MARK: - Update
    
    /// Marks a pending transaction as completed.
    ///
    /// This converts a planned transaction into a real, completed transaction.
    /// The transaction's date is updated to today to reflect when it was actually completed,
    /// while preserving the original description and amount.
    ///
    /// - Parameter transaction: The pending transaction to complete.
    /// - Throws: An error if the save operation fails.
    func completePendingTransaction(_ transaction: Transaction) throws {
        transaction.isPending = false
        // Update date to today to reflect actual completion date
        transaction.date = Date()
        
        do {
            try modelContext.save()
            loadTransactions()
        } catch {
            print("Failed to complete pending transaction: \(error)")
            throw error
        }
    }
    
    /// Updates an existing transaction's properties.
    ///
    /// - Parameters:
    ///   - transaction: The transaction to update.
    ///   - unitPrice: The new price per unit.
    ///   - quantity: The new quantity.
    ///   - descriptionText: The new description.
    ///   - category: The new category (optional).
    ///   - date: The new date.
    /// - Throws: An error if the save operation fails.
    func updateTransaction(
        _ transaction: Transaction,
        unitPrice: Decimal,
        quantity: Int,
        descriptionText: String,
        category: Category?,
        date: Date
    ) throws {
        transaction.unitPrice = unitPrice
        transaction.quantity = quantity
        transaction.amount = unitPrice * Decimal(quantity)
        transaction.descriptionText = descriptionText
        transaction.category = category
        transaction.date = date
        
        do {
            try modelContext.save()
            loadTransactions()
        } catch {
            print("Failed to update transaction: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    /// Deletes a transaction from SwiftData.
    ///
    /// **Note:** If the transaction has a recurrence rule, it will also be deleted
    /// due to the cascade delete rule on Transaction.recurrenceRule.
    ///
    /// - Parameter transaction: The transaction to delete.
    /// - Throws: An error if the save operation fails.
    func deleteTransaction(_ transaction: Transaction) throws {
        modelContext.delete(transaction)
        
        do {
            try modelContext.save()
            loadTransactions()
        } catch {
            print("Failed to delete transaction: \(error)")
            throw error
        }
    }
    
    // MARK: - Filtering
    
    /// Filters completed transactions based on search text, category, and date range.
    ///
    /// All filter criteria are optional. Empty/nil values mean "no filter" for that criterion.
    ///
    /// - Parameters:
    ///   - searchText: Text to search in description (case-insensitive). Empty string means no filter.
    ///   - category: Category to filter by. Nil means no filter.
    ///   - dateRange: Date range to filter by. Nil means no filter.
    /// - Returns: Filtered array of transactions, maintaining date descending order.
    func filteredTransactions(
        searchText: String,
        category: Category?,
        dateRange: ClosedRange<Date>?
    ) -> [Transaction] {
        var filtered = transactions
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.descriptionText.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by category
        if let category = category {
            filtered = filtered.filter { $0.category?.id == category.id }
        }
        
        // Filter by date range
        if let dateRange = dateRange {
            filtered = filtered.filter { dateRange.contains($0.date) }
        }
        
        return filtered
    }
    
    // MARK: - Grouping
    
    /// Groups completed transactions by month, with Spanish month names.
    ///
    /// Each group contains:
    /// - `month`: Localized month/year string (e.g., "Agosto 2026")
    /// - `transactions`: Transactions in that month, sorted by date descending
    /// - `subtotal`: Sum of all transaction amounts in that month
    ///
    /// Groups are ordered by most recent month first.
    ///
    /// - Returns: Array of month groups with their transactions and subtotals.
    func transactionsGroupedByMonth() -> [(month: String, transactions: [Transaction], subtotal: Decimal)] {
        var groups: [String: [Transaction]] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es")
        dateFormatter.dateFormat = "MMMM yyyy"
        
        let calendar = Calendar.current
        
        // Group transactions by month
        for transaction in transactions {
            let monthKey = dateFormatter.string(from: transaction.date)
            groups[monthKey, default: []].append(transaction)
        }
        
        // Convert to array of tuples with subtotals
        var result: [(month: String, transactions: [Transaction], subtotal: Decimal)] = []
        
        for (monthKey, monthTransactions) in groups {
            // Sort transactions within each month by date descending
            let sorted = monthTransactions.sorted { $0.date > $1.date }
            
            // Calculate subtotal for this month
            let subtotal = sorted.reduce(Decimal(0)) { $0 + $1.amount }
            
            result.append((month: monthKey, transactions: sorted, subtotal: subtotal))
        }
        
        // Sort groups by most recent month first
        // Extract the first transaction date from each group for comparison
        result.sort { group1, group2 in
            guard let date1 = group1.transactions.first?.date,
                  let date2 = group2.transactions.first?.date else {
                return false
            }
            return date1 > date2
        }
        
        return result
    }
    
    // MARK: - Utility
    
    /// Returns the count of all transactions (completed + pending) of this type.
    var totalTransactionCount: Int {
        transactions.count + pendingTransactions.count
    }
    
    /// Returns whether there are any transactions of this type.
    var isEmpty: Bool {
        transactions.isEmpty && pendingTransactions.isEmpty
    }
    
    /// Returns the most recent transaction, if any.
    var mostRecentTransaction: Transaction? {
        transactions.first
    }
    
    /// Returns transactions for a specific month and year.
    ///
    /// - Parameters:
    ///   - month: The month (1-12).
    ///   - year: The year.
    /// - Returns: Transactions in that month, sorted by date descending.
    func transactions(forMonth month: Int, year: Int) -> [Transaction] {
        let calendar = Calendar.current
        
        return transactions.filter { transaction in
            let components = calendar.dateComponents([.month, .year], from: transaction.date)
            return components.month == month && components.year == year
        }
    }
    
    /// Calculates the total for a specific month and year.
    ///
    /// - Parameters:
    ///   - month: The month (1-12).
    ///   - year: The year.
    /// - Returns: The total amount for that month.
    func total(forMonth month: Int, year: Int) -> Decimal {
        let monthTransactions = transactions(forMonth: month, year: year)
        return monthTransactions.reduce(Decimal(0)) { $0 + $1.amount }
    }
}
