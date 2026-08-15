//
//  UserProfile.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Represents the user's profile information and preferences.
@Model
final class UserProfile {
    var id: UUID
    var name: String
    var avatarSystemImage: String
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify)
    var preferredCurrency: Currency?
    
    init(
        id: UUID = UUID(),
        name: String,
        avatarSystemImage: String,
        preferredCurrency: Currency? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.avatarSystemImage = avatarSystemImage
        self.preferredCurrency = preferredCurrency
        self.createdAt = createdAt
    }
}
