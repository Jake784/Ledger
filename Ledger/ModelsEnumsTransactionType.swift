//
//  TransactionType.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation

/// Defines the type of a financial transaction.
enum TransactionType: String, Codable {
    case income = "income"
    case expense = "expense"
    case capitalAdjustment = "capitalAdjustment"
}
