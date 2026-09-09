//
//  NavigationSidebar.swift
//  FinVault
//
//  Created by Luis Callejas on 15/08/26.
//

import SwiftUI

/// The set of top-level modules presented in FinVault's main sidebar.
///
/// Each case pairs a Spanish, user-facing label with an SF Symbol.
/// The raw value is used as a stable identifier for `NavigationSplitView` selection.
enum SidebarModule: String, CaseIterable, Identifiable {
    case panel
    case ingresos
    case gastos
    case historial
    case proyecciones
    case presupuestos
    case metas
    case ahorro
    case categorias
    case configuracion

    var id: String { rawValue }

    /// User-facing label shown in the sidebar.
    var title: String {
        switch self {
        case .panel: return "Panel"
        case .ingresos: return "Ingresos"
        case .gastos: return "Gastos"
        case .historial: return "Historial"
        case .proyecciones: return "Proyecciones"
        case .presupuestos: return "Presupuestos"
        case .metas: return "Metas"
        case .ahorro: return "Ahorro"
        case .categorias: return "Categorías"
        case .configuracion: return "Configuración"
        }
    }

    /// SF Symbol representing the module.
    var icon: String {
        switch self {
        case .panel: return "square.grid.2x2"
        case .ingresos: return "arrow.down.circle"
        case .gastos: return "arrow.up.circle"
        case .historial: return "clock.arrow.circlepath"
        case .proyecciones: return "chart.line.uptrend.xyaxis"
        case .presupuestos: return "chart.pie"
        case .metas: return "target"
        case .ahorro: return "banknote"
        case .categorias: return "tag"
        case .configuracion: return "gearshape"
        }
    }
}

/// The main sidebar for FinVault's `NavigationSplitView`.
///
/// Lists every top-level module with an SF Symbol and Spanish label,
/// highlighting the currently selected item as a Liquid Glass pill tinted
/// with the accent color.
///
/// **Usage:**
/// ```swift
/// @State private var selection: SidebarModule? = .panel
///
/// NavigationSplitView {
///     NavigationSidebar(selection: $selection)
/// } detail: {
///     // Module-specific view based on `selection`
/// }
/// ```
///
/// **Implementation note:** this renders rows itself instead of using
/// `List(selection:)`. A native macOS `List`'s selection highlight is an opaque
/// solid rect that can't be swapped for a glass capsule while keeping the row
/// underneath it — so matching the glass-pill look means giving up `List`'s
/// row type in exchange for the buttons' own Tab-key focus and full
/// click/VoiceOver support. Arrow-key traversal is reimplemented manually
/// below (`.focusable()` + `.onMoveCommand`) so keyboard navigation still
/// matches `List`'s behavior despite not using one.
///
/// **Where Used:**
/// - Root app scene, as the primary column of `NavigationSplitView`
struct NavigationSidebar: View {
    @Binding var selection: SidebarModule?

    /// Keeps keyboard focus on the sidebar itself (rather than whichever row
    /// `Button` was last clicked) so `onMoveCommand` reliably keeps receiving
    /// arrow-key events — a plain `.focusable()` only makes the container
    /// *eligible* for focus, it doesn't claim it.
    @FocusState private var isFocused: Bool

    /// Single source of truth for the selection-pill transition. Applied via
    /// `withAnimation` at every mutation site (row taps and both arrow-key
    /// directions in `moveSelection`) instead of a per-row implicit
    /// `.animation(value:)` — the previous implicit-animation approach fired
    /// inconsistently between Up and Down, and compounded with the
    /// `ScrollView`'s native arrow-key overscroll bounce (Up immediately
    /// rubber-bands against the top edge when the topmost row is already
    /// selected) to make Up feel laggy while Down looked instant.
    private static let selectionAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SidebarModule.allCases) { module in
                        SidebarRow(
                            module: module,
                            isSelected: selection == module,
                            action: { selectModule(module) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }
        }
        // Content always fits the sidebar's height, so this disables the
        // elastic overscroll bounce entirely rather than only suppressing it
        // conditionally — that bounce (not the pill's own spring) was the
        // actual source of the Up-only stutter.
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("FinVault")
        .tint(Color.accentColor)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onMoveCommand(perform: moveSelection)
        .onAppear { isFocused = true }
    }

    private func selectModule(_ module: SidebarModule) {
        withAnimation(Self.selectionAnimation) {
            selection = module
        }
        isFocused = true
    }

    /// Moves `selection` up/down through `SidebarModule.allCases`, mirroring
    /// `List(selection:)`'s native arrow-key row traversal. Both directions
    /// go through the exact same `selectModule` call, so the animation is
    /// identical regardless of which arrow key triggered it.
    private func moveSelection(_ direction: MoveCommandDirection) {
        let modules = SidebarModule.allCases

        guard let current = selection, let currentIndex = modules.firstIndex(of: current) else {
            if let first = modules.first {
                selectModule(first)
            }
            return
        }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        default:
            return
        }

        guard modules.indices.contains(targetIndex) else { return }
        selectModule(modules[targetIndex])
    }
}

/// A single tappable sidebar row; becomes a tinted glass capsule while selected.
private struct SidebarRow: View {
    let module: SidebarModule
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                rowLabel.glassEffect(.regular.tint(Color.accentColor.opacity(0.25)), in: .capsule)
            } else {
                rowLabel
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var rowLabel: some View {
        Label(module.title, systemImage: module.icon)
            .font(.body)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Navigation Sidebar") {
    NavigationSidebarPreviewContainer()
}

/// Stateful wrapper so the preview can drive `@Binding var selection`.
private struct NavigationSidebarPreviewContainer: View {
    @State private var selection: SidebarModule? = .panel

    var body: some View {
        NavigationSplitView {
            NavigationSidebar(selection: $selection)
        } detail: {
            if let selection = selection {
                VStack(spacing: 12) {
                    Image(systemName: selection.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                    Text(selection.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            } else {
                Text("Selecciona un módulo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 700, height: 450)
    }
}
