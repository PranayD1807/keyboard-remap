import Foundation
import IOKit.hid
import AppKit

let home = FileManager.default.homeDirectoryForCurrentUser.path
let appVersion = "0.0.2-beta"
let configPath = (home as NSString).appendingPathComponent(".config/keyboard-remap/config.json")
let configDir = (home as NSString).appendingPathComponent(".config/keyboard-remap")

// Comprehensive Key Aliases Table (USB HID Keyboard & Consumer Usage Page)
var keyAliases: [String: UInt64] = [
    // Modifiers
    "left_ctrl": 0x7000000E0,
    "left_control": 0x7000000E0,
    "left_shift": 0x7000000E1,
    "left_alt": 0x7000000E2,
    "left_option": 0x7000000E2,
    "left_opt": 0x7000000E2,
    "left_gui": 0x7000000E3,
    "left_cmd": 0x7000000E3,
    "left_command": 0x7000000E3,
    "left_win": 0x7000000E3,
    "left_windows": 0x7000000E3,

    "right_ctrl": 0x7000000E4,
    "right_control": 0x7000000E4,
    "right_shift": 0x7000000E5,
    "right_alt": 0x7000000E6,
    "right_option": 0x7000000E6,
    "right_opt": 0x7000000E6,
    "right_gui": 0x7000000E7,
    "right_cmd": 0x7000000E7,
    "right_command": 0x7000000E7,
    "right_win": 0x7000000E7,
    "right_windows": 0x7000000E7,

    "caps_lock": 0x700000039,
    "capslock": 0x700000039,

    // Editing & Common
    "escape": 0x700000029,
    "esc": 0x700000029,
    "return": 0x700000028,
    "enter": 0x700000028,
    "tab": 0x70000002B,
    "space": 0x70000002C,
    "backspace": 0x70000002A,
    "delete": 0x70000002A,
    "forward_delete": 0x70000004C,
    "del": 0x70000004C,

    // Navigation & Control
    "left_arrow": 0x700000050,
    "right_arrow": 0x70000004F,
    "up_arrow": 0x700000052,
    "down_arrow": 0x700000051,
    "home": 0x70000004A,
    "end": 0x70000004D,
    "page_up": 0x70000004B,
    "pageup": 0x70000004B,
    "page_down": 0x70000004E,
    "pagedown": 0x70000004E,
    "insert": 0x700000049,
    "ins": 0x700000049,
    "print_screen": 0x700000046,
    "printscreen": 0x700000046,
    "prtscn": 0x700000046,
    "scroll_lock": 0x700000047,
    "pause_break": 0x700000048,
    "pause": 0x700000048,

    // Function keys
    "f1": 0x70000003A, "f2": 0x70000003B, "f3": 0x70000003C, "f4": 0x70000003D,
    "f5": 0x70000003E, "f6": 0x70000003F, "f7": 0x700000040, "f8": 0x700000041,
    "f9": 0x700000042, "f10": 0x700000043, "f11": 0x700000044, "f12": 0x700000045,
    "f13": 0x700000068, "f14": 0x700000069, "f15": 0x70000006A, "f16": 0x70000006B,
    "f17": 0x70000006C, "f18": 0x70000006D, "f19": 0x70000006E, "f20": 0x70000006F,

    // Media & Consumer Controls
    "volume_up": 0x000C00E9,
    "volume_down": 0x000C00EA,
    "mute": 0x000C00E2,
    "play_pause": 0x000C00CD,
    "next_track": 0x000C00B5,
    "prev_track": 0x000C00B6,
    "previous_track": 0x000C00B6,

    // Punctuation & Symbols
    "grave_tilde": 0x700000035, "tilde": 0x700000035, "grave": 0x700000035,
    "minus": 0x70000002D, "equal": 0x70000002E,
    "left_bracket": 0x70000002F, "right_bracket": 0x700000030,
    "backslash": 0x700000031, "semicolon": 0x700000033, "quote": 0x700000034,
    "comma": 0x700000036, "period": 0x700000037, "slash": 0x700000038
]

// Add letters a-z and numbers 0-9
do {
    // a-z: 0x04 - 0x1D
    for i in 0..<26 {
        let char = String(UnicodeScalar(UInt8(ascii: "a") + UInt8(i)))
        keyAliases[char] = 0x700000004 + UInt64(i)
    }
    // 1-9: 0x1E - 0x26, 0: 0x27
    for i in 1...9 {
        keyAliases["\(i)"] = 0x70000001E + UInt64(i - 1)
    }
    keyAliases["0"] = 0x700000027
}

func parseKey(_ str: String) -> UInt64? {
    let lower = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let hid = keyAliases[lower] {
        return hid
    }
    if lower.hasPrefix("0x"), let val = UInt64(lower.dropFirst(2), radix: 16) {
        return val
    }
    if let val = UInt64(lower) {
        return val
    }
    return nil
}

func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    print("[\(formatter.string(from: Date()))] \(message)")
    fflush(stdout)
}

struct DeviceConfig: Codable {
    let name: String?
    let vendor_id: Int
    let product_id: Int?
    let remap: [String: String]
}

struct RootConfig: Codable {
    let devices: [DeviceConfig]
}

struct ParsedMapping {
    let name: String
    let vendorID: Int
    let productID: Int?
    let rawArray: [[String: UInt64]]
    let jsonString: String
}

var currentMappings: [ParsedMapping] = []
var hidManager: IOHIDManager? = nil

func loadConfig() -> Bool {
    guard FileManager.default.fileExists(atPath: configPath) else {
        log("Config file not found at \(configPath)")
        return false
    }
    
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let root = try JSONDecoder().decode(RootConfig.self, from: data)
        
        var newMappings: [ParsedMapping] = []
        for dev in root.devices {
            var rawList: [[String: UInt64]] = []
            var jsonItems: [String] = []
            
            for (srcStr, dstStr) in dev.remap {
                guard let src = parseKey(srcStr), let dst = parseKey(dstStr) else {
                    log("Warning: Unknown key mapping '\(srcStr)' -> '\(dstStr)'")
                    continue
                }
                rawList.append([
                    "HIDKeyboardModifierMappingSrc": src,
                    "HIDKeyboardModifierMappingDst": dst
                ])
                jsonItems.append("{\"HIDKeyboardModifierMappingSrc\":\(src),\"HIDKeyboardModifierMappingDst\":\(dst)}")
            }
            
            let jsonPayload = "{\"UserKeyMapping\":[" + jsonItems.joined(separator: ",") + "]}"
            newMappings.append(ParsedMapping(
                name: dev.name ?? "Device",
                vendorID: dev.vendor_id,
                productID: dev.product_id,
                rawArray: rawList,
                jsonString: jsonPayload
            ))
        }
        
        currentMappings = newMappings
        return true
    } catch {
        log("Error loading config.json: \(error.localizedDescription)")
        return false
    }
}

func applyAllMappings(reason: String) {
    for mapping in currentMappings {
        var matchDictStr = "{\"VendorID\":\(mapping.vendorID),\"PrimaryUsagePage\":1,\"PrimaryUsage\":6"
        if let pid = mapping.productID, pid > 0 {
            matchDictStr += ",\"ProductID\":\(pid)"
        }
        matchDictStr += "}"
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = ["property", "--matching", matchDictStr, "--set", mapping.jsonString]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
    }
    
    if reason != "periodic check" {
        log("Remappings applied (\(reason)) for \(currentMappings.count) device(s)")
    }
}

func setupHIDManager() {
    if let old = hidManager {
        IOHIDManagerClose(old, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    var matchArray: [[String: Any]] = []
    
    for mapping in currentMappings {
        var dict: [String: Any] = [
            kIOHIDVendorIDKey: mapping.vendorID,
            kIOHIDDeviceUsagePageKey: 1,
            kIOHIDDeviceUsageKey: 6
        ]
        if let pid = mapping.productID, pid > 0 {
            dict[kIOHIDProductIDKey] = pid
        }
        matchArray.append(dict)
    }
    
    if !matchArray.isEmpty {
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchArray as CFArray)
    }
    
    let matchedCallback: IOHIDDeviceCallback = { context, result, sender, device in
        applyAllMappings(reason: "device connected/reconnected")
    }
    
    IOHIDManagerRegisterDeviceMatchingCallback(manager, matchedCallback, nil)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    hidManager = manager
}

log("Starting Keyboard Remap Daemon v\(appVersion) (listening to ~/.config/keyboard-remap/config.json)")

if loadConfig() {
    setupHIDManager()
    applyAllMappings(reason: "startup")
}

// Watchers for config changes
var lastMTime: Date? = {
    let attrs = try? FileManager.default.attributesOfItem(atPath: configPath)
    return attrs?[.modificationDate] as? Date
}()

func reloadIfChanged(reason: String) {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: configPath),
          let mtime = attrs[.modificationDate] as? Date else { return }
    if lastMTime == nil || mtime != lastMTime {
        lastMTime = mtime
        log("Detected change in config.json (\(reason)). Reloading...")
        if loadConfig() {
            setupHIDManager()
            applyAllMappings(reason: "config.json updated")
        }
    }
}

// 1. File watcher
var fileFD: Int32 = -1
var fileSource: DispatchSourceFileSystemObject? = nil

func watchConfigFile() {
    if fileFD >= 0 {
        fileSource?.cancel()
        close(fileFD)
        fileFD = -1
    }
    fileFD = open(configPath, O_EVTONLY)
    if fileFD >= 0 {
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileFD,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: .main
        )
        s.setEventHandler {
            let flags = s.data
            reloadIfChanged(reason: "file event")
            if flags.contains(.delete) || flags.contains(.rename) {
                // Editor performed atomic swap, re-arm watcher after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    watchConfigFile()
                }
            }
        }
        s.resume()
        fileSource = s
    }
}
watchConfigFile()

// 2. Directory watcher (catches atomic renames from editors)
let dirFD = open(configDir, O_EVTONLY)
if dirFD >= 0 {
    let dirSource = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: dirFD,
        eventMask: [.write, .extend, .attrib],
        queue: .main
    )
    dirSource.setEventHandler {
        reloadIfChanged(reason: "directory event")
    }
    dirSource.resume()
}

// 3. Fast poll check (every 1s) as guaranteed fallback
let pollTimer = DispatchSource.makeTimerSource(queue: .main)
pollTimer.schedule(deadline: .now() + 1, repeating: 1.0)
pollTimer.setEventHandler {
    reloadIfChanged(reason: "poll check")
}
pollTimer.resume()

// 4. System wake notification
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil,
    queue: .main
) { _ in
    applyAllMappings(reason: "system wake")
}

// 5. Periodic hardware re-enforce every 30 seconds
let enforceTimer = DispatchSource.makeTimerSource(queue: .main)
enforceTimer.schedule(deadline: .now() + 30, repeating: 30.0)
enforceTimer.setEventHandler {
    applyAllMappings(reason: "periodic check")
}
enforceTimer.resume()

RunLoop.main.run()
