//
//  Projection.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents a financial projection for a specific year with line items.
@Model
final class Projection {
    var id: UUID
    var name: String
    var year: Int
    var startingCapitalMode: CapitalMode
    var simulatedStartingCapital: Decimal?
    
    @Relationship(deleteRule: .cascade)
    var items: [ProjectionItem]
    
    init(
        id: UUID = UUID(),
        name: String,
        year: Int,
        startingCapitalMode: CapitalMode,
        simulatedStartingCapital: Decimal? = nil,
        items: [ProjectionItem] = []
    ) {
        self.id = id
        self.name = name
        self.year = year
        self.startingCapitalMode = startingCapitalMode
        self.simulatedStartingCapital = simulatedStartingCapital
        self.items = items
    }
}
