//
//  CategorySeeder.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import SwiftData

/// Service responsible for seeding predefined categories into SwiftData on first launch.
/// This seeder is idempotent: it only inserts categories if none exist, preventing duplicates on subsequent launches.
final class CategorySeeder {
    
    // MARK: - Color Palette
    
    /// A curated palette of hex color strings for category differentiation.
    private enum ColorPalette {
        static let red = "#FF3B30"
        static let orange = "#FF9500"
        static let yellow = "#FFCC00"
        static let green = "#34C759"
        static let teal = "#5AC8FA"
        static let blue = "#007AFF"
        static let indigo = "#5856D6"
        static let purple = "#AF52DE"
        static let pink = "#FF2D55"
        static let brown = "#A2845E"
        static let gray = "#8E8E93"
        static let mint = "#00C7BE"
        static let cyan = "#32ADE6"
        static let lime = "#BFD200"
        static let coral = "#FF6B6B"
    }
    
    // MARK: - Seeding
    
    /// Seeds predefined categories into the provided ModelContext if no categories exist.
    /// - Parameter context: The SwiftData ModelContext to query and insert into.
    static func seedIfNeeded(context: ModelContext) {
        // Check if any categories already exist
        let fetchDescriptor = FetchDescriptor<Category>()
        
        do {
            let existingCategories = try context.fetch(fetchDescriptor)
            
            guard existingCategories.isEmpty else {
                // Categories already exist, skip seeding
                return
            }
            
            // Insert predefined expense categories
            let expenseCategories = createExpenseCategories()
            for category in expenseCategories {
                context.insert(category)
            }
            
            // Insert predefined income categories
            let incomeCategories = createIncomeCategories()
            for category in incomeCategories {
                context.insert(category)
            }
            
            // Save the context
            try context.save()
            
        } catch {
            print("Error seeding categories: \(error)")
        }
    }
    
    // MARK: - Category Creation
    
    /// Creates the predefined expense categories.
    private static func createExpenseCategories() -> [Category] {
        return [
            Category(
                name: "Vivienda",
                type: .expense,
                icon: "house.fill",
                color: ColorPalette.blue,
                isCustom: false
            ),
            Category(
                name: "Educación",
                type: .expense,
                icon: "graduationcap.fill",
                color: ColorPalette.indigo,
                isCustom: false
            ),
            Category(
                name: "Transporte",
                type: .expense,
                icon: "car.fill",
                color: ColorPalette.orange,
                isCustom: false
            ),
            Category(
                name: "Salud",
                type: .expense,
                icon: "cross.case.fill",
                color: ColorPalette.red,
                isCustom: false
            ),
            Category(
                name: "Entretenimiento",
                type: .expense,
                icon: "gamecontroller.fill",
                color: ColorPalette.purple,
                isCustom: false
            ),
            Category(
                name: "Servicios",
                type: .expense,
                icon: "bolt.fill",
                color: ColorPalette.yellow,
                isCustom: false
            ),
            Category(
                name: "Alimentación",
                type: .expense,
                icon: "fork.knife",
                color: ColorPalette.green,
                isCustom: false
            ),
            Category(
                name: "Ropa",
                type: .expense,
                icon: "tshirt.fill",
                color: ColorPalette.pink,
                isCustom: false
            ),
            Category(
                name: "Mascotas",
                type: .expense,
                icon: "pawprint.fill",
                color: ColorPalette.brown,
                isCustom: false
            ),
            Category(
                name: "Suscripciones",
                type: .expense,
                icon: "repeat.circle.fill",
                color: ColorPalette.teal,
                isCustom: false
            ),
            Category(
                name: "Deudas/Préstamos",
                type: .expense,
                icon: "creditcard.fill",
                color: ColorPalette.coral,
                isCustom: false
            ),
            Category(
                name: "Regalos/Donaciones",
                type: .expense,
                icon: "gift.fill",
                color: ColorPalette.mint,
                isCustom: false
            ),
            Category(
                name: "Viajes",
                type: .expense,
                icon: "airplane",
                color: ColorPalette.cyan,
                isCustom: false
            ),
            Category(
                name: "Impuestos",
                type: .expense,
                icon: "building.columns.fill",
                color: ColorPalette.gray,
                isCustom: false
            ),
            Category(
                name: "Otros",
                type: .expense,
                icon: "ellipsis.circle.fill",
                color: ColorPalette.gray,
                isCustom: false
            )
        ]
    }
    
    /// Creates the predefined income categories.
    private static func createIncomeCategories() -> [Category] {
        return [
            Category(
                name: "Salario",
                type: .income,
                icon: "banknote.fill",
                color: ColorPalette.green,
                isCustom: false
            ),
            Category(
                name: "Freelance",
                type: .income,
                icon: "laptopcomputer",
                color: ColorPalette.blue,
                isCustom: false
            ),
            Category(
                name: "Trabajo extra",
                type: .income,
                icon: "briefcase.fill",
                color: ColorPalette.indigo,
                isCustom: false
            ),
            Category(
                name: "Inversiones",
                type: .income,
                icon: "chart.line.uptrend.xyaxis",
                color: ColorPalette.teal,
                isCustom: false
            ),
            Category(
                name: "Bonos/Comisiones",
                type: .income,
                icon: "star.fill",
                color: ColorPalette.yellow,
                isCustom: false
            ),
            Category(
                name: "Reembolsos",
                type: .income,
                icon: "arrow.uturn.left.circle.fill",
                color: ColorPalette.orange,
                isCustom: false
            ),
            Category(
                name: "Venta de activos",
                type: .income,
                icon: "tag.fill",
                color: ColorPalette.purple,
                isCustom: false
            ),
            Category(
                name: "Ingreso pasivo",
                type: .income,
                icon: "infinity",
                color: ColorPalette.mint,
                isCustom: false
            ),
            Category(
                name: "Otros",
                type: .income,
                icon: "ellipsis.circle.fill",
                color: ColorPalette.gray,
                isCustom: false
            )
        ]
    }
}
