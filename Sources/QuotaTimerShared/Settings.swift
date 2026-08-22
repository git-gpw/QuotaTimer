import Foundation
import Observation

public enum AppAppearance: String, Sendable, CaseIterable {
    case system
    case light
    case dark
}

@Observable
@MainActor
public final class AppSettings {
    private let defaults: UserDefaults

    public var thresholds: Set<Int> {
        didSet { saveThresholds() }
    }

    public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    public var pollInterval: TimeInterval {
        didSet { defaults.set(pollInterval, forKey: "pollInterval") }
    }

    public var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }

    public var pomodoroEnabled: Bool {
        didSet { defaults.set(pomodoroEnabled, forKey: "pomodoroEnabled") }
    }

    public var claudeEnabled: Bool {
        didSet { defaults.set(claudeEnabled, forKey: "claudeEnabled") }
    }

    public var codexEnabled: Bool {
        didSet { defaults.set(codexEnabled, forKey: "codexEnabled") }
    }

    public var showTimerWidget: Bool {
        didSet { defaults.set(showTimerWidget, forKey: "showTimerWidget") }
    }

    public var showUsageWidget: Bool {
        didSet { defaults.set(showUsageWidget, forKey: "showUsageWidget") }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let stored = defaults.array(forKey: "thresholds") as? [Int] {
            self.thresholds = Set(stored)
        } else {
            self.thresholds = [50, 75, 90]
        }

        if defaults.object(forKey: "launchAtLogin") != nil {
            self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        } else {
            self.launchAtLogin = false
        }

        if defaults.object(forKey: "pollInterval") != nil {
            self.pollInterval = defaults.double(forKey: "pollInterval")
        } else {
            self.pollInterval = 180
        }

        if let raw = defaults.string(forKey: "appearance"),
           let val = AppAppearance(rawValue: raw) {
            self.appearance = val
        } else {
            self.appearance = .system
        }

        if defaults.object(forKey: "pomodoroEnabled") != nil {
            self.pomodoroEnabled = defaults.bool(forKey: "pomodoroEnabled")
        } else {
            self.pomodoroEnabled = true
        }

        if defaults.object(forKey: "claudeEnabled") != nil {
            self.claudeEnabled = defaults.bool(forKey: "claudeEnabled")
        } else {
            self.claudeEnabled = true
        }

        if defaults.object(forKey: "codexEnabled") != nil {
            self.codexEnabled = defaults.bool(forKey: "codexEnabled")
        } else {
            self.codexEnabled = true
        }

        self.showTimerWidget = defaults.bool(forKey: "showTimerWidget")
        self.showUsageWidget = defaults.bool(forKey: "showUsageWidget")
    }

    public func isThresholdEnabled(_ level: Int) -> Bool {
        thresholds.contains(level)
    }

    public func toggleThreshold(_ level: Int) {
        if thresholds.contains(level) {
            thresholds.remove(level)
        } else {
            thresholds.insert(level)
        }
    }

    private func saveThresholds() {
        defaults.set(Array(thresholds).sorted(), forKey: "thresholds")
    }
}
