//
//  CategoryType.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation

/// Defines whether a category is used for income or expense transactions.
enum CategoryType: String, Codable {
    case income = "income"
    case expense = "expense"
}
