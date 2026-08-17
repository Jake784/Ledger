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
/// highlighting the currently selected item with the accent color.
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
/// **Where Used:**
/// - Root app scene, as the primary column of `NavigationSplitView`
struct NavigationSidebar: View {
    @Binding var selection: SidebarModule?

    var body: some View {
        List(SidebarModule.allCases, selection: $selection) { module in
            Label(module.title, systemImage: module.icon)
                .tag(module)
        }
        .navigationTitle("FinVault")
        .tint(Color.accentColor)
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
