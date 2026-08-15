//
//  BiometricAuthService.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import LocalAuthentication

/// Custom error types for biometric authentication failures.
enum BiometricAuthError: LocalizedError {
    case biometricsNotAvailable
    case biometricsNotEnrolled
    case userCancelled
    case authenticationFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometricsNotEnrolled:
            return "No biometrics are enrolled. Please set up Face ID or Touch ID in System Preferences."
        case .userCancelled:
            return "Authentication was cancelled."
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

/// Service that wraps Apple's LocalAuthentication framework for biometric and passcode authentication.
///
/// This service protects sensitive actions like capital adjustments and account deletion.
/// It attempts biometric authentication first (Face ID/Touch ID), and gracefully falls back
/// to device passcode if biometrics are unavailable or not enrolled.
///
/// **Usage Example:**
/// ```swift
/// // In a ViewModel
/// let authService = BiometricAuthService()
///
/// func performCapitalAdjustment() {
///     Task {
///         do {
///             let success = try await authService.authenticate(
///                 reason: "Confirm to adjust your capital"
///             )
///             if success {
///                 // Proceed with capital adjustment
///                 createCapitalAdjustmentTransaction()
///             }
///         } catch let error as BiometricAuthError {
///             // Handle specific authentication errors
///             self.errorMessage = error.localizedDescription
///         } catch {
///             // Handle unexpected errors
///             self.errorMessage = "Authentication error: \(error.localizedDescription)"
///         }
///     }
/// }
/// ```
final class BiometricAuthService {
    
    // MARK: - Properties
    
    private let context: LAContext
    
    // MARK: - Initialization
    
    /// Initializes a new BiometricAuthService.
    /// - Parameter context: Optional LAContext for testing purposes. Defaults to a new LAContext.
    init(context: LAContext = LAContext()) {
        self.context = context
    }
    
    // MARK: - Authentication
    
    /// Authenticates the user using biometrics or device passcode.
    ///
    /// This method attempts biometric authentication first (Face ID or Touch ID).
    /// If biometrics are not available or not enrolled, it automatically falls back
    /// to the device passcode using `.deviceOwnerAuthentication` policy.
    ///
    /// - Parameter reason: A localized string explaining why authentication is needed.
    ///                     This appears in the authentication dialog.
    /// - Returns: `true` if authentication succeeded, `false` otherwise.
    /// - Throws: `BiometricAuthError` with specific failure reasons.
    func authenticate(reason: String) async throws -> Bool {
        var error: NSError?
        
        // First, check if biometric authentication is available
        let biometricsAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        
        // Determine which policy to use based on biometric availability
        let policy: LAPolicy
        
        if biometricsAvailable {
            // Use biometrics if available
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else {
            // Fall back to passcode authentication
            // Check if passcode authentication is available
            var passcodeError: NSError?
            let passcodeAvailable = context.canEvaluatePolicy(
                .deviceOwnerAuthentication,
                error: &passcodeError
            )
            
            guard passcodeAvailable else {
                // No authentication method available
                throw BiometricAuthError.biometricsNotAvailable
            }
            
            policy = .deviceOwnerAuthentication
        }
        
        // Perform the authentication
        do {
            let success = try await context.evaluatePolicy(
                policy,
                localizedReason: reason
            )
            return success
        } catch let laError as LAError {
            // Map LAError to our custom BiometricAuthError
            throw mapLAError(laError)
        } catch {
            throw BiometricAuthError.unknown(error)
        }
    }
    
    // MARK: - Biometric Availability
    
    /// Checks what type of biometric authentication is available on the device.
    /// - Returns: A tuple with availability status and biometric type description.
    func biometricType() -> (available: Bool, type: String) {
        var error: NSError?
        let available = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        
        guard available else {
            return (false, "None")
        }
        
        switch context.biometryType {
        case .faceID:
            return (true, "Face ID")
        case .touchID:
            return (true, "Touch ID")
        case .opticID:
            return (true, "Optic ID")
        case .none:
            return (false, "None")
        @unknown default:
            return (false, "Unknown")
        }
    }
    
    // MARK: - Error Mapping
    
    /// Maps LAError codes to custom BiometricAuthError cases.
    private func mapLAError(_ error: LAError) -> BiometricAuthError {
        switch error.code {
        case .biometryNotAvailable:
            return .biometricsNotAvailable
        case .biometryNotEnrolled:
            return .biometricsNotEnrolled
        case .userCancel, .appCancel, .systemCancel:
            return .userCancelled
        case .authenticationFailed:
            return .authenticationFailed
        case .userFallback:
            // User chose to use passcode instead of biometrics
            return .userCancelled
        case .passcodeNotSet:
            return .biometricsNotAvailable
        default:
            return .authenticationFailed
        }
    }
}
