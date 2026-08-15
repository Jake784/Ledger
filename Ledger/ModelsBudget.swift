//
//  Budget.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a monthly budget with category-specific spending limits.
@Model
final class Budget {
    var id: UUID
    var month: Int
    var year: Int
    
    @Relationship(deleteRule: .cascade)
    var categoryLimits: [BudgetCategoryLimit]
    
    init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        categoryLimits: [BudgetCategoryLimit] = []
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.categoryLimits = categoryLimits
    }
}
