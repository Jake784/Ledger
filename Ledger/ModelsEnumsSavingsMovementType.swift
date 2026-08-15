//
//  SavingsMovementType.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation

/// Defines whether a savings movement is a deposit or withdrawal.
enum SavingsMovementType: String, Codable {
    case deposit = "deposit"
    case withdrawal = "withdrawal"
}
