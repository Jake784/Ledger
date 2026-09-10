//
//  PrimaryButtonStyle.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// Primary button style for main call-to-action buttons.
///
/// Uses the app's accent color with a subtle press animation.
/// Appropriate for primary actions like "Save", "Create", "Confirm".
///
/// **Usage:**
/// ```swift
/// Button("Save Transaction") {
///     // Action
/// }
/// .buttonStyle(PrimaryButtonStyle())
/// ```
///
/// **Where Used:**
/// - Form submission buttons
/// - Create new item actions
/// - Confirmation dialogs
/// - Onboarding flow
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? Color.accentColor : Color.gray)
            )
            // The `.frame(maxWidth: .infinity)` above only expands the
            // *layout* size — without this, taps on the filled background
            // outside the label's own tight glyph bounds (e.g. the padding
            // around a short title) don't register. Every custom button
            // style in this file needs its own copy of this fix.
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button style for less prominent actions.
///
/// Uses a bordered style with the accent color for the border.
/// Appropriate for cancel, dismiss, or alternative actions.
///
/// **Usage:**
/// ```swift
/// Button("Cancel") {
///     // Action
/// }
/// .buttonStyle(SecondaryButtonStyle())
/// ```
///
/// **Where Used:**
/// - Cancel buttons
/// - Alternative actions
/// - Toolbar items
/// - Navigation actions
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.accentColor : Color.gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isEnabled ? Color.accentColor : Color.gray, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Destructive button style for dangerous actions.
///
/// Uses red color to signal caution for actions like delete or reset.
///
/// **Usage:**
/// ```swift
/// Button("Delete Account") {
///     // Action
/// }
/// .buttonStyle(DestructiveButtonStyle())
/// ```
///
/// **Where Used:**
/// - Delete confirmations
/// - Account deletion
/// - Data clearing actions
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? Color.red : Color.gray)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Compact button style for inline actions.
///
/// Smaller padding for use in tight spaces like list rows or toolbars.
///
/// **Usage:**
/// ```swift
/// Button("Edit") {
///     // Action
/// }
/// .buttonStyle(CompactButtonStyle())
/// ```
struct CompactButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = .accentColor) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Button Styles") {
    VStack(spacing: 32) {
        // Primary Buttons
        VStack(alignment: .leading, spacing: 16) {
            Text("Primary Actions")
                .font(.headline)

            Button("Guardar Transacción") {
                print("Save tapped")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Crear Presupuesto") {
                print("Create tapped")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Disabled State") {
                print("Won't execute")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(true)
        }

        Divider()

        // Secondary Buttons
        VStack(alignment: .leading, spacing: 16) {
            Text("Secondary Actions")
                .font(.headline)

            Button("Cancelar") {
                print("Cancel tapped")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Ver Detalles") {
                print("Details tapped")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Disabled State") {
                print("Won't execute")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(true)
        }

        Divider()

        // Destructive Buttons
        VStack(alignment: .leading, spacing: 16) {
            Text("Destructive Actions")
                .font(.headline)

            Button("Eliminar Transacción") {
                print("Delete tapped")
            }
            .buttonStyle(DestructiveButtonStyle())

            Button("Borrar Todos los Datos") {
                print("Clear all tapped")
            }
            .buttonStyle(DestructiveButtonStyle())
        }

        Divider()

        // Compact Buttons
        VStack(alignment: .leading, spacing: 16) {
            Text("Compact Buttons")
                .font(.headline)

            HStack {
                Button("Editar") {
                    print("Edit tapped")
                }
                .buttonStyle(CompactButtonStyle())

                Button("Completar") {
                    print("Complete tapped")
                }
                .buttonStyle(CompactButtonStyle(color: .green))

                Button("Eliminar") {
                    print("Delete tapped")
                }
                .buttonStyle(CompactButtonStyle(color: .red))
            }
        }

        Divider()

        // Form Example
        VStack(alignment: .leading, spacing: 16) {
            Text("Form Button Group")
                .font(.headline)

            Card {
                VStack(spacing: 16) {
                    Text("¿Crear nueva meta de ahorro?")
                        .font(.headline)

                    Text("Esto creará una nueva meta vinculada a un fondo de ahorros.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Cancelar") {
                            print("Cancel")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button("Crear Meta") {
                            print("Create")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
    }
    .padding()
    .frame(width: 400)
}
