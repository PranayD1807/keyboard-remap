import SwiftUI
import AppKit
import IOKit.hid

struct DeviceConfig: Codable, Identifiable, Equatable {
    var id: String { "\(vendor_id)-\(product_id ?? 0)" }
    var name: String?
    var vendor_id: Int
    var product_id: Int?
    var remap: [String: String]
}

struct RootConfig: Codable {
    var devices: [DeviceConfig]
}

struct DetectedKeyboard: Identifiable, Hashable {
    var id: String { "\(vendorID)-\(productID)" }
    let name: String
    let vendorID: Int
    let productID: Int
    let transport: String
    let isBuiltIn: Bool
    
    var displayName: String {
        let tag = isBuiltIn ? " [Built-in]" : (transport.isEmpty ? "" : " [\(transport)]")
        return "\(name)\(tag)"
    }
}

struct KeyCatalogItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
}

let fullKeyCatalog: [KeyCatalogItem] = [
    // Modifiers
    KeyCatalogItem(id: "left_command", name: "Left Command (⌘)", category: "Modifiers"),
    KeyCatalogItem(id: "left_option", name: "Left Option / Alt (⌥)", category: "Modifiers"),
    KeyCatalogItem(id: "left_control", name: "Left Control (⌃)", category: "Modifiers"),
    KeyCatalogItem(id: "left_shift", name: "Left Shift (⇧)", category: "Modifiers"),
    KeyCatalogItem(id: "right_command", name: "Right Command (⌘)", category: "Modifiers"),
    KeyCatalogItem(id: "right_option", name: "Right Option / Alt (⌥)", category: "Modifiers"),
    KeyCatalogItem(id: "right_control", name: "Right Control (⌃)", category: "Modifiers"),
    KeyCatalogItem(id: "right_shift", name: "Right Shift (⇧)", category: "Modifiers"),
    KeyCatalogItem(id: "caps_lock", name: "Caps Lock", category: "Modifiers"),

    // Editing
    KeyCatalogItem(id: "escape", name: "Escape", category: "Editing"),
    KeyCatalogItem(id: "return", name: "Return / Enter", category: "Editing"),
    KeyCatalogItem(id: "tab", name: "Tab", category: "Editing"),
    KeyCatalogItem(id: "space", name: "Space", category: "Editing"),
    KeyCatalogItem(id: "backspace", name: "Backspace / Delete", category: "Editing"),
    KeyCatalogItem(id: "forward_delete", name: "Forward Delete", category: "Editing"),

    // Navigation
    KeyCatalogItem(id: "home", name: "Home", category: "Navigation"),
    KeyCatalogItem(id: "end", name: "End", category: "Navigation"),
    KeyCatalogItem(id: "page_up", name: "Page Up", category: "Navigation"),
    KeyCatalogItem(id: "page_down", name: "Page Down", category: "Navigation"),
    KeyCatalogItem(id: "insert", name: "Insert", category: "Navigation"),
    KeyCatalogItem(id: "print_screen", name: "Print Screen", category: "Navigation"),
    KeyCatalogItem(id: "scroll_lock", name: "Scroll Lock", category: "Navigation"),
    KeyCatalogItem(id: "pause_break", name: "Pause / Break", category: "Navigation"),
    KeyCatalogItem(id: "left_arrow", name: "Left Arrow", category: "Navigation"),
    KeyCatalogItem(id: "right_arrow", name: "Right Arrow", category: "Navigation"),
    KeyCatalogItem(id: "up_arrow", name: "Up Arrow", category: "Navigation"),
    KeyCatalogItem(id: "down_arrow", name: "Down Arrow", category: "Navigation"),

    // Function Keys
    KeyCatalogItem(id: "f1", name: "F1", category: "Function"),
    KeyCatalogItem(id: "f2", name: "F2", category: "Function"),
    KeyCatalogItem(id: "f3", name: "F3", category: "Function"),
    KeyCatalogItem(id: "f4", name: "F4", category: "Function"),
    KeyCatalogItem(id: "f5", name: "F5", category: "Function"),
    KeyCatalogItem(id: "f6", name: "F6", category: "Function"),
    KeyCatalogItem(id: "f7", name: "F7", category: "Function"),
    KeyCatalogItem(id: "f8", name: "F8", category: "Function"),
    KeyCatalogItem(id: "f9", name: "F9", category: "Function"),
    KeyCatalogItem(id: "f10", name: "F10", category: "Function"),
    KeyCatalogItem(id: "f11", name: "F11", category: "Function"),
    KeyCatalogItem(id: "f12", name: "F12", category: "Function"),

    // Media
    KeyCatalogItem(id: "volume_up", name: "Volume Up", category: "Media"),
    KeyCatalogItem(id: "volume_down", name: "Volume Down", category: "Media"),
    KeyCatalogItem(id: "mute", name: "Mute", category: "Media"),
    KeyCatalogItem(id: "play_pause", name: "Play / Pause", category: "Media"),
    KeyCatalogItem(id: "next_track", name: "Next Track", category: "Media"),
    KeyCatalogItem(id: "prev_track", name: "Previous Track", category: "Media")
]

struct CustomRuleItem: Identifiable, Equatable {
    var id = UUID()
    var fromKey: String
    var toKey: String
}

class SettingsViewModel: ObservableObject {
    @Published var detectedKeyboards: [DetectedKeyboard] = []
    @Published var selectedKeyboardID: String = ""
    
    // Quick Modifiers
    @Published var leftAlt: String = "default"
    @Published var leftWin: String = "default"
    @Published var rightAlt: String = "default"
    @Published var rightWin: String = "default"
    @Published var capsLock: String = "default"
    
    // Custom key rules
    @Published var customRules: [CustomRuleItem] = []
    
    @Published var isDaemonRunning: Bool = false
    @Published var statusMessage: String = ""
    
    let configURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/keyboard-remap/config.json")
    }()
    
    var rawConfig: RootConfig = RootConfig(devices: [])
    
    init() {
        refreshDevices()
        loadConfig()
        checkDaemon()
    }
    
    func refreshDevices() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 1,
            kIOHIDDeviceUsageKey: 6
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return
        }
        
        var list: [DetectedKeyboard] = []
        for dev in set {
            let name = (IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String) ?? "Unknown Keyboard"
            let vendor = (IOHIDDeviceGetProperty(dev, kIOHIDVendorIDKey as CFString) as? Int) ?? 0
            let product = (IOHIDDeviceGetProperty(dev, kIOHIDProductIDKey as CFString) as? Int) ?? 0
            let transport = (IOHIDDeviceGetProperty(dev, kIOHIDTransportKey as CFString) as? String) ?? ""
            let isBuiltIn = (IOHIDDeviceGetProperty(dev, "Built-In" as CFString) as? Bool) ?? (transport == "FIFO" || name.contains("Internal"))
            
            let kb = DetectedKeyboard(
                name: name,
                vendorID: vendor,
                productID: product,
                transport: transport,
                isBuiltIn: isBuiltIn
            )
            if !list.contains(where: { $0.id == kb.id }) {
                list.append(kb)
            }
        }
        
        list.sort { !$0.isBuiltIn && $1.isBuiltIn }
        self.detectedKeyboards = list
        if selectedKeyboardID.isEmpty, let firstExternal = list.first(where: { !$0.isBuiltIn }) ?? list.first {
            self.selectedKeyboardID = firstExternal.id
        }
    }
    
    func checkDaemon() {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        DispatchQueue.main.async {
            self.isDaemonRunning = output.contains("com.pranay.keyboard-remap") || output.contains("com.pranay.lenovo-key-remap")
        }
    }
    
    func loadConfig() {
        guard let data = try? Data(contentsOf: configURL),
              let decoded = try? JSONDecoder().decode(RootConfig.self, from: data) else {
            return
        }
        self.rawConfig = decoded
        selectDevice(id: selectedKeyboardID)
    }
    
    func selectDevice(id: String) {
        self.selectedKeyboardID = id
        if let dev = rawConfig.devices.first(where: { "\($0.vendor_id)-\($0.product_id ?? 0)" == id }) {
            self.leftAlt = dev.remap["left_alt"] ?? "default"
            self.leftWin = dev.remap["left_win"] ?? "default"
            self.rightAlt = dev.remap["right_alt"] ?? "default"
            self.rightWin = dev.remap["right_win"] ?? "default"
            self.capsLock = dev.remap["caps_lock"] ?? "default"
            
            // Extract custom rules
            let modifierKeys = Set(["left_alt", "left_win", "right_alt", "right_win", "caps_lock"])
            var custom: [CustomRuleItem] = []
            for (k, v) in dev.remap where !modifierKeys.contains(k) {
                custom.append(CustomRuleItem(fromKey: k, toKey: v))
            }
            self.customRules = custom
        } else {
            self.leftAlt = "default"
            self.leftWin = "default"
            self.rightAlt = "default"
            self.rightWin = "default"
            self.capsLock = "default"
            self.customRules = []
        }
    }
    
    func addCustomRule() {
        customRules.append(CustomRuleItem(fromKey: "f1", toKey: "play_pause"))
    }
    
    func removeCustomRule(id: UUID) {
        customRules.removeAll(where: { $0.id == id })
    }
    
    func applyPresetWindowsToMac() {
        self.leftAlt = "left_command"
        self.leftWin = "left_option"
        self.rightAlt = "right_command"
        self.rightWin = "right_option"
        statusMessage = "Preset applied (Click Save & Apply)"
    }
    
    func resetToDefaults() {
        self.leftAlt = "default"
        self.leftWin = "default"
        self.rightAlt = "default"
        self.rightWin = "default"
        self.capsLock = "default"
        self.customRules = []
        statusMessage = "Reset to default (Click Save & Apply)"
    }
    
    func saveConfig() {
        guard let kb = detectedKeyboards.first(where: { $0.id == selectedKeyboardID }) else {
            statusMessage = "No keyboard selected"
            return
        }
        
        var remapDict: [String: String] = [:]
        if leftAlt != "default" { remapDict["left_alt"] = leftAlt }
        if leftWin != "default" { remapDict["left_win"] = leftWin }
        if rightAlt != "default" { remapDict["right_alt"] = rightAlt }
        if rightWin != "default" { remapDict["right_win"] = rightWin }
        if capsLock != "default" { remapDict["caps_lock"] = capsLock }
        
        for rule in customRules {
            let from = rule.fromKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let to = rule.toKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !from.isEmpty && !to.isEmpty && to != "default" {
                remapDict[from] = to
            }
        }
        
        var updatedDevices = rawConfig.devices
        if let idx = updatedDevices.firstIndex(where: { $0.vendor_id == kb.vendorID && ($0.product_id ?? 0) == kb.productID }) {
            if remapDict.isEmpty {
                updatedDevices.remove(at: idx)
            } else {
                updatedDevices[idx].name = kb.name
                updatedDevices[idx].remap = remapDict
            }
        } else if !remapDict.isEmpty {
            updatedDevices.append(DeviceConfig(
                name: kb.name,
                vendor_id: kb.vendorID,
                product_id: kb.productID,
                remap: remapDict
            ))
        }
        
        let root = RootConfig(devices: updatedDevices)
        self.rawConfig = root
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(root) else {
            statusMessage = "Error encoding settings"
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: configURL, options: .atomic)
            statusMessage = "Settings saved & applied for \(kb.name)!"
            checkDaemon()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.statusMessage.contains("Settings saved & applied") {
                    self.statusMessage = ""
                }
            }
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
    
    func openJSONFile() {
        NSWorkspace.shared.open(configURL)
    }
    
    func restartDaemon() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let plistPath = "\(home)/Library/LaunchAgents/com.pranay.keyboard-remap.plist"
        let legacyPlistPath = "\(home)/Library/LaunchAgents/com.pranay.lenovo-key-remap.plist"
        let path = FileManager.default.fileExists(atPath: plistPath) ? plistPath : legacyPlistPath
        
        let unload = Process()
        unload.launchPath = "/bin/launchctl"
        unload.arguments = ["unload", path]
        try? unload.run()
        unload.waitUntilExit()
        
        let load = Process()
        load.launchPath = "/bin/launchctl"
        load.arguments = ["load", path]
        try? load.run()
        load.waitUntilExit()
        
        statusMessage = "Daemon reloaded"
        checkDaemon()
    }
}

let modifierOptions: [(id: String, label: String)] = [
    ("default", "Default (Unmapped)"),
    ("left_command", "Command (⌘)"),
    ("left_option", "Option (⌥)"),
    ("left_control", "Control (⌃)"),
    ("caps_lock", "Caps Lock"),
    ("escape", "Escape")
]

let appVersion = "0.0.1-beta"

struct ContentView: View {
    @ObservedObject var vm: SettingsViewModel
    
    var currentKeyboard: DetectedKeyboard? {
        vm.detectedKeyboards.first(where: { $0.id == vm.selectedKeyboardID })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Keyboard Remap Settings")
                            .font(.system(size: 16, weight: .bold))
                        Text("v\(appVersion)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text("Auto-detect and remap any key on any keyboard")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.isDaemonRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(vm.isDaemonRunning ? "Daemon Active" : "Daemon Stopped")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Keyboard Selection Section
                    GroupBox(label: Label("Detected Keyboards", systemImage: "keyboard")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Picker("Select Device:", selection: Binding(
                                    get: { vm.selectedKeyboardID },
                                    set: { newID in vm.selectDevice(id: newID) }
                                )) {
                                    ForEach(vm.detectedKeyboards) { kb in
                                        Text(kb.displayName).tag(kb.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Button(action: { vm.refreshDevices() }) {
                                    Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            if let kb = currentKeyboard {
                                HStack(spacing: 12) {
                                    Text("Vendor ID: \(kb.vendorID) (0x\(String(kb.vendorID, radix: 16)))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text("Product ID: \(kb.productID) (0x\(String(kb.productID, radix: 16)))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text("Transport: \(kb.transport.isEmpty ? "Unknown" : kb.transport)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(8)
                    }
                    
                    // Modifier Mappings Section
                    GroupBox(label: Label("Quick Modifiers", systemImage: "slider.horizontal.3")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Standard modifier key swaps:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                Button("Swap Alt ↔ Cmd, Win ↔ Opt") {
                                    vm.applyPresetWindowsToMac()
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 11))
                                
                                Text("|").foregroundColor(.secondary)
                                
                                Button("Reset") {
                                    vm.resetToDefaults()
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 11))
                            }
                            .padding(.bottom, 2)
                            
                            Divider()
                            
                            quickPickerRow(title: "Left Alt (Option)", selection: $vm.leftAlt)
                            quickPickerRow(title: "Left Windows (Command)", selection: $vm.leftWin)
                            quickPickerRow(title: "Right Alt (Option)", selection: $vm.rightAlt)
                            quickPickerRow(title: "Right Windows (Command)", selection: $vm.rightWin)
                            quickPickerRow(title: "Caps Lock", selection: $vm.capsLock)
                        }
                        .padding(8)
                    }
                    
                    // Custom Any-Key Remappings Section
                    GroupBox(label: Label("Custom Key Remappings (Any Key → Any Key)", systemImage: "arrow.triangle.swap")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Remap any function key, navigation key, or editing key:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                Button(action: { vm.addCustomRule() }) {
                                    Label("Add Remap", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            if vm.customRules.isEmpty {
                                Text("No custom key rules added yet. Click '+ Add Remap' to remap any key (e.g. F1 → Play/Pause, Insert → Forward Delete).")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 6)
                            } else {
                                Divider()
                                
                                ForEach($vm.customRules) { $rule in
                                    HStack(spacing: 8) {
                                        // Source Key Picker
                                        Picker("", selection: $rule.fromKey) {
                                            ForEach(fullKeyCatalog) { item in
                                                Text("\(item.name) (\(item.category))").tag(item.id)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity)
                                        
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 11))
                                        
                                        // Destination Key Picker
                                        Picker("", selection: $rule.toKey) {
                                            Text("None / Disabled").tag("default")
                                            ForEach(fullKeyCatalog) { item in
                                                Text("\(item.name) (\(item.category))").tag(item.id)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity)
                                        
                                        // Delete Button
                                        Button(action: { vm.removeCustomRule(id: rule.id) }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                        .padding(.leading, 4)
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                    
                    if !vm.statusMessage.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(vm.statusMessage)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button(action: { vm.openJSONFile() }) {
                    Label("Open config.json", systemImage: "doc.text")
                }
                .buttonStyle(.link)
                
                Button(action: { vm.restartDaemon() }) {
                    Label("Restart Daemon", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.link)
                
                Spacer()
                
                Button("Save & Apply") {
                    vm.saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 560)
    }
    
    func quickPickerRow(title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .frame(width: 190, alignment: .leading)
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            Spacer()
            
            Picker("", selection: selection) {
                ForEach(modifierOptions, id: \.id) { opt in
                    Text(opt.label).tag(opt.id)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let vm = SettingsViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Keyboard Remap Settings"
        window.contentView = NSHostingView(rootView: ContentView(vm: vm))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
