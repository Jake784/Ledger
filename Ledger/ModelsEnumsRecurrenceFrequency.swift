//
//  RecurrenceFrequency.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation

/// Defines the frequency at which a recurring transaction repeats.
enum RecurrenceFrequency: String, Codable {
    case monthly = "monthly"
    case weekly = "weekly"
}
