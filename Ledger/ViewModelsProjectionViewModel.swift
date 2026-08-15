//
//  ProjectionViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages financial projections and compares them with real transaction data.
///
/// **Projection vs. Budget - Key Distinction:**
///
/// **Projections (THIS ViewModel):**
/// - Annual financial forecasting tool
/// - Use SIMULATED/ESTIMATED data for planning
/// - Create "what-if" scenarios with different assumptions
/// - Cross-reference with real data to measure accuracy
/// - Prospective planning (looking forward)
///
/// **Budgets (BudgetViewModel):**
/// - Monthly spending control tool
/// - Track REAL spending against planned limits
/// - Compare actual expenses to budgeted amounts
/// - Retrospective analysis (looking backward)
///
/// **Starting Capital Modes:**
///
/// 1. **Actual Capital (.actualCapital):**
///    - Uses the real current capital from transaction history
///    - Formula: (Sum of Income) - (Sum of Expenses) + (Sum of Capital Adjustments)
///    - Same calculation as DashboardViewModel
///    - Best for realistic projections based on current financial state
///
/// 2. **Simulated Capital (.simulatedCapital):**
///    - Uses a user-provided hypothetical starting amount
///    - Allows modeling "what if I started with X amount" scenarios
///    - Useful for goal planning and financial experiments
///
/// **Real Data Cross-Reference - Category-Level Tracking:**
///
/// Projections estimate income/expense amounts per category and month. When comparing
/// to real data, the system:
/// - Identifies which categories are included in the projection's items
/// - Sums actual transactions in those categories for each month
/// - Compares estimated vs. real at the category level (NOT per individual item)
///
/// Example:
/// - Projection has two items: "Base Salary" and "Freelance Work" both in category "Salario"
/// - Real comparison sums ALL transactions in "Salario" category for each month
/// - This prevents double-counting and matches how users think about categories
///
/// **Model Accuracy Formula:**
///
/// Accuracy measures how closely the projection's estimates match reality.
/// Only months that have already occurred (have real transaction data) are counted.
///
/// Formula:
/// ```
/// For each past month:
///   monthError = abs((realBalance - projectedBalance) / realBalance) * 100
///   (0% = perfect match, 100% = completely wrong)
///
/// averageError = mean of all monthErrors
/// accuracy = max(0, 100 - averageError)
/// ```
///
/// Result: 100% = perfect prediction, 0% = extremely inaccurate
///
/// **Dynamic Projection:**
///
/// Combines real data with future estimates:
/// ```
/// dynamicProjection = currentRealCapital + sumOfFutureEstimatedNet
/// ```
///
/// Where:
/// - currentRealCapital = actual capital from all completed transactions
/// - sumOfFutureEstimatedNet = sum of (estimatedIncome - estimatedExpense) for months not yet occurred
///
/// This provides a "most likely outcome" based on past reality and future plans.
///
/// **Usage:**
/// ```swift
/// struct ProjectionView: View {
///     @State private var viewModel: ProjectionViewModel
///
///     var body: some View {
///         if let projection = viewModel.currentProjection {
///             VStack {
///                 // Monthly breakdown chart
///                 // Model accuracy indicator
///                 // Dynamic projection display
///             }
///         }
///     }
/// }
/// ```
@Observable
final class ProjectionViewModel {
    
    // MARK: - Properties
    
    /// The currently active/selected projection.
    private(set) var currentProjection: Projection?
    
    /// All projections, sorted by year descending (newest first).
    private(set) var allProjections: [Projection] = []
    
    /// Monthly breakdown comparing estimated vs. real data for the current projection.
    private(set) var monthlyBreakdown: [(
        month: Int,
        estimatedIncome: Decimal,
        realIncome: Decimal,
        estimatedExpense: Decimal,
        realExpense: Decimal,
        projectedBalance: Decimal,
        realBalance: Decimal
    )] = []
    
    /// Model accuracy percentage (0-100).
    /// 100% = perfect match between estimates and reality.
    /// Only calculated for months that have already occurred.
    private(set) var modelAccuracy: Double = 0
    
    /// Dynamic projection combining real capital with future estimates.
    /// Formula: currentRealCapital + sum of future months' estimated net.
    private(set) var dynamicProjection: Decimal = 0
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the ProjectionViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Loading
    
    /// Loads a specific projection and recalculates all derived values.
    ///
    /// - Parameter projection: The projection to load and analyze.
    func loadProjection(_ projection: Projection) {
        currentProjection = projection
        calculateMonthlyBreakdown()
        calculateModelAccuracy()
        calculateDynamicProjection()
    }
    
    /// Loads all projections from SwiftData.
    func loadAllProjections() {
        let fetchDescriptor = FetchDescriptor<Projection>(
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        
        do {
            allProjections = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to load projections: \(error)")
            allProjections = []
        }
    }
    
    // MARK: - Monthly Breakdown Calculation
    
    /// Calculates the monthly breakdown for the current projection.
    private func calculateMonthlyBreakdown() {
        guard let projection = currentProjection else {
            monthlyBreakdown = []
            return
        }
        
        var breakdown: [(
            month: Int,
            estimatedIncome: Decimal,
            realIncome: Decimal,
            estimatedExpense: Decimal,
            realExpense: Decimal,
            projectedBalance: Decimal,
            realBalance: Decimal
        )] = []
        
        // Get starting capital
        let startingCapital = getStartingCapital(for: projection)
        
        // Collect categories used in this projection for real data filtering
        let projectionCategories = Set(projection.items.compactMap { $0.category?.id })
        
        var cumulativeEstimatedNet: Decimal = 0
        var cumulativeRealNet: Decimal = 0
        
        for month in 1...12 {
            // Calculate estimated income and expense
            let estimatedIncome = calculateEstimatedIncome(for: month, in: projection)
            let estimatedExpense = calculateEstimatedExpense(for: month, in: projection)
            
            // Calculate real income and expense (only in projection's categories)
            let (realIncome, realExpense) = calculateRealAmounts(
                for: month,
                year: projection.year,
                categories: projectionCategories
            )
            
            // Update cumulative nets
            cumulativeEstimatedNet += (estimatedIncome - estimatedExpense)
            cumulativeRealNet += (realIncome - realExpense)
            
            // Calculate balances
            let projectedBalance = startingCapital + cumulativeEstimatedNet
            let realBalance = startingCapital + cumulativeRealNet
            
            breakdown.append((
                month: month,
                estimatedIncome: estimatedIncome,
                realIncome: realIncome,
                estimatedExpense: estimatedExpense,
                realExpense: realExpense,
                projectedBalance: projectedBalance,
                realBalance: realBalance
            ))
        }
        
        monthlyBreakdown = breakdown
    }
    
    /// Gets the starting capital for a projection based on its mode.
    private func getStartingCapital(for projection: Projection) -> Decimal {
        switch projection.startingCapitalMode {
        case .actualCapital:
            return calculateCurrentCapital()
        case .simulatedCapital:
            return projection.simulatedStartingCapital ?? 0
        }
    }
    
    /// Calculates current capital from all completed transactions.
    /// Same formula as DashboardViewModel.
    private func calculateCurrentCapital() -> Decimal {
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
            
            return income - expenses + adjustments
            
        } catch {
            print("Failed to calculate current capital: \(error)")
            return 0
        }
    }
    
    /// Calculates estimated income for a specific month in the projection.
    private func calculateEstimatedIncome(for month: Int, in projection: Projection) -> Decimal {
        return projection.items
            .filter { item in
                (item.itemType == .fixedIncome || item.itemType == .variableIncome) &&
                item.appliedMonths.contains(month)
            }
            .reduce(Decimal(0)) { $0 + $1.estimatedMonthly }
    }
    
    /// Calculates estimated expense for a specific month in the projection.
    private func calculateEstimatedExpense(for month: Int, in projection: Projection) -> Decimal {
        return projection.items
            .filter { item in
                (item.itemType == .fixedExpense || item.itemType == .variableExpense) &&
                item.appliedMonths.contains(month)
            }
            .reduce(Decimal(0)) { $0 + $1.estimatedMonthly }
    }
    
    /// Calculates real income and expense for a month, filtered to projection's categories.
    private func calculateRealAmounts(
        for month: Int,
        year: Int,
        categories: Set<UUID>
    ) -> (income: Decimal, expense: Decimal) {
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.isPending == false
            }
        )
        
        do {
            let transactions = try modelContext.fetch(fetchDescriptor)
            let calendar = Calendar.current
            
            var income: Decimal = 0
            var expense: Decimal = 0
            
            for transaction in transactions {
                // Filter to correct month/year
                let components = calendar.dateComponents([.month, .year], from: transaction.date)
                guard components.month == month && components.year == year else { continue }
                
                // Filter to projection's categories only
                guard let categoryID = transaction.category?.id,
                      categories.contains(categoryID) else { continue }
                
                switch transaction.type {
                case .income:
                    income += transaction.amount
                case .expense:
                    expense += transaction.amount
                case .capitalAdjustment:
                    break // Not counted in projections
                }
            }
            
            return (income, expense)
            
        } catch {
            print("Failed to calculate real amounts: \(error)")
            return (0, 0)
        }
    }
    
    // MARK: - Model Accuracy Calculation
    
    /// Calculates how accurate the projection has been so far.
    ///
    /// Only considers months that have already occurred (past months).
    /// Formula: 100 - averageAbsolutePercentageError
    private func calculateModelAccuracy() {
        guard !monthlyBreakdown.isEmpty else {
            modelAccuracy = 0
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        guard let projection = currentProjection else {
            modelAccuracy = 0
            return
        }
        
        var errors: [Double] = []
        
        for breakdown in monthlyBreakdown {
            // Only consider months that have already occurred
            if projection.year < currentYear ||
               (projection.year == currentYear && breakdown.month <= currentMonth) {
                
                // Skip months with zero real balance (no data)
                guard breakdown.realBalance != 0 else { continue }
                
                // Calculate percentage error
                let realBalance = Double(truncating: breakdown.realBalance as NSDecimalNumber)
                let projectedBalance = Double(truncating: breakdown.projectedBalance as NSDecimalNumber)
                
                let percentageError = abs((realBalance - projectedBalance) / realBalance) * 100.0
                errors.append(percentageError)
            }
        }
        
        // Calculate accuracy
        if errors.isEmpty {
            modelAccuracy = 0 // No past data to compare
        } else {
            let averageError = errors.reduce(0, +) / Double(errors.count)
            modelAccuracy = max(0, 100 - averageError)
        }
    }
    
    // MARK: - Dynamic Projection Calculation
    
    /// Calculates the dynamic projection: current capital + future estimated net.
    private func calculateDynamicProjection() {
        let currentCapital = calculateCurrentCapital()
        
        guard let projection = currentProjection else {
            dynamicProjection = currentCapital
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        var futureEstimatedNet: Decimal = 0
        
        for breakdown in monthlyBreakdown {
            // Only count future months
            if projection.year > currentYear ||
               (projection.year == currentYear && breakdown.month > currentMonth) {
                let monthNet = breakdown.estimatedIncome - breakdown.estimatedExpense
                futureEstimatedNet += monthNet
            }
        }
        
        dynamicProjection = currentCapital + futureEstimatedNet
    }
    
    // MARK: - Create
    
    /// Creates a new financial projection.
    ///
    /// - Parameters:
    ///   - name: The name for this projection.
    ///   - year: The year to project.
    ///   - startingCapitalMode: Whether to use actual or simulated capital.
    ///   - simulatedStartingCapital: Required if mode is .simulatedCapital, ignored otherwise.
    /// - Throws: An error if the save operation fails.
    func createProjection(
        name: String,
        year: Int,
        startingCapitalMode: CapitalMode,
        simulatedStartingCapital: Decimal?
    ) throws {
        let projection = Projection(
            name: name,
            year: year,
            startingCapitalMode: startingCapitalMode,
            simulatedStartingCapital: simulatedStartingCapital,
            items: []
        )
        
        modelContext.insert(projection)
        
        do {
            try modelContext.save()
            loadAllProjections()
        } catch {
            print("Failed to create projection: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    /// Deletes a projection and all its items.
    ///
    /// Due to the cascade delete rule, all ProjectionItems are automatically deleted.
    ///
    /// - Parameter projection: The projection to delete.
    /// - Throws: An error if the save operation fails.
    func deleteProjection(_ projection: Projection) throws {
        modelContext.delete(projection)
        
        do {
            try modelContext.save()
            
            // Clear current if it was deleted
            if currentProjection?.id == projection.id {
                currentProjection = nil
                monthlyBreakdown = []
                modelAccuracy = 0
                dynamicProjection = 0
            }
            
            loadAllProjections()
        } catch {
            print("Failed to delete projection: \(error)")
            throw error
        }
    }
    
    // MARK: - Projection Items
    
    /// Adds a new item to the current projection.
    ///
    /// - Parameters:
    ///   - concept: Description of this item.
    ///   - category: The category for this item.
    ///   - itemType: Type of projection item (fixed/variable income/expense).
    ///   - estimatedMonthly: Estimated monthly amount.
    ///   - appliedMonths: Months (1-12) where this item applies.
    /// - Throws: `ProjectionViewModelError.noProjectionLoaded` if no projection is loaded,
    ///           or a save error if persistence fails.
    func addProjectionItem(
        concept: String,
        category: Category,
        itemType: ProjectionItemType,
        estimatedMonthly: Decimal,
        appliedMonths: [Int]
    ) throws {
        guard let projection = currentProjection else {
            throw ProjectionViewModelError.noProjectionLoaded
        }
        
        let item = ProjectionItem(
            concept: concept,
            category: category,
            itemType: itemType,
            estimatedMonthly: estimatedMonthly,
            appliedMonths: appliedMonths
        )
        
        projection.items.append(item)
        modelContext.insert(item)
        
        do {
            try modelContext.save()
            // Recalculate with new item
            calculateMonthlyBreakdown()
            calculateModelAccuracy()
            calculateDynamicProjection()
        } catch {
            print("Failed to add projection item: \(error)")
            throw error
        }
    }
    
    /// Updates an existing projection item.
    ///
    /// - Parameters:
    ///   - item: The item to update.
    ///   - concept: New concept description.
    ///   - estimatedMonthly: New estimated monthly amount.
    ///   - appliedMonths: New applied months.
    /// - Throws: An error if the save operation fails.
    func updateProjectionItem(
        _ item: ProjectionItem,
        concept: String,
        estimatedMonthly: Decimal,
        appliedMonths: [Int]
    ) throws {
        item.concept = concept
        item.estimatedMonthly = estimatedMonthly
        item.appliedMonths = appliedMonths
        
        do {
            try modelContext.save()
            // Recalculate with updated item
            calculateMonthlyBreakdown()
            calculateModelAccuracy()
            calculateDynamicProjection()
        } catch {
            print("Failed to update projection item: \(error)")
            throw error
        }
    }
    
    /// Deletes a projection item.
    ///
    /// - Parameter item: The item to delete.
    /// - Throws: An error if the save operation fails.
    func deleteProjectionItem(_ item: ProjectionItem) throws {
        guard let projection = currentProjection else {
            throw ProjectionViewModelError.noProjectionLoaded
        }
        
        projection.items.removeAll { $0.id == item.id }
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            // Recalculate without this item
            calculateMonthlyBreakdown()
            calculateModelAccuracy()
            calculateDynamicProjection()
        } catch {
            print("Failed to delete projection item: \(error)")
            throw error
        }
    }
    
    // MARK: - Grouping
    
    /// Groups projection items by type for the four-tab UI.
    ///
    /// Returns a dictionary with keys:
    /// - .fixedExpense
    /// - .variableExpense
    /// - .fixedIncome
    /// - .variableIncome
    ///
    /// - Returns: Dictionary mapping item types to their items.
    func itemsGroupedByType() -> [ProjectionItemType: [ProjectionItem]] {
        guard let projection = currentProjection else {
            return [:]
        }
        
        var grouped: [ProjectionItemType: [ProjectionItem]] = [
            .fixedExpense: [],
            .variableExpense: [],
            .fixedIncome: [],
            .variableIncome: []
        ]
        
        for item in projection.items {
            grouped[item.itemType, default: []].append(item)
        }
        
        return grouped
    }
    
    // MARK: - Utility
    
    /// Returns whether a projection is currently loaded.
    var hasProjection: Bool {
        currentProjection != nil
    }
    
    /// Returns the total estimated annual income.
    var totalEstimatedIncome: Decimal {
        monthlyBreakdown.reduce(Decimal(0)) { $0 + $1.estimatedIncome }
    }
    
    /// Returns the total estimated annual expense.
    var totalEstimatedExpense: Decimal {
        monthlyBreakdown.reduce(Decimal(0)) { $0 + $1.estimatedExpense }
    }
    
    /// Returns the estimated annual net (income - expense).
    var estimatedAnnualNet: Decimal {
        totalEstimatedIncome - totalEstimatedExpense
    }
    
    /// Returns the total real annual income (so far).
    var totalRealIncome: Decimal {
        monthlyBreakdown.reduce(Decimal(0)) { $0 + $1.realIncome }
    }
    
    /// Returns the total real annual expense (so far).
    var totalRealExpense: Decimal {
        monthlyBreakdown.reduce(Decimal(0)) { $0 + $1.realExpense }
    }
    
    /// Returns the real annual net (so far).
    var realAnnualNet: Decimal {
        totalRealIncome - totalRealExpense
    }
    
    /// Returns the projected end-of-year balance.
    var projectedYearEndBalance: Decimal {
        monthlyBreakdown.last?.projectedBalance ?? 0
    }
}

// MARK: - Errors

/// Errors that can occur during projection operations.
enum ProjectionViewModelError: LocalizedError {
    case noProjectionLoaded
    
    var errorDescription: String? {
        switch self {
        case .noProjectionLoaded:
            return "No projection is currently loaded. Load or create a projection first."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noProjectionLoaded:
            return "Select an existing projection or create a new one."
        }
    }
}
