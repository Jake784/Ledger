//
//  Goal.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a financial goal with a target amount and date.
@Model
final class Goal {
    var id: UUID
    var name: String
    var targetAmount: Decimal
    var targetDate: Date
    
    @Relationship(deleteRule: .cascade)
    var linkedSavingsFund: SavingsFund?
    
    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        targetDate: Date,
        linkedSavingsFund: SavingsFund? = nil
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.linkedSavingsFund = linkedSavingsFund
    }
}
