//
//  BudgetCategoryLimit.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a spending limit for a specific category within a budget.
@Model
final class BudgetCategoryLimit {
    var id: UUID
    var limitAmount: Decimal
    
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    init(
        id: UUID = UUID(),
        category: Category? = nil,
        limitAmount: Decimal
    ) {
        self.id = id
        self.category = category
        self.limitAmount = limitAmount
    }
}
