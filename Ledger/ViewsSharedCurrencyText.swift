//
//  CurrencyText.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// A text view that formats and displays monetary amounts with currency symbols.
///
/// Provides consistent currency formatting throughout the app with support
/// for different sizes and weights for various use cases.
///
/// **Usage:**
/// ```swift
/// CurrencyText(
///     amount: 1875.50,
///     currency: gtqCurrency,
///     size: .large
/// )
/// ```
///
/// **Where Used:**
/// - Dashboard capital display
/// - Transaction amounts
/// - Budget totals
/// - Goal targets
/// - Savings fund balances
struct CurrencyText: View {
    let amount: Decimal
    let currency: Currency
    let size: SizeVariant
    let weight: Font.Weight
    let color: Color?
    
    enum SizeVariant {
        case large      // Dashboard headers, key metrics
        case medium     // Section totals
        case regular    // List items
        case small      // Metadata, secondary info
        
        var font: Font {
            switch self {
            case .large: return .title.weight(.bold)
            case .medium: return .title3.weight(.semibold)
            case .regular: return .body
            case .small: return .caption
            }
        }
    }
    
    init(
        amount: Decimal,
        currency: Currency,
        size: SizeVariant = .regular,
        weight: Font.Weight? = nil,
        color: Color? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.size = size
        self.weight = weight ?? (size == .large ? .bold : size == .medium ? .semibold : .regular)
        self.color = color
    }
    
    var body: some View {
        Text(formattedAmount)
            .font(size.font.weight(weight))
            .foregroundStyle(color ?? Color.primary)
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency.symbol) \(amountString)"
    }
}

/// A variant that shows positive/negative amounts with semantic colors.
///
/// Automatically colors positive amounts green and negative amounts red.
///
/// **Usage:**
/// ```swift
/// SignedCurrencyText(
///     amount: -250.00,
///     currency: currency
/// )
/// // Displays in red with minus sign
/// ```
struct SignedCurrencyText: View {
    let amount: Decimal
    let currency: Currency
    let size: CurrencyText.SizeVariant
    let showPlusSign: Bool
    
    init(
        amount: Decimal,
        currency: Currency,
        size: CurrencyText.SizeVariant = .regular,
        showPlusSign: Bool = true
    ) {
        self.amount = amount
        self.currency = currency
        self.size = size
        self.showPlusSign = showPlusSign
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if amount > 0 && showPlusSign {
                Text("+")
                    .font(size.font)
                    .foregroundStyle(.green)
            }
            
            CurrencyText(
                amount: abs(amount),
                currency: currency,
                size: size,
                color: amount >= 0 ? .green : .red
            )
        }
    }
}

/// A compact currency display for tight spaces.
///
/// Shows just the symbol and amount without full formatting.
struct CompactCurrencyText: View {
    let amount: Decimal
    let currency: Currency
    
    var body: some View {
        Text("\(currency.symbol)\(formatCompact(amount))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    private func formatCompact(_ value: Decimal) -> String {
        let number = abs(NSDecimalNumber(decimal: value).doubleValue)
        
        if number >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
        } else {
            return String(format: "%.0f", number)
        }
    }
}

// MARK: - Previews

#Preview("Currency Text Sizes") {
    VStack(spacing: 24) {
        let currency = Currency(code: "GTQ", symbol: "Q")
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Size Variants")
                .font(.headline)
            
            CurrencyText(
                amount: 25750.50,
                currency: currency,
                size: .large
            )
            
            CurrencyText(
                amount: 12500.00,
                currency: currency,
                size: .medium
            )
            
            CurrencyText(
                amount: 1875.00,
                currency: currency,
                size: .regular
            )
            
            CurrencyText(
                amount: 450.25,
                currency: currency,
                size: .small
            )
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Signed Amounts")
                .font(.headline)
            
            SignedCurrencyText(
                amount: 5250.00,
                currency: currency,
                size: .medium
            )
            
            SignedCurrencyText(
                amount: -1875.50,
                currency: currency,
                size: .medium
            )
            
            SignedCurrencyText(
                amount: 0,
                currency: currency,
                size: .medium
            )
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Compact Format")
                .font(.headline)
            
            HStack {
                CompactCurrencyText(amount: 1_250_000, currency: currency)
                CompactCurrencyText(amount: 45_500, currency: currency)
                CompactCurrencyText(amount: 750, currency: currency)
            }
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("In Context")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Capital Actual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    CurrencyText(
                        amount: 25750.50,
                        currency: currency,
                        size: .large,
                        color: .blue
                    )
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Balance Mensual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    SignedCurrencyText(
                        amount: 3250.00,
                        currency: currency,
                        size: .medium
                    )
                }
            }
            .cardStyle()
        }
    }
    .padding()
    .frame(width: 500)
}
