//
//  RecurrenceRule.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Defines the recurrence pattern for repeating transactions.
@Model
final class RecurrenceRule {
    var frequency: RecurrenceFrequency
    var dayOfMonth: Int?
    var startDate: Date
    var endDate: Date?
    
    init(
        frequency: RecurrenceFrequency,
        dayOfMonth: Int? = nil,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.frequency = frequency
        self.dayOfMonth = dayOfMonth
        self.startDate = startDate
        self.endDate = endDate
    }
}
