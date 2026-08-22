import Foundation

public enum LaunchAtLogin {
    private static let plistName = "com.quotatimer.launcher.plist"

    private static var launchAgentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    private static var plistURL: URL {
        launchAgentsDir.appendingPathComponent(plistName)
    }

    public static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    public static func enable() throws {
        let executablePath = ProcessInfo.processInfo.arguments[0]
        let resolvedPath: String
        if executablePath.hasPrefix("/") {
            resolvedPath = executablePath
        } else {
            resolvedPath = FileManager.default.currentDirectoryPath + "/" + executablePath
        }

        let plist: [String: Any] = [
            "Label": "com.quotatimer.launcher",
            "ProgramArguments": [resolvedPath],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    public static func disable() throws {
        guard isEnabled else { return }
        try FileManager.default.removeItem(at: plistURL)
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    public static func generatePlistContent(executablePath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.quotatimer.launcher</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
    }
}
