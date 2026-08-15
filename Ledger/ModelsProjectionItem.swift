//
//  ProjectionItem.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a single line item within a financial projection.
@Model
final class ProjectionItem {
    var id: UUID
    var concept: String
    var itemType: ProjectionItemType
    var estimatedMonthly: Decimal
    var appliedMonths: [Int]
    
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    init(
        id: UUID = UUID(),
        concept: String,
        category: Category? = nil,
        itemType: ProjectionItemType,
        estimatedMonthly: Decimal,
        appliedMonths: [Int] = []
    ) {
        self.id = id
        self.concept = concept
        self.category = category
        self.itemType = itemType
        self.estimatedMonthly = estimatedMonthly
        self.appliedMonths = appliedMonths
    }
}
