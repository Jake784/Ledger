//
//  HistoryViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages the combined Historial (History) module — every income
/// and expense transaction together, in chronological order.
///
/// Mirrors `TransactionListViewModel`'s structure and conventions closely, but
/// without a fixed `type`: it loads both `.income` and `.expense` transactions
/// (never `.capitalAdjustment`, which — as `TransactionListViewModel` documents —
/// has its own dedicated, biometric-protected flow and isn't part of regular
/// transaction history) and adds a `type` axis to its filtering.
///
/// **SwiftData Integration:**
/// - All mutations happen elsewhere (Income/Expenses modules); this ViewModel is read-only.
/// - Uses Decimal arithmetic for financial precision.
@Observable
final class HistoryViewModel {

    // MARK: - Properties

    /// All completed (non-pending) income and expense transactions, sorted by date descending.
    private(set) var transactions: [Transaction] = []

    /// All pending income and expense transactions, sorted by date ascending (soonest due first).
    private(set) var pendingTransactions: [Transaction] = []

    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Initializes the HistoryViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Data Loading

    /// Loads all income and expense transactions from SwiftData, excluding capital adjustments.
    ///
    /// Separates transactions into completed and pending arrays, matching
    /// `TransactionListViewModel`'s own separation.
    func loadTransactions() {
        // SwiftData's #Predicate macro doesn't support comparing a model's custom
        // enum property against a captured enum constant — it throws
        // `SwiftDataError.unsupportedPredicate` ("Captured/constant values of type
        // 'TransactionType' are not supported") at fetch time, even when the value is
        // hoisted to a local `let` first (confirmed by direct testing — this was the
        // root cause of Income/Expenses transactions never appearing). Fetch without
        // filtering by `type` in the predicate and exclude capital adjustments in plain
        // Swift instead, matching `DashboardViewModel.calculateCurrentCapital()`'s
        // already-working pattern, which filters only on `isPending` (a Bool) in the
        // predicate and switches on `transaction.type` after fetching.
        let fetchDescriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let allTransactions = try modelContext.fetch(fetchDescriptor)
            let relevantTransactions = allTransactions.filter { $0.type != .capitalAdjustment }

            let completed = relevantTransactions.filter { !$0.isPending }
            let pending = relevantTransactions.filter { $0.isPending }

            self.transactions = completed.sorted { $0.date > $1.date }
            self.pendingTransactions = pending.sorted { $0.date < $1.date }

        } catch {
            print("Failed to load transaction history: \(error)")
            transactions = []
            pendingTransactions = []
        }
    }

    // MARK: - Filtering

    /// Filters completed transactions based on transaction type, search text, category, and date range.
    ///
    /// All filter criteria are optional. Nil/empty values mean "no filter" for that criterion.
    ///
    /// - Parameters:
    ///   - type: Transaction type to filter by (.income or .expense). Nil means both.
    ///   - searchText: Text to search in description (case-insensitive). Empty string means no filter.
    ///   - category: Category to filter by. Nil means no filter.
    ///   - dateRange: Date range to filter by. Nil means no filter.
    /// - Returns: Filtered array of transactions, maintaining date descending order.
    func filteredTransactions(
        type: TransactionType?,
        searchText: String,
        category: Category?,
        dateRange: ClosedRange<Date>?
    ) -> [Transaction] {
        var filtered = transactions

        if let type {
            filtered = filtered.filter { $0.type == type }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.descriptionText.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category {
            filtered = filtered.filter { $0.category?.id == category.id }
        }

        if let dateRange {
            filtered = filtered.filter { dateRange.contains($0.date) }
        }

        return filtered
    }

    // MARK: - Grouping

    /// Groups a set of transactions by month, with Spanish month names.
    ///
    /// Unlike `TransactionListViewModel.transactionsGroupedByMonth()` (which sums a single
    /// type into one subtotal), each group's total nets income against expense, since History
    /// combines both — `netTotal` is positive when income outweighs expense in that month.
    ///
    /// - Parameter transactions: The transactions to group (typically the result of
    ///   `filteredTransactions`, or `self.transactions` for the unfiltered view).
    /// - Returns: Array of month groups, most recent month first.
    func groupedByMonth(_ transactions: [Transaction]) -> [(month: String, transactions: [Transaction], netTotal: Decimal)] {
        var groups: [String: [Transaction]] = [:]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es")
        dateFormatter.dateFormat = "MMMM yyyy"

        for transaction in transactions {
            let monthKey = dateFormatter.string(from: transaction.date)
            groups[monthKey, default: []].append(transaction)
        }

        var result: [(month: String, transactions: [Transaction], netTotal: Decimal)] = []

        for (monthKey, monthTransactions) in groups {
            let sorted = monthTransactions.sorted { $0.date > $1.date }

            let netTotal = sorted.reduce(Decimal(0)) { total, transaction in
                transaction.type == .income ? total + transaction.amount : total - transaction.amount
            }

            result.append((month: monthKey, transactions: sorted, netTotal: netTotal))
        }

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

    /// Returns whether there is any transaction history (completed or pending) at all.
    var isEmpty: Bool {
        transactions.isEmpty && pendingTransactions.isEmpty
    }
}
