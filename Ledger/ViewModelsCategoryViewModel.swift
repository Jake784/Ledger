//
//  CategoryViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages category data operations for the UI layer.
///
/// This ViewModel provides CRUD operations for both predefined and custom categories,
/// separating expense and income categories for easy display in the UI.
///
/// **Usage in Views:**
/// ```swift
/// struct CategoryListView: View {
///     @State private var viewModel: CategoryViewModel
///
///     init(modelContext: ModelContext) {
///         _viewModel = State(initialValue: CategoryViewModel(modelContext: modelContext))
///     }
///
///     var body: some View {
///         List {
///             Section("Expenses") {
///                 ForEach(viewModel.expenseCategories) { category in
///                     CategoryRow(category: category)
///                 }
///             }
///             Section("Income") {
///                 ForEach(viewModel.incomeCategories) { category in
///                     CategoryRow(category: category)
///                 }
///             }
///         }
///         .onAppear {
///             viewModel.loadCategories()
///         }
///     }
/// }
/// ```
///
/// **SwiftData Integration:**
/// - Requires a ModelContext for all data operations
/// - Automatically refreshes category lists after mutations
/// - Respects delete rules (nullify for transactions, preventing orphaned data)
@Observable
final class CategoryViewModel {
    
    // MARK: - Properties
    
    /// All expense categories, sorted alphabetically.
    private(set) var expenseCategories: [Category] = []
    
    /// All income categories, sorted alphabetically.
    private(set) var incomeCategories: [Category] = []
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the CategoryViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Loading
    
    /// Loads all categories from SwiftData and populates expense and income arrays.
    ///
    /// Categories are automatically sorted alphabetically by name.
    /// Call this method when the view appears or after performing mutations.
    func loadCategories() {
        let fetchDescriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        
        do {
            let allCategories = try modelContext.fetch(fetchDescriptor)
            
            // Separate into expense and income categories
            expenseCategories = allCategories.filter { $0.type == .expense }
            incomeCategories = allCategories.filter { $0.type == .income }
            
        } catch {
            print("Failed to load categories: \(error)")
            expenseCategories = []
            incomeCategories = []
        }
    }
    
    // MARK: - Create
    
    /// Creates a new custom category and saves it to SwiftData.
    ///
    /// - Parameters:
    ///   - name: The display name for the category.
    ///   - type: Whether this is an expense or income category.
    ///   - icon: SF Symbol name for the category icon.
    ///   - color: Hex color string (e.g., "#FF3B30").
    /// - Throws: An error if the save operation fails.
    func addCustomCategory(
        name: String,
        type: CategoryType,
        icon: String,
        color: String
    ) throws {
        let newCategory = Category(
            name: name,
            type: type,
            icon: icon,
            color: color,
            isCustom: true
        )
        
        modelContext.insert(newCategory)
        
        do {
            try modelContext.save()
            loadCategories()
        } catch {
            print("Failed to save new category: \(error)")
            throw error
        }
    }
    
    // MARK: - Update
    
    /// Updates an existing custom category's properties.
    ///
    /// Only custom categories (isCustom == true) can be modified.
    /// Predefined categories are read-only to maintain consistency.
    ///
    /// - Parameters:
    ///   - category: The category to update.
    ///   - name: The new display name.
    ///   - icon: The new SF Symbol name.
    ///   - color: The new hex color string.
    /// - Throws: `CategoryViewModelError.cannotModifyPredefinedCategory` if attempting to modify a predefined category,
    ///           or a save error if persistence fails.
    func updateCategory(
        _ category: Category,
        name: String,
        icon: String,
        color: String
    ) throws {
        guard category.isCustom else {
            throw CategoryViewModelError.cannotModifyPredefinedCategory
        }
        
        category.name = name
        category.icon = icon
        category.color = color
        
        do {
            try modelContext.save()
            loadCategories()
        } catch {
            print("Failed to update category: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    /// Deletes a custom category from SwiftData.
    ///
    /// Only custom categories (isCustom == true) can be deleted.
    /// Predefined categories are protected from deletion to maintain app consistency.
    ///
    /// **Important:** Any transactions currently using this category will have their
    /// `category` relationship set to `nil` (becoming "uncategorized") due to the
    /// `.nullify` delete rule on the Transaction.category relationship. The UI should
    /// warn users about this before confirming deletion if the category is in use.
    ///
    /// - Parameter category: The category to delete.
    /// - Throws: `CategoryViewModelError.cannotModifyPredefinedCategory` if attempting to delete a predefined category,
    ///           or a save error if persistence fails.
    func deleteCategory(_ category: Category) throws {
        guard category.isCustom else {
            throw CategoryViewModelError.cannotModifyPredefinedCategory
        }
        
        modelContext.delete(category)
        
        do {
            try modelContext.save()
            loadCategories()
        } catch {
            print("Failed to delete category: \(error)")
            throw error
        }
    }
    
    // MARK: - Utility
    
    /// Returns the count of transactions using a specific category.
    ///
    /// Useful for showing warnings in the UI before deleting a category.
    ///
    /// - Parameter category: The category to check.
    /// - Returns: The number of transactions using this category.
    func transactionCount(for category: Category) -> Int {
        let categoryID = category.id
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.category?.id == categoryID
            }
        )
        
        do {
            let transactions = try modelContext.fetch(fetchDescriptor)
            return transactions.count
        } catch {
            print("Failed to count transactions for category: \(error)")
            return 0
        }
    }
    
    /// Returns all categories of a specific type.
    ///
    /// - Parameter type: The category type to filter by.
    /// - Returns: Array of categories matching the type, sorted alphabetically.
    func categories(ofType type: CategoryType) -> [Category] {
        switch type {
        case .expense:
            return expenseCategories
        case .income:
            return incomeCategories
        }
    }
}

// MARK: - Errors

/// Errors that can occur during category operations.
enum CategoryViewModelError: LocalizedError {
    case cannotModifyPredefinedCategory
    
    var errorDescription: String? {
        switch self {
        case .cannotModifyPredefinedCategory:
            return "Predefined categories cannot be modified or deleted. Only custom categories can be edited."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cannotModifyPredefinedCategory:
            return "Create a new custom category instead."
        }
    }
}
