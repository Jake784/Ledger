//
//  StatusBadge.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// A small pill-shaped badge for displaying status information.
///
/// Used throughout the app to show transaction states, goal statuses,
/// and other categorical information with semantic color coding.
///
/// **Usage:**
/// ```swift
/// StatusBadge(text: "Pendiente", color: .orange)
/// StatusBadge(text: "Completado", color: .green)
/// StatusBadge(text: "Vencido", color: .red)
/// ```
///
/// **Where Used:**
/// - Transaction status (pending, completed)
/// - Goal status (active, overdue, achieved)
/// - Budget alerts (at risk, over budget)
/// - Projection accuracy indicators
struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String?
    
    init(text: String, color: Color, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

/// Predefined status badge variants for common use cases.
extension StatusBadge {
    /// Pending transaction status badge.
    static func pending() -> StatusBadge {
        StatusBadge(text: "Pendiente", color: .orange, icon: "clock")
    }
    
    /// Completed transaction status badge.
    static func completed() -> StatusBadge {
        StatusBadge(text: "Completado", color: .green, icon: "checkmark.circle")
    }
    
    /// Overdue status badge.
    static func overdue() -> StatusBadge {
        StatusBadge(text: "Vencido", color: .red, icon: "exclamationmark.triangle")
    }
    
    /// Active status badge.
    static func active() -> StatusBadge {
        StatusBadge(text: "Activo", color: .blue, icon: "circle.fill")
    }
    
    /// Over budget warning badge.
    static func overBudget() -> StatusBadge {
        StatusBadge(text: "Excedido", color: .red, icon: "exclamationmark.circle")
    }
    
    /// At risk warning badge.
    static func atRisk() -> StatusBadge {
        StatusBadge(text: "Riesgo", color: .orange, icon: "exclamationmark.triangle")
    }
    
    /// Achieved goal badge.
    static func achieved() -> StatusBadge {
        StatusBadge(text: "Logrado", color: .green, icon: "checkmark.seal")
    }
}

// MARK: - Previews

#Preview("Status Badges") {
    VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction States")
                .font(.headline)
            
            HStack(spacing: 8) {
                StatusBadge.pending()
                StatusBadge.completed()
                StatusBadge.overdue()
            }
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget & Goal States")
                .font(.headline)
            
            HStack(spacing: 8) {
                StatusBadge.active()
                StatusBadge.atRisk()
                StatusBadge.overBudget()
                StatusBadge.achieved()
            }
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Badges")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                StatusBadge(text: "Fijo", color: .blue)
                StatusBadge(text: "Variable", color: .purple)
                StatusBadge(text: "Recurrente", color: .indigo, icon: "arrow.clockwise")
                StatusBadge(text: "Alta Precisión", color: .green, icon: "scope")
            }
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("In Context")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Renta Mensual")
                        .font(.headline)
                    Text("Q 5,000.00")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                StatusBadge.pending()
            }
            .cardStyle()
        }
    }
    .padding()
    .frame(width: 450)
}
