import Cocoa
import Carbon.HIToolbox

// MARK: - Shortcut formatting

let keyNames: [UInt32: String] = [
    50: "`",
    // Arrows
    123: "←", 124: "→", 125: "↓", 126: "↑",
    // Letters
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
    8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
    16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 37: "L", 38: "J",
    40: "K", 45: "N", 46: "M",
    // Numbers
    18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
    25: "9", 26: "7", 28: "8", 29: "0",
    // Special
    36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
    // Function
    122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
    98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
]

func formatShortcut(keyCode: UInt32, modifiers: UInt32) -> String {
    var m = ""
    if modifiers & UInt32(controlKey) != 0 { m += "⌃" }
    if modifiers & UInt32(optionKey)  != 0 { m += "⌥" }
    if modifiers & UInt32(shiftKey)   != 0 { m += "⇧" }
    if modifiers & UInt32(cmdKey)     != 0 { m += "⌘" }
    return m + (keyNames[keyCode] ?? "(\(keyCode))")
}

// MARK: - Toggle switch

final class ToggleSwitch: NSControl {

    var isOn: Bool = false { didSet { needsDisplay = true } }

    override var intrinsicContentSize: NSSize { NSSize(width: 44, height: 24) }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        sendAction(action, to: target)
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = bounds.insetBy(dx: 1, dy: 1)
        let r = track.height / 2
        (isOn ? NSColor.controlAccentColor : NSColor(white: 0.65, alpha: 1)).setFill()
        NSBezierPath(roundedRect: track, xRadius: r, yRadius: r).fill()

        let pad: CGFloat = 2
        let td = track.height - pad * 2
        let tx = isOn ? track.maxX - td - pad : track.minX + pad
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: tx, y: track.minY + pad, width: td, height: td)).fill()
    }
}

private class NonClickableHeaderView: NSTableHeaderView {
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
}

// MARK: - Settings window

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    var onHotkeysChanged: (() -> Void)?
    var onStartRecording: (() -> Void)?
    var onStopRecording:  (() -> Void)?

    private var tableView: NSTableView!
    private var recordingRow: Int?
    private var keyMonitor: Any?
    private weak var enabledSwitch: ToggleSwitch?
    private weak var axStatusLabel: NSTextField?
    private weak var axOpenBtn: NSButton?
    private weak var finderCheckbox: NSButton?
    private weak var finderTextField: NSTextField?
    private weak var launchAtLoginCheckbox: NSButton?

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 690),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Sizer Settings"
        win.center()
        win.isReleasedWhenClosed = false
        self.init(window: win)
        win.delegate = self
        buildUI()
    }

    // MARK: UI

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        // Header: icon + title + enabled toggle

        let iconView = NSImageView(image: makeSizerIcon(dim: 32))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleNone
        cv.addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: "Sizer")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .boldSystemFont(ofSize: 15)
        cv.addSubview(titleLabel)

        let enabledLabel = NSTextField(labelWithString: "Enabled")
        enabledLabel.translatesAutoresizingMaskIntoConstraints = false
        enabledLabel.font = .systemFont(ofSize: 13)
        cv.addSubview(enabledLabel)

        let sw = ToggleSwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.isOn = AppDelegate.shared?.isEnabled ?? true
        sw.target = self
        sw.action = #selector(enabledToggled)
        cv.addSubview(sw)
        enabledSwitch = sw

        // Tabs

        let tabs = NSTabView()
        tabs.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(tabs)

        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalItem.view = buildGeneralTab()
        tabs.addTabViewItem(generalItem)

        let shortcutsItem = NSTabViewItem(identifier: "shortcuts")
        shortcutsItem.label = "Shortcuts"
        shortcutsItem.view = buildShortcutsTab()
        tabs.addTabViewItem(shortcutsItem)

        // Footer

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(close))
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"
        cv.addSubview(doneBtn)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let versionLabel = NSTextField(labelWithString: "v\(version)")
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        versionLabel.textColor = .tertiaryLabelColor
        cv.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 14),
            iconView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            sw.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            sw.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            sw.widthAnchor.constraint(equalToConstant: 44),
            sw.heightAnchor.constraint(equalToConstant: 24),

            enabledLabel.trailingAnchor.constraint(equalTo: sw.leadingAnchor, constant: -6),
            enabledLabel.centerYAnchor.constraint(equalTo: sw.centerYAnchor),

            tabs.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            tabs.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 12),
            tabs.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -12),
            tabs.bottomAnchor.constraint(equalTo: doneBtn.topAnchor, constant: -12),

            doneBtn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            doneBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),

            versionLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            versionLabel.centerYAnchor.constraint(equalTo: doneBtn.centerYAnchor),
        ])

        refreshAccessibilityStatus()
    }

    private func buildShortcutsTab() -> NSView {
        let v = NSView()

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = false
        scroll.borderType = .bezelBorder
        v.addSubview(scroll)

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.allowsColumnResizing    = false
        tableView.allowsMultipleSelection = false
        tableView.rowHeight   = 26
        tableView.focusRingType = .none
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.intercellSpacing = .zero
        tableView.headerView = NonClickableHeaderView()

        let c1 = NSTableColumn(identifier: .init("action"))
        c1.title = "Action"; c1.width = 200
        let c2 = NSTableColumn(identifier: .init("shortcut"))
        c2.title = "Shortcut"; c2.width = 180
        tableView.addTableColumn(c1)
        tableView.addTableColumn(c2)

        scroll.documentView = tableView
        tableView.reloadData()

        let helpLabel = NSTextField(labelWithString: "Click a shortcut to record a new one. Press ⎋ to cancel.")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        v.addSubview(helpLabel)

        let resetBtn = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults))
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        resetBtn.bezelStyle = .rounded
        v.addSubview(resetBtn)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: v.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: helpLabel.topAnchor, constant: -8),

            helpLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            helpLabel.bottomAnchor.constraint(equalTo: resetBtn.topAnchor, constant: -10),

            resetBtn.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            resetBtn.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -12),
        ])

        return v
    }

    private func buildGeneralTab() -> NSView {
        let v = NSView()

        // Accessibility status banner

        let axLabel = NSTextField(labelWithString: "")
        axLabel.translatesAutoresizingMaskIntoConstraints = false
        axLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        axLabel.maximumNumberOfLines = 0
        axLabel.lineBreakMode = .byWordWrapping
        axStatusLabel = axLabel

        let axBtn = NSButton(title: "Open Settings", target: self,
                             action: #selector(openAccessibilitySettings))
        axBtn.translatesAutoresizingMaskIntoConstraints = false
        axBtn.bezelStyle = .rounded
        axBtn.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        axOpenBtn = axBtn

        // Stack so the button takes no space while hidden.
        let axStack = NSStackView(views: [axLabel, axBtn])
        axStack.translatesAutoresizingMaskIntoConstraints = false
        axStack.orientation = .vertical
        axStack.alignment = .trailing
        axStack.spacing = 6
        v.addSubview(axStack)

        let divider = NSBox()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.boxType = .separator
        v.addSubview(divider)

        // Preferences

        let speedLabel = NSTextField(labelWithString: "Animation:")
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        speedLabel.textColor = .secondaryLabelColor
        v.addSubview(speedLabel)

        let speedOptions: [AnimationSpeed] = [.off, .faster, .fast, .slow]
        let speedControl = NSSegmentedControl(labels: ["Off", "Faster", "Fast", "Slow"],
                                              trackingMode: .selectOne,
                                              target: self,
                                              action: #selector(speedChanged(_:)))
        speedControl.translatesAutoresizingMaskIntoConstraints = false
        speedControl.selectedSegment = speedOptions.firstIndex(of: BindingStore.shared.animationSpeed) ?? 2
        v.addSubview(speedControl)

        let speedNote = NSTextField(wrappingLabelWithString: "If a window is too slow to keep up, Sizer skips the rest of the animation and jumps straight to the final size.")
        speedNote.translatesAutoresizingMaskIntoConstraints = false
        speedNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        speedNote.textColor = .tertiaryLabelColor
        v.addSubview(speedNote)

        let finderLabel = NSTextField(labelWithString: "Finder sidebar:")
        finderLabel.translatesAutoresizingMaskIntoConstraints = false
        finderLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        finderLabel.textColor = .secondaryLabelColor
        v.addSubview(finderLabel)

        let finderCheck = NSButton(checkboxWithTitle: "Hide if ≥", target: self, action: #selector(finderCheckboxChanged(_:)))
        finderCheck.translatesAutoresizingMaskIntoConstraints = false
        finderCheck.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        finderCheck.state = BindingStore.shared.finderSidebarHideEnabled ? .on : .off
        v.addSubview(finderCheck)
        finderCheckbox = finderCheck

        let finderField = NSTextField()
        finderField.translatesAutoresizingMaskIntoConstraints = false
        finderField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        finderField.stringValue = "\(BindingStore.shared.finderSidebarHideThreshold)"
        finderField.isEnabled = BindingStore.shared.finderSidebarHideEnabled
        finderField.delegate = self
        finderField.placeholderString = "5"
        v.addSubview(finderField)
        finderTextField = finderField

        let finderWindowsLabel = NSTextField(labelWithString: "windows")
        finderWindowsLabel.translatesAutoresizingMaskIntoConstraints = false
        finderWindowsLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        finderWindowsLabel.textColor = .secondaryLabelColor
        v.addSubview(finderWindowsLabel)

        let launchCheck = NSButton(checkboxWithTitle: "Launch at Login",
                                    target: self, action: #selector(launchAtLoginToggled(_:)))
        launchCheck.translatesAutoresizingMaskIntoConstraints = false
        launchCheck.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        AppDelegate.shared?.syncLaunchAtLoginState()
        launchCheck.state = BindingStore.shared.launchAtLogin ? .on : .off
        if #available(macOS 13.0, *) {} else {
            launchCheck.isEnabled = false
            launchCheck.toolTip = "Requires macOS 13 or later"
        }
        v.addSubview(launchCheck)
        launchAtLoginCheckbox = launchCheck

        NSLayoutConstraint.activate([
            axStack.topAnchor.constraint(equalTo: v.topAnchor, constant: 14),
            axStack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            axStack.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),
            axLabel.widthAnchor.constraint(equalTo: axStack.widthAnchor),

            divider.topAnchor.constraint(equalTo: axStack.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),

            speedLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            speedLabel.centerYAnchor.constraint(equalTo: speedControl.centerYAnchor),

            speedControl.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 14),
            speedControl.leadingAnchor.constraint(equalTo: speedLabel.trailingAnchor, constant: 8),

            finderLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            finderLabel.centerYAnchor.constraint(equalTo: finderCheck.centerYAnchor),

            speedNote.topAnchor.constraint(equalTo: speedControl.bottomAnchor, constant: 6),
            speedNote.leadingAnchor.constraint(equalTo: speedControl.leadingAnchor),
            speedNote.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),

            finderCheck.topAnchor.constraint(equalTo: speedNote.bottomAnchor, constant: 14),
            finderCheck.leadingAnchor.constraint(equalTo: finderLabel.trailingAnchor, constant: 8),

            finderField.leadingAnchor.constraint(equalTo: finderCheck.trailingAnchor, constant: 6),
            finderField.centerYAnchor.constraint(equalTo: finderCheck.centerYAnchor),
            finderField.widthAnchor.constraint(equalToConstant: 40),

            finderWindowsLabel.leadingAnchor.constraint(equalTo: finderField.trailingAnchor, constant: 4),
            finderWindowsLabel.centerYAnchor.constraint(equalTo: finderCheck.centerYAnchor),

            launchCheck.topAnchor.constraint(equalTo: finderCheck.bottomAnchor, constant: 14),
            launchCheck.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
        ])

        return v
    }

    private func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        axStatusLabel?.stringValue = trusted ? "✓ Accessibility granted" : "⚠ Accessibility not granted — click Open Settings to reset and re-add Sizer"
        axStatusLabel?.textColor   = trusted ? .systemGreen : .systemOrange
        axOpenBtn?.isHidden        = trusted
    }

    // MARK: Window delegate

    func windowDidBecomeKey(_ notification: Notification) {
        refreshAccessibilityStatus()
        enabledSwitch?.isOn = AppDelegate.shared?.isEnabled ?? true
        enabledSwitch?.needsDisplay = true
        AppDelegate.shared?.syncLaunchAtLoginState()
        launchAtLoginCheckbox?.state = BindingStore.shared.launchAtLogin ? .on : .off
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording(cancelled: true)
    }

    // MARK: Actions

    @objc private func enabledToggled() {
        AppDelegate.shared?.toggleEnabled(nil)
        enabledSwitch?.isOn = AppDelegate.shared?.isEnabled ?? true
    }

    @objc private func openAccessibilitySettings() {
        AppDelegate.shared?.resetAndOpenAccessibilitySettings()
    }

    @objc private func resetDefaults() {
        stopRecording(cancelled: true)
        BindingStore.shared.resetAll()
        tableView.reloadData()
        onHotkeysChanged?()
    }

    @objc private func speedChanged(_ sender: NSSegmentedControl) {
        let speeds: [AnimationSpeed] = [.off, .faster, .fast, .slow]
        guard sender.selectedSegment < speeds.count else { return }
        BindingStore.shared.animationSpeed = speeds[sender.selectedSegment]
    }

    private func sidebarThresholdDescription(_ threshold: Int) -> String {
        threshold == 0 ? "Never hide Finder sidebar" : "Hide Finder sidebar if ≥ \(threshold) windows"
    }

    @objc private func finderCheckboxChanged(_ sender: NSButton) {
        BindingStore.shared.finderSidebarHideEnabled = sender.state == .on
        finderTextField?.isEnabled = sender.state == .on
    }

    @objc private func launchAtLoginToggled(_ sender: NSButton) {
        AppDelegate.shared?.setLaunchAtLogin(sender.state == .on)
        sender.state = BindingStore.shared.launchAtLogin ? .on : .off
    }

    @objc private func finderThresholdChanged(_ sender: NSStepper) {
        BindingStore.shared.finderSidebarHideThreshold = sender.integerValue
    }

    // MARK: Recording

    private func startRecording(row: Int) {
        guard recordingRow != row else { return }
        stopRecording(cancelled: true)
        recordingRow = row
        onStartRecording?()
        refreshShortcutCell(row)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let row = recordingRow else { return }

        if event.keyCode == 53 { stopRecording(cancelled: true); return }

        let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if f.contains(.control) { mods |= UInt32(controlKey) }
        if f.contains(.option)  { mods |= UInt32(optionKey)  }
        if f.contains(.shift)   { mods |= UInt32(shiftKey)   }
        if f.contains(.command) { mods |= UInt32(cmdKey)     }
        guard mods != 0 else { return }

        BindingStore.shared.save(
            id: BindingStore.shared.definitions[row].id,
            keyCode: UInt32(event.keyCode),
            modifiers: mods
        )
        stopRecording(cancelled: false)
        refreshShortcutCell(row)
        onHotkeysChanged?()
    }

    private func stopRecording(cancelled: Bool) {
        let wasRecording = recordingRow != nil
        let prevRow = recordingRow
        recordingRow = nil

        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        guard wasRecording else { return }

        onStopRecording?()
        if cancelled, let row = prevRow { refreshShortcutCell(row) }
    }

    private func refreshShortcutCell(_ row: Int) {
        tableView.reloadData(forRowIndexes: IndexSet(integer: row),
                             columnIndexes: IndexSet(integer: 1))
    }
}

// MARK: - Table data source / delegate

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === finderTextField else { return }
        let v = max(1, Int(field.stringValue) ?? BindingStore.shared.finderSidebarHideThreshold)
        BindingStore.shared.finderSidebarHideThreshold = v
        field.stringValue = "\(v)"
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        BindingStore.shared.definitions.count
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let def = BindingStore.shared.definitions[row]

        switch tableColumn?.identifier.rawValue {
        case "action":
            let cell = NSTableCellView()
            let tf = NSTextField(labelWithString: def.label)
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf); cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell

        case "shortcut":
            let cell = NSTableCellView()
            let isRec = recordingRow == row
            let btn = NSButton(title: "", target: self, action: #selector(shortcutTapped(_:)))
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.tag = row
            btn.bezelStyle = .roundRect
            btn.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

            if isRec {
                btn.attributedTitle = NSAttributedString(
                    string: "Type shortcut…",
                    attributes: [.foregroundColor: NSColor.placeholderTextColor,
                                 .font: NSFont.systemFont(ofSize: 12, weight: .light)]
                )
            } else {
                let shortcut = formatShortcut(
                    keyCode:   BindingStore.shared.keyCode(for: def.id),
                    modifiers: BindingStore.shared.modifiers(for: def.id)
                )
                btn.attributedTitle = NSAttributedString(
                    string: shortcut,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                        .kern: 2.5,
                    ]
                )
            }

            cell.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                btn.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            ])
            return cell

        default: return nil
        }
    }

    @objc private func shortcutTapped(_ sender: NSButton) {
        startRecording(row: sender.tag)
    }
}
