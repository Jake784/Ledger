//
//  HistoryGlassStyle.swift
//  FinVault
//

import SwiftUI

/// Liquid Glass surface treatments scoped to `HistoryToolbar`.
///
/// Deliberately kept separate from `cardStyle`/`Card` (`ViewsSharedCardStyle.swift`)
/// and from `DashboardGlassStyle`/`FormGlassStyle`, for the same reason those two
/// stay scoped to their own modules — changing a shared modifier would restyle
/// every other module's cards, not just the Historial toolbar.
extension View {
    /// The rounded capsule housing a group of `HistoryToolbar` icon buttons —
    /// a single continuous glass surface, matching Finder's toolbar icon groupings.
    /// Applied separately to the filter/sort cluster and the search button, so each
    /// reads as its own distinct group rather than one continuous capsule.
    func historyToolbarClusterGlass() -> some View {
        self
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}
