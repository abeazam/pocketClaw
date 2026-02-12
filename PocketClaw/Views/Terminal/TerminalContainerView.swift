import SwiftUI
import SwiftTerm

// MARK: - Terminal Container View

/// Wraps SwiftTerm's UIKit `TerminalView` for use in SwiftUI.
struct TerminalContainerView: UIViewRepresentable {
    let viewModel: TerminalViewModel

    func makeUIView(context: Context) -> TerminalView {
        // Reuse the existing TerminalView if available — this preserves
        // the terminal buffer (scrollback, cursor, screen content) across
        // sheet dismiss/reopen cycles.
        if let existing = viewModel.terminalView {
            existing.terminalDelegate = context.coordinator
            installAccessory(on: existing, coordinator: context.coordinator)
            return existing
        }

        let terminalView = TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.backgroundColor = .black
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .init(red: 0.19, green: 0.82, blue: 0.35, alpha: 1) // #30D158

        // Install our custom accessory with terminal keys + OpenClaw commands
        installAccessory(on: terminalView, coordinator: context.coordinator)

        // Keep a strong reference so the view survives sheet dismissal
        viewModel.terminalView = terminalView

        return terminalView
    }

    private func installAccessory(on terminalView: TerminalView, coordinator: Coordinator) {
        let screenWidth = terminalView.window?.screen.bounds.width ?? terminalView.bounds.width
        let accessory = TerminalAccessoryView(width: max(screenWidth, 375))

        accessory.onSendData = { [weak coordinator] data in
            coordinator?.viewModel.send(data)
        }

        accessory.onCtrlToggle = { active in
            // SwiftTerm checks this property when encoding key events
            terminalView.controlModifier = active
        }

        terminalView.inputAccessoryView = accessory
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // No dynamic updates needed — data flows through callbacks
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, TerminalViewDelegate {
        let viewModel: TerminalViewModel

        init(viewModel: TerminalViewModel) {
            self.viewModel = viewModel
        }

        // Keyboard input → SSH
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            viewModel.send(Data(data))
        }

        // Terminal resized
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            viewModel.resize(cols: newCols, rows: newRows)
        }

        // Terminal title changed (optional — ignore for now)
        func setTerminalTitle(source: TerminalView, title: String) {}

        // Current directory changed (optional — ignore)
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        // Scroll position changed (optional — ignore)
        func scrolled(source: TerminalView, position: Double) {}

        // Hyperlink clicked (optional — ignore)
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}

        // Bell (optional — could add haptic later)
        func bell(source: TerminalView) {}

        // Clipboard (optional — ignore)
        func clipboardCopy(source: TerminalView, content: Data) {}

        // iTerm2 content (optional — ignore)
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

        // Range changed (optional — ignore)
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
