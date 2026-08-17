//
//  CurrencySeeder.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Service responsible for seeding the default currency into SwiftData on first launch.
/// This seeder is idempotent: it only inserts a currency if none exist, preventing duplicates on subsequent launches.
final class CurrencySeeder {

    // MARK: - Seeding

    /// Seeds the default currency into the provided ModelContext if no currency exists.
    /// - Parameter context: The SwiftData ModelContext to query and insert into.
    static func seedIfNeeded(context: ModelContext) {
        // Check if any currency already exists
        let fetchDescriptor = FetchDescriptor<Currency>()

        do {
            let existingCurrencies = try context.fetch(fetchDescriptor)

            guard existingCurrencies.isEmpty else {
                // A currency already exists, skip seeding
                return
            }

            let defaultCurrency = Currency(code: "GTQ", symbol: "Q", isDefault: true)
            context.insert(defaultCurrency)

            try context.save()

        } catch {
            print("Error seeding default currency: \(error)")
        }
    }
}
