//
//  SavingsFund.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a savings fund with deposits and withdrawals.
@Model
final class SavingsFund {
    var id: UUID
    var name: String
    
    @Relationship(deleteRule: .cascade)
    var movements: [SavingsMovement]
    
    @Relationship(deleteRule: .nullify)
    var linkedGoal: Goal?
    
    /// Computed property that returns the current balance by summing all movements.
    var currentAmount: Decimal {
        movements.reduce(Decimal(0)) { total, movement in
            switch movement.type {
            case .deposit:
                return total + movement.amount
            case .withdrawal:
                return total - movement.amount
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        movements: [SavingsMovement] = [],
        linkedGoal: Goal? = nil
    ) {
        self.id = id
        self.name = name
        self.movements = movements
        self.linkedGoal = linkedGoal
    }
}
