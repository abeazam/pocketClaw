import UIKit
import SwiftTerm

// MARK: - Quick Command Definition

struct TerminalQuickCommand {
    let label: String
    let command: String
    let icon: String?
    let destructive: Bool

    init(_ label: String, command: String, icon: String? = nil, destructive: Bool = false) {
        self.label = label
        self.command = command
        self.icon = icon
        self.destructive = destructive
    }

    // MARK: - OpenClaw Commands

    static let openClawCommands: [TerminalQuickCommand] = [
        .init("Status", command: "openclaw status --all", icon: "chart.bar"),
        .init("Health", command: "openclaw health", icon: "heart"),
        .init("Restart", command: "openclaw gateway restart", icon: "arrow.clockwise"),
        .init("Logs", command: "tail -f /tmp/openclaw-gateway.log", icon: "doc.text"),
        .init("Doctor", command: "openclaw doctor --repair", icon: "stethoscope"),
        .init("Channels", command: "openclaw channels status --probe", icon: "antenna.radiowaves.left.and.right"),
        .init("Update", command: "sudo npm i -g openclaw@latest", icon: "arrow.down.circle"),
        .init("Sessions", command: "openclaw sessions --active 60", icon: "bubble.left.and.bubble.right"),
        .init("Agents", command: "openclaw agents list", icon: "person.2"),
        .init("Onboard", command: "openclaw onboard", icon: "hand.wave"),
        .init("Kill", command: "pkill -9 -f openclaw-gateway", icon: "xmark.octagon", destructive: true),
    ]
}

// MARK: - Terminal Accessory View

/// Custom keyboard accessory with two rows:
/// Row 1: Standard terminal keys (Esc, Ctrl, Tab, symbols, arrows)
/// Row 2: Scrollable OpenClaw quick command buttons
final class TerminalAccessoryView: UIInputView, UIInputViewAudioFeedback {

    // MARK: - Callbacks

    /// Called when a key or command sends data to the terminal
    var onSendData: ((_ data: Data) -> Void)?

    /// Called when the Ctrl modifier is toggled
    var onCtrlToggle: ((_ active: Bool) -> Void)?

    // MARK: - State

    private var isCtrlActive = false
    private var ctrlButton: UIButton?

    // MARK: - Constants

    private let terminalGreen = UIColor(red: 48 / 255, green: 209 / 255, blue: 88 / 255, alpha: 1) // #30D158
    private let rowHeight: CGFloat = 36
    private let buttonSpacing: CGFloat = 5
    private let buttonCornerRadius: CGFloat = 6

    // MARK: - UIInputViewAudioFeedback

    var enableInputClicksWhenVisible: Bool { true }

    // MARK: - Init

    init(width: CGFloat) {
        let totalHeight: CGFloat = 78 // Two rows + padding
        super.init(
            frame: CGRect(x: 0, y: 0, width: width, height: totalHeight),
            inputViewStyle: .keyboard
        )
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])

        // Row 1: Terminal keys
        let terminalKeysRow = buildTerminalKeysRow()
        stack.addArrangedSubview(terminalKeysRow)
        terminalKeysRow.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

        // Row 2: OpenClaw commands (scrollable)
        let commandsRow = buildCommandsRow()
        stack.addArrangedSubview(commandsRow)
        commandsRow.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
    }

    // MARK: - Row 1: Terminal Keys

    private func buildTerminalKeysRow() -> UIView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = buttonSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        // Terminal key definitions: (label, bytes to send)
        let keys: [(String, [UInt8])] = [
            ("esc", [0x1B]),
            ("ctrl", []),  // Special: toggle modifier
            ("tab", [0x09]),
            ("~", Array("~".utf8)),
            ("|", Array("|".utf8)),
            ("/", Array("/".utf8)),
            ("-", Array("-".utf8)),
        ]

        for (label, bytes) in keys {
            let button = makeTerminalKeyButton(label: label)
            if label == "ctrl" {
                button.addAction(UIAction { [weak self] _ in
                    self?.toggleCtrl()
                }, for: .touchUpInside)
                ctrlButton = button
            } else {
                let data = bytes
                button.addAction(UIAction { [weak self] _ in
                    UIDevice.current.playInputClick()
                    self?.sendBytes(data)
                }, for: .touchUpInside)
            }
            stack.addArrangedSubview(button)
        }

        // Separator
        let sep = makeSeparator()
        stack.addArrangedSubview(sep)

        // Arrow keys
        let arrows: [(String, String, [UInt8])] = [
            ("arrow.left", "Left", [0x1B, 0x5B, 0x44]),
            ("arrow.down", "Down", [0x1B, 0x5B, 0x42]),
            ("arrow.up", "Up", [0x1B, 0x5B, 0x41]),
            ("arrow.right", "Right", [0x1B, 0x5B, 0x43]),
        ]

        for (icon, accessLabel, bytes) in arrows {
            let button = makeArrowButton(icon: icon, accessibilityLabel: accessLabel)
            let data = bytes
            button.addAction(UIAction { [weak self] _ in
                UIDevice.current.playInputClick()
                self?.sendBytes(data)
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        return scrollView
    }

    // MARK: - Row 2: OpenClaw Commands

    private func buildCommandsRow() -> UIView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        for cmd in TerminalQuickCommand.openClawCommands {
            let button = makeCommandButton(cmd)
            button.addAction(UIAction { [weak self] _ in
                UIDevice.current.playInputClick()
                self?.sendCommand(cmd.command)
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        return scrollView
    }

    // MARK: - Button Factories

    private func makeTerminalKeyButton(label: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = label
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(white: 0.25, alpha: 1)
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            return outgoing
        }

        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.accessibilityLabel = label
        return button
    }

    private func makeArrowButton(icon: String, accessibilityLabel: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(white: 0.25, alpha: 1)
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)

        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.accessibilityLabel = accessibilityLabel
        return button
    }

    private func makeCommandButton(_ cmd: TerminalQuickCommand) -> UIButton {
        var config = UIButton.Configuration.filled()

        if let iconName = cmd.icon {
            config.image = UIImage(
                systemName: iconName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            )
            config.imagePadding = 4
            config.imagePlacement = .leading
        }

        config.title = cmd.label
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return outgoing
        }

        if cmd.destructive {
            config.baseForegroundColor = .white
            config.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        } else {
            config.baseForegroundColor = .black
            config.baseBackgroundColor = UIColor(
                red: 48 / 255, green: 209 / 255, blue: 88 / 255, alpha: 0.9
            ) // Terminal green
        }

        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.accessibilityLabel = "\(cmd.label) command"
        return button
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = UIColor(white: 0.4, alpha: 1)
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return sep
    }

    // MARK: - Actions

    private func toggleCtrl() {
        UIDevice.current.playInputClick()
        isCtrlActive.toggle()

        if let ctrlButton {
            var config = ctrlButton.configuration
            config?.baseBackgroundColor = isCtrlActive
                ? terminalGreen
                : UIColor(white: 0.25, alpha: 1)
            config?.baseForegroundColor = isCtrlActive ? .black : .white
            ctrlButton.configuration = config
        }

        onCtrlToggle?(isCtrlActive)
    }

    private func sendBytes(_ bytes: [UInt8]) {
        var bytesToSend = bytes

        // Apply Ctrl modifier: Ctrl+key = key & 0x1F for printable ASCII
        if isCtrlActive, bytesToSend.count == 1, bytesToSend[0] >= 0x40, bytesToSend[0] <= 0x7E {
            bytesToSend = [bytesToSend[0] & 0x1F]
            // Auto-reset Ctrl
            isCtrlActive = false
            if let ctrlButton {
                var config = ctrlButton.configuration
                config?.baseBackgroundColor = UIColor(white: 0.25, alpha: 1)
                config?.baseForegroundColor = .white
                ctrlButton.configuration = config
            }
            onCtrlToggle?(false)
        }

        onSendData?(Data(bytesToSend))
    }

    private func sendCommand(_ command: String) {
        let fullCommand = command + "\n"
        if let data = fullCommand.data(using: .utf8) {
            onSendData?(data)
        }
    }
}
