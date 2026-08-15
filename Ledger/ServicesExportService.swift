//
//  ExportService.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import Foundation
import PDFKit
import AppKit // Required for NSFont, NSColor, and PDF rendering on macOS

/// Service that exports financial data to CSV and PDF formats for backup and sharing.
///
/// This service provides transaction export capabilities in two formats:
/// - **CSV**: Plain text tabular format for spreadsheet import
/// - **PDF**: Formatted document for archival and sharing
///
/// **Usage Example:**
/// ```swift
/// // In HistoryViewModel or ExportViewModel:
/// let exportService = ExportService()
///
/// func exportToPDF() {
///     let pdfData = exportService.exportTransactionsToPDF(
///         transactions,
///         title: "Transaction History - 2026"
///     )
///
///     do {
///         let fileURL = try exportService.saveToFile(
///             data: pdfData,
///             filename: "FinVault_Transactions_2026.pdf"
///         )
///         // Present share sheet or save panel with fileURL
///     } catch {
///         print("Export failed: \(error)")
///     }
/// }
/// ```
///
/// **Current Use Cases:**
/// - Historial (Transaction history export)
///
/// **Future Use Cases:**
/// - Proyecciones (Export projection line items)
/// - Presupuestos (Export budget vs. actual reports)
///
/// **Dependencies:**
/// Assumes Transaction model is available in the same target.
final class ExportService {
    
    // MARK: - CSV Export
    
    /// Exports an array of transactions to CSV format.
    ///
    /// Generates a CSV string with columns: Date, Type, Category, Description, Quantity, Unit Price, Amount, Currency.
    /// Properly escapes commas, quotes, and newlines in text fields.
    ///
    /// - Parameter transactions: Array of transactions to export.
    /// - Returns: A CSV-formatted string ready to be written to a file.
    func exportTransactionsToCSV(_ transactions: [Transaction]) -> String {
        var csv = "Date,Type,Category,Description,Quantity,Unit Price,Amount,Currency\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.date)
            let type = transaction.type.rawValue.capitalized
            let category = escapeCSVField(transaction.category?.name ?? "Uncategorized")
            let description = escapeCSVField(transaction.descriptionText)
            let quantity = String(transaction.quantity)
            let unitPrice = formatDecimal(transaction.unitPrice)
            let amount = formatDecimal(transaction.amount)
            let currency = transaction.currency?.code ?? ""
            
            let row = "\(date),\(type),\(category),\(description),\(quantity),\(unitPrice),\(amount),\(currency)\n"
            csv.append(row)
        }
        
        return csv
    }
    
    /// Escapes a CSV field value, wrapping in quotes if necessary.
    private func escapeCSVField(_ field: String) -> String {
        // If field contains comma, quote, or newline, wrap in quotes and escape quotes
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    // MARK: - PDF Export
    
    /// Exports an array of transactions to PDF format.
    ///
    /// Generates a simple tabular PDF report with the provided title.
    /// Uses Core Graphics for PDF rendering on macOS.
    ///
    /// - Parameters:
    ///   - transactions: Array of transactions to export.
    ///   - title: The title to display at the top of the PDF.
    /// - Returns: PDF data that can be saved to a file or shared.
    func exportTransactionsToPDF(_ transactions: [Transaction], title: String) -> Data {
        // Define page dimensions (US Letter: 612 x 792 points)
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - (margin * 2)
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        // Create PDF data
        let data = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            return Data()
        }
        
        var mediaBox = pageRect
        
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }
        
        // Set up flipped coordinate system for easier drawing
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext
        
        var currentY: CGFloat = margin
        
        // Begin first page
        context.beginPDFPage(nil as CFDictionary?)
        
        // Draw title
        currentY = drawTitle(title, at: currentY, pageWidth: pageWidth)
        currentY += 20
        
        // Draw table header
        currentY = drawTableHeader(at: currentY, margin: margin, contentWidth: contentWidth)
        currentY += 5
        
        // Draw transactions
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        for transaction in transactions {
            // Check if we need a new page
            if currentY > pageHeight - margin - 40 {
                context.endPDFPage()
                context.beginPDFPage(nil as CFDictionary?)
                currentY = margin
                currentY = drawTableHeader(at: currentY, margin: margin, contentWidth: contentWidth)
                currentY += 5
            }
            
            currentY = drawTransactionRow(
                transaction,
                at: currentY,
                margin: margin,
                contentWidth: contentWidth,
                dateFormatter: dateFormatter
            )
        }
        
        // End last page
        context.endPDFPage()
        context.closePDF()
        
        NSGraphicsContext.restoreGraphicsState()
        
        return data as Data
    }
    
    /// Draws the PDF title.
    private func drawTitle(_ title: String, at y: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let font = NSFont.boldSystemFont(ofSize: 18)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let titleSize = title.size(withAttributes: attributes)
        let titleX = (pageWidth - titleSize.width) / 2
        let titleRect = CGRect(x: titleX, y: y, width: titleSize.width, height: titleSize.height)
        
        title.draw(in: titleRect, withAttributes: attributes)
        
        return y + titleSize.height
    }
    
    /// Draws the table header row.
    private func drawTableHeader(at y: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let font = NSFont.boldSystemFont(ofSize: 10)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let columns = ["Date", "Type", "Category", "Description", "Qty", "Unit Price", "Amount", "Curr"]
        let columnWidths: [CGFloat] = [60, 50, 80, 150, 30, 70, 70, 40] // Total: 550
        
        var x = margin
        for (index, column) in columns.enumerated() {
            let rect = CGRect(x: x, y: y, width: columnWidths[index], height: 15)
            column.draw(in: rect, withAttributes: attributes)
            x += columnWidths[index]
        }
        
        // Draw line under header
        let linePath = NSBezierPath()
        linePath.move(to: CGPoint(x: margin, y: y + 16))
        linePath.line(to: CGPoint(x: margin + 550, y: y + 16))
        linePath.lineWidth = 0.5
        NSColor.gray.setStroke()
        linePath.stroke()
        
        return y + 18
    }
    
    /// Draws a single transaction row.
    private func drawTransactionRow(
        _ transaction: Transaction,
        at y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        dateFormatter: DateFormatter
    ) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 9)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let date = dateFormatter.string(from: transaction.date)
        let type = transaction.type.rawValue.prefix(3).uppercased()
        let category = transaction.category?.name ?? "—"
        let description = truncate(transaction.descriptionText, maxLength: 25)
        let quantity = String(transaction.quantity)
        let unitPrice = formatDecimal(transaction.unitPrice)
        let amount = formatDecimal(transaction.amount)
        let currency = transaction.currency?.code ?? ""
        
        let columnWidths: [CGFloat] = [60, 50, 80, 150, 30, 70, 70, 40]
        let values = [date, type, category, description, quantity, unitPrice, amount, currency]
        
        var x = margin
        for (index, value) in values.enumerated() {
            let rect = CGRect(x: x, y: y, width: columnWidths[index], height: 12)
            value.draw(in: rect, withAttributes: attributes)
            x += columnWidths[index]
        }
        
        return y + 14
    }
    
    /// Truncates a string to a maximum length, adding ellipsis if needed.
    private func truncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: maxLength - 1)
        return String(text[..<index]) + "…"
    }
    
    // MARK: - File System
    
    /// Saves data to a file in the app's Documents directory.
    ///
    /// Creates the file and returns its URL for sharing via a share sheet or save panel.
    ///
    /// - Parameters:
    ///   - data: The data to write to the file.
    ///   - filename: The desired filename (including extension).
    /// - Returns: The URL of the saved file.
    /// - Throws: An error if the file cannot be written.
    func saveToFile(data: Data, filename: String) throws -> URL {
        let fileManager = FileManager.default
        
        // Get the Documents directory
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExportError.documentsDirectoryNotFound
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // Write the data to the file
        try data.write(to: fileURL, options: .atomic)
        
        return fileURL
    }
    
    /// Saves data to a temporary file suitable for immediate sharing.
    ///
    /// Useful for share sheets where the file doesn't need to persist.
    ///
    /// - Parameters:
    ///   - data: The data to write to the file.
    ///   - filename: The desired filename (including extension).
    /// - Returns: The URL of the temporary file.
    /// - Throws: An error if the file cannot be written.
    func saveToTemporaryFile(data: Data, filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL, options: .atomic)
        
        return fileURL
    }
    
    // MARK: - Helpers
    
    /// Formats a Decimal value for display (2 decimal places).
    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case documentsDirectoryNotFound
    
    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "Could not locate the Documents directory."
        }
    }
}

