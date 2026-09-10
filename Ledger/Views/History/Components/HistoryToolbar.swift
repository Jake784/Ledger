//
//  HistoryToolbar.swift
//  FinVault
//

import SwiftUI

/// The order `HistoryToolbar`'s sort menu applies to `filteredTransactions`.
enum HistorySortOrder {
    case newestFirst
    case oldestFirst
}

/// A Finder-style toolbar for `HistoryView`, hosted inline with the navigation title
/// via `.toolbar(placement: .primaryAction)` — mirrors how Finder's toolbar icons sit
/// in the same bar as the window title, rather than as a separate row in the content.
///
/// Two distinct glass capsules, matching Finder's own toolbar grouping (its view
/// switcher is one group; share/tag/more/search is a second group with search visually
/// separate at the end): filter+sort together in one capsule, search alone in a second,
/// with a small gap between them.
///
/// Wires directly into `HistoryView`'s existing filter/sort state via bindings rather
/// than owning any filtering logic itself — `filterButton` only toggles the existing
/// `filterBar`'s visibility, `sortMenu` only flips `sortOrder` (consumed by
/// `HistoryViewModel.filteredTransactions(sortAscending:)`), and `searchField` is bound
/// to the same `searchText` `HistoryView` already threads through `filteredTransactions`.
///
/// Every icon button reuses `hoverHighlight()` (`ViewsSharedHoverEffect.swift`) and the
/// `.contentShape(Rectangle())` full-bounds click-target fix already established for
/// custom button labels elsewhere (`PrimaryButtonStyle`, `SidebarRow`).
///
/// **Where Used:**
/// - `HistoryView`, via `.toolbar(placement: .primaryAction)` next to the "Historial" title.
struct HistoryToolbar: View {
    @Binding var sortOrder: HistorySortOrder
    @Binding var isFilterPanelExpanded: Bool
    @Binding var searchText: String
    let hasActiveFilters: Bool

    @State private var isSearchExpanded = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 10) {
                filterSortCluster
                searchCluster
            }
        }
        .onAppear {
            // A non-empty search carried over from before the toolbar last
            // appeared (e.g. cleared via "Limpiar filtros" while collapsed)
            // should still land expanded, not hide an active query.
            isSearchExpanded = !searchText.isEmpty
        }
    }

    // MARK: - Filter + Sort Cluster

    private var filterSortCluster: some View {
        HStack(spacing: 2) {
            filterButton
            sortMenu
        }
        .padding(4)
        .historyToolbarClusterGlass()
    }

    private var filterButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isFilterPanelExpanded.toggle()
            }
        } label: {
            Image(systemName: isFilterPanelExpanded ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFilterPanelExpanded ? Color.accentColor : Color.primary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if hasActiveFilters {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityLabel("Filtros")
    }

    private var sortMenu: some View {
        Menu {
            Toggle(
                "Más recientes primero",
                isOn: Binding(
                    get: { sortOrder == .newestFirst },
                    set: { if $0 { sortOrder = .newestFirst } }
                )
            )
            Toggle(
                "Más antiguos primero",
                isOn: Binding(
                    get: { sortOrder == .oldestFirst },
                    set: { if $0 { sortOrder = .oldestFirst } }
                )
            )
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .hoverHighlight()
        .accessibilityLabel("Ordenar")
    }

    // MARK: - Search Cluster

    private var searchCluster: some View {
        searchField
            .padding(4)
            .historyToolbarClusterGlass()
    }

    /// A magnifying-glass button that expands into an inline field, mirroring Finder's
    /// toolbar search. Bound directly to `searchText` — `HistoryView`'s `filterBar` no
    /// longer has its own search field, so there's a single source of truth.
    private var searchField: some View {
        HStack(spacing: 6) {
            Button(action: toggleSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight()
            .accessibilityLabel("Buscar")

            if isSearchExpanded {
                TextField("Buscar por descripción", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .frame(width: 160)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.trailing, isSearchExpanded ? 10 : 0)
    }

    /// Collapses back to just the icon when the field is already empty; otherwise clears
    /// the query first (matching Spotlight/Finder's search-field behavior), so a stray
    /// tap never silently discards what the user typed.
    private func toggleSearch() {
        withAnimation(.easeOut(duration: 0.15)) {
            if isSearchExpanded && !searchText.isEmpty {
                searchText = ""
            } else {
                isSearchExpanded.toggle()
                if isSearchExpanded {
                    isSearchFieldFocused = true
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("History Toolbar") {
    HistoryToolbarPreviewContainer()
        .padding(24)
        .frame(width: 500)
}

/// Stateful wrapper so the preview can drive every `@Binding`.
private struct HistoryToolbarPreviewContainer: View {
    @State private var sortOrder: HistorySortOrder = .newestFirst
    @State private var isFilterPanelExpanded = false
    @State private var searchText = ""

    var body: some View {
        HistoryToolbar(
            sortOrder: $sortOrder,
            isFilterPanelExpanded: $isFilterPanelExpanded,
            searchText: $searchText,
            hasActiveFilters: true
        )
    }
}
