//
//  Category.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a transaction category for organizing income and expenses.
@Model
final class Category {
    var id: UUID
    var name: String
    var type: CategoryType
    var icon: String
    var color: String
    var isCustom: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        type: CategoryType,
        icon: String,
        color: String,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.color = color
        self.isCustom = isCustom
    }
}
