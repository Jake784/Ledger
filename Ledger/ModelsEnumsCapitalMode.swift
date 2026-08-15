//
//  CapitalMode.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation

/// Defines whether a projection uses actual or simulated starting capital.
enum CapitalMode: String, Codable {
    case actualCapital = "actualCapital"
    case simulatedCapital = "simulatedCapital"
}
