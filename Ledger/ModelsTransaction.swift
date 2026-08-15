//
//  Transaction.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a financial transaction (income, expense, or capital adjustment).
@Model
final class Transaction {
    var id: UUID
    var type: TransactionType
    var unitPrice: Decimal
    var quantity: Int
    var amount: Decimal
    var descriptionText: String
    var date: Date
    var isPending: Bool
    var note: String?
    
    @Relationship(deleteRule: .nullify)
    var currency: Currency?
    
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    @Relationship(deleteRule: .cascade)
    var recurrenceRule: RecurrenceRule?
    
    init(
        id: UUID = UUID(),
        type: TransactionType,
        unitPrice: Decimal,
        quantity: Int = 1,
        amount: Decimal,
        currency: Currency? = nil,
        descriptionText: String,
        category: Category? = nil,
        date: Date,
        isPending: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.amount = amount
        self.currency = currency
        self.descriptionText = descriptionText
        self.category = category
        self.date = date
        self.isPending = isPending
        self.recurrenceRule = recurrenceRule
        self.note = note
    }
}
