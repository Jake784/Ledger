//
//  Currency.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a currency used throughout the application.
@Model
final class Currency {
    var code: String
    var symbol: String
    var isDefault: Bool
    
    init(
        code: String,
        symbol: String,
        isDefault: Bool = false
    ) {
        self.code = code
        self.symbol = symbol
        self.isDefault = isDefault
    }
}
