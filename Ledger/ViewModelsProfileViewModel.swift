//
//  ProfileViewModel.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData
import Observation

/// ViewModel that manages the user's profile information.
///
/// **Single-User App Design:**
/// FinVault is designed for single-user use. There should only ever be ONE UserProfile
/// record in the database. This ViewModel ensures that constraint is maintained.
///
/// **Onboarding Flow:**
/// During first launch, the app should:
/// 1. Check if a profile exists via `loadProfile()`
/// 2. If `userProfile == nil`, show onboarding
/// 3. Call `createInitialProfile()` to create the first (and only) profile
/// 4. From then on, only `updateProfile()` is used to modify it
///
/// **Usage:**
/// ```swift
/// struct ProfileView: View {
///     @State private var viewModel: ProfileViewModel
///
///     var body: some View {
///         if let profile = viewModel.userProfile {
///             Form {
///                 TextField("Name", text: $name)
///                 // Avatar picker
///                 // Currency picker
///             }
///         }
///         .onAppear {
///             viewModel.loadProfile()
///         }
///     }
/// }
/// ```
@Observable
final class ProfileViewModel {
    
    // MARK: - Properties
    
    /// The single user profile for this app instance.
    private(set) var userProfile: UserProfile?
    
    /// SwiftData context for persistence operations.
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initializes the ProfileViewModel with a SwiftData context.
    /// - Parameter modelContext: The ModelContext to use for data operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Data Loading
    
    /// Loads the user profile from SwiftData.
    ///
    /// Since this is a single-user app, there should only be one UserProfile record.
    /// If multiple exist (data corruption), this will load the first one.
    func loadProfile() {
        let fetchDescriptor = FetchDescriptor<UserProfile>()
        
        do {
            let profiles = try modelContext.fetch(fetchDescriptor)
            userProfile = profiles.first
            
            // Warn if multiple profiles exist (shouldn't happen)
            if profiles.count > 1 {
                print("Warning: Multiple UserProfile records found. Expected only 1. Using first.")
            }
            
        } catch {
            print("Failed to load user profile: \(error)")
            userProfile = nil
        }
    }
    
    // MARK: - Create
    
    /// Creates the initial user profile during onboarding.
    ///
    /// **Important:** This should only be called ONCE during first app launch.
    /// The app should check `userProfile == nil` before showing onboarding.
    ///
    /// - Parameters:
    ///   - name: The user's name.
    ///   - avatarSystemImage: SF Symbol name for the avatar.
    ///   - preferredCurrency: The user's preferred currency.
    /// - Throws: An error if the save operation fails.
    func createInitialProfile(
        name: String,
        avatarSystemImage: String,
        preferredCurrency: Currency
    ) throws {
        // Safety check: prevent creating multiple profiles
        if userProfile != nil {
            print("Warning: Attempting to create profile when one already exists. Updating instead.")
            try updateProfile(name: name, avatarSystemImage: avatarSystemImage)
            
            // Update currency separately since updateProfile doesn't handle it
            userProfile?.preferredCurrency = preferredCurrency
            try modelContext.save()
            return
        }
        
        let profile = UserProfile(
            name: name,
            avatarSystemImage: avatarSystemImage,
            preferredCurrency: preferredCurrency,
            createdAt: Date()
        )
        
        modelContext.insert(profile)
        
        do {
            try modelContext.save()
            userProfile = profile
        } catch {
            print("Failed to create initial profile: \(error)")
            throw error
        }
    }
    
    // MARK: - Update
    
    /// Updates the user's profile information.
    ///
    /// - Parameters:
    ///   - name: The new name.
    ///   - avatarSystemImage: The new avatar SF Symbol name.
    /// - Throws: An error if the save operation fails.
    func updateProfile(name: String, avatarSystemImage: String) throws {
        guard let profile = userProfile else {
            print("Cannot update profile: no profile exists")
            throw ProfileViewModelError.noProfileExists
        }
        
        profile.name = name
        profile.avatarSystemImage = avatarSystemImage
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update profile: \(error)")
            throw error
        }
    }
    
    /// Updates the user's preferred currency.
    ///
    /// - Parameter currency: The new preferred currency.
    /// - Throws: An error if the save operation fails.
    func updatePreferredCurrency(_ currency: Currency) throws {
        guard let profile = userProfile else {
            print("Cannot update currency: no profile exists")
            throw ProfileViewModelError.noProfileExists
        }
        
        profile.preferredCurrency = currency
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update preferred currency: \(error)")
            throw error
        }
    }
    
    // MARK: - Utility
    
    /// Returns whether a profile exists.
    var hasProfile: Bool {
        userProfile != nil
    }
    
    /// Returns whether onboarding is needed.
    var needsOnboarding: Bool {
        userProfile == nil
    }
}

// MARK: - Errors

/// Errors that can occur during profile operations.
enum ProfileViewModelError: LocalizedError {
    case noProfileExists
    
    var errorDescription: String? {
        switch self {
        case .noProfileExists:
            return "No user profile exists. Please complete onboarding first."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noProfileExists:
            return "Create a profile through the onboarding flow."
        }
    }
}
