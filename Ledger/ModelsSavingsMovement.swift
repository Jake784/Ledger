//
//  SavingsMovement.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a deposit or withdrawal from a savings fund.
@Model
final class SavingsMovement {
    var id: UUID
    var type: SavingsMovementType
    var amount: Decimal
    var date: Date
    var note: String?
    
    init(
        id: UUID = UUID(),
        type: SavingsMovementType,
        amount: Decimal,
        date: Date,
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.date = date
        self.note = note
    }
}
