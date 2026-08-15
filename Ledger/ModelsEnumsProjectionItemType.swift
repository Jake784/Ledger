//
//  ProjectionItemType.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation

/// Defines the type of income or expense in a projection.
enum ProjectionItemType: String, Codable {
    case fixedExpense = "fixedExpense"
    case variableExpense = "variableExpense"
    case fixedIncome = "fixedIncome"
    case variableIncome = "variableIncome"
}
