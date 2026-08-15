//
//  NotificationService.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import UserNotifications

/// Service that manages local notifications for pending transactions and goal deadlines.
///
/// This service wraps Apple's UserNotifications framework to schedule reminders for:
/// - Pending fixed transactions on their due date
/// - Goal deadlines approaching (configurable days before target date)
///
/// **Authorization:**
/// Call `requestAuthorization()` once during onboarding or app launch before scheduling notifications.
///
/// **Usage Example:**
/// ```swift
/// // In FinVaultApp.init() or OnboardingViewModel:
/// let notificationService = NotificationService()
/// Task {
///     do {
///         let granted = try await notificationService.requestAuthorization()
///         if granted {
///             print("Notification permission granted")
///         }
///     } catch {
///         print("Failed to request notification permission: \(error)")
///     }
/// }
/// ```
///
/// **Dependencies:**
/// Assumes Transaction and Goal models are available in the same target.
final class NotificationService {
    
    // MARK: - Properties
    
    private let notificationCenter: UNUserNotificationCenter
    
    // MARK: - Initialization
    
    /// Initializes a new NotificationService.
    /// - Parameter notificationCenter: The UNUserNotificationCenter to use. Defaults to .current() for production.
    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }
    
    // MARK: - Authorization
    
    /// Requests notification permission from the user.
    ///
    /// This should be called once during onboarding or first app launch.
    /// Subsequent calls will return the current authorization status without re-prompting.
    ///
    /// - Returns: `true` if permission is granted, `false` otherwise.
    /// - Throws: An error if the authorization request fails.
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await notificationCenter.requestAuthorization(options: options)
        return granted
    }
    
    /// Checks the current notification authorization status.
    /// - Returns: `true` if notifications are authorized, `false` otherwise.
    func isAuthorized() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Transaction Reminders
    
    /// Schedules a local notification for a pending transaction on its due date.
    ///
    /// The notification is scheduled at 9:00 AM on the transaction's date.
    /// Uses the transaction's UUID as the notification identifier for later cancellation.
    ///
    /// - Parameter transaction: The transaction to schedule a reminder for.
    /// - Throws: An error if the notification scheduling fails.
    func scheduleReminder(for transaction: Transaction) throws {
        Task {
            // Check authorization before scheduling
            guard await isAuthorized() else {
                print("Notification authorization not granted. Skipping reminder for transaction \(transaction.id)")
                return
            }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Pending Transaction Due"
            
            // Format the amount with currency symbol if available
            let amountString = formatAmount(transaction.amount, currency: transaction.currency)
            content.body = "\(transaction.descriptionText) - \(amountString)"
            
            content.sound = .default
            content.categoryIdentifier = "PENDING_TRANSACTION"
            
            // Schedule for 9:00 AM on the transaction's date
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: transaction.date)
            dateComponents.hour = 9
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Use transaction ID as identifier
            let identifier = transaction.id.uuidString
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            do {
                try await notificationCenter.add(request)
                print("Scheduled reminder for transaction \(transaction.id) on \(transaction.date)")
            } catch {
                print("Failed to schedule reminder for transaction \(transaction.id): \(error)")
                throw error
            }
        }
    }
    
    /// Cancels a previously scheduled notification for a transaction.
    ///
    /// - Parameter transaction: The transaction whose reminder should be cancelled.
    func cancelReminder(for transaction: Transaction) {
        let identifier = transaction.id.uuidString
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled reminder for transaction \(transaction.id)")
    }
    
    // MARK: - Goal Reminders
    
    /// Schedules a local notification for a goal deadline approaching.
    ///
    /// The notification is scheduled at 9:00 AM, a specified number of days before the goal's target date.
    ///
    /// - Parameters:
    ///   - goal: The goal to schedule a reminder for.
    ///   - daysBefore: Number of days before the target date to send the reminder (e.g., 7 for one week before).
    /// - Throws: An error if the notification scheduling fails.
    func scheduleGoalReminder(for goal: Goal, daysBefore: Int = 7) throws {
        Task {
            // Check authorization before scheduling
            guard await isAuthorized() else {
                print("Notification authorization not granted. Skipping reminder for goal \(goal.id)")
                return
            }
            
            // Calculate the reminder date
            let calendar = Calendar.current
            guard let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: goal.targetDate) else {
                print("Failed to calculate reminder date for goal \(goal.id)")
                return
            }
            
            // Don't schedule if reminder date is in the past
            guard reminderDate > Date() else {
                print("Reminder date is in the past for goal \(goal.id). Skipping.")
                return
            }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Goal Deadline Approaching"
            
            let amountString = formatAmount(goal.targetAmount, currency: nil)
            let daysText = daysBefore == 1 ? "1 day" : "\(daysBefore) days"
            content.body = "\(goal.name) - \(amountString) target in \(daysText)"
            
            content.sound = .default
            content.categoryIdentifier = "GOAL_DEADLINE"
            
            // Schedule for 9:00 AM on the reminder date
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            dateComponents.hour = 9
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Use goal ID with prefix as identifier
            let identifier = "goal-\(goal.id.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            do {
                try await notificationCenter.add(request)
                print("Scheduled reminder for goal \(goal.id) on \(reminderDate)")
            } catch {
                print("Failed to schedule reminder for goal \(goal.id): \(error)")
                throw error
            }
        }
    }
    
    /// Cancels a previously scheduled notification for a goal.
    ///
    /// - Parameter goal: The goal whose reminder should be cancelled.
    func cancelGoalReminder(for goal: Goal) {
        let identifier = "goal-\(goal.id.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled reminder for goal \(goal.id)")
    }
    
    // MARK: - Batch Operations
    
    /// Cancels all pending notifications.
    func cancelAllReminders() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("Cancelled all pending reminders")
    }
    
    /// Returns the count of pending notification requests.
    /// - Returns: The number of scheduled notifications.
    func getPendingNotificationCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }
    
    // MARK: - Helpers
    
    /// Formats a Decimal amount with optional currency symbol.
    private func formatAmount(_ amount: Decimal, currency: Currency?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        
        if let currency = currency {
            return "\(currency.symbol)\(amountString)"
        } else {
            return amountString
        }
    }
}
