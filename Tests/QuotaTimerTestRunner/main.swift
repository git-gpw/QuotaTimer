import Foundation
import QuotaTimerShared

nonisolated(unsafe) var passed = 0
nonisolated(unsafe) var failed = 0

func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("  FAIL [\(file):\(line)] \(message)")
    }
}

func fixture(_ name: String) -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try! Data(contentsOf: url)
}

// --- Test: Decode full success payload ---
do {
    print("Test: Decode full success payload")
    let data = fixture("usage_success")
    let r = try JSONDecoder().decode(UsageResponse.self, from: data)

    check(r.fiveHour?.utilization == 42.0, "fiveHour.utilization == 42.0")
    check(r.fiveHour?.resetsAt == "2025-06-10T14:30:00Z", "fiveHour.resetsAt")
    check(r.sevenDay?.utilization == 65.0, "sevenDay.utilization == 65.0")
    check(r.sevenDayOpus?.utilization == 30.0, "sevenDayOpus.utilization == 30.0")
    check(r.sevenDaySonnet?.utilization == 50.0, "sevenDaySonnet.utilization == 50.0")
    check(r.sevenDayDesign?.utilization == 0.0, "sevenDayDesign.utilization == 0.0")
    check(r.sevenDayFable?.utilization == 0.0, "sevenDayFable.utilization == 0.0")
    check(r.sevenDayFable?.resetsAt == nil, "sevenDayFable.resetsAt is null")
    check(r.nimbus_quill == nil, "nimbus_quill is null")

    let limits = r.limits!
    check(limits.count == 3, "limits.count == 3")
    check(limits[0].kind == "session", "limits[0].kind == session")
    check(limits[0].group == "session", "limits[0].group == session")
    check(limits[0].percent == 42, "limits[0].percent == 42")
    check(limits[0].isActive == true, "limits[0].isActive == true")
    check(limits[0].scope?.model?.id == "claude-opus-4", "limits[0].scope.model.id")
    check(limits[0].scope?.model?.displayName == "Claude Opus 4", "limits[0].scope.model.displayName")
    check(limits[1].kind == "weekly_all", "limits[1].kind == weekly_all")
    check(limits[1].scope == nil, "limits[1].scope is null")
    check(limits[2].scope?.model?.id == nil, "limits[2].scope.model.id is null")
    check(limits[2].scope?.model?.displayName == "Fable", "limits[2].scope.model.displayName == Fable")
    check(limits[2].resetsAt == nil, "limits[2].resetsAt is null")
}

// --- Test: Decode empty limits ---
do {
    print("Test: Decode empty limits")
    let data = fixture("usage_empty_limits")
    let r = try JSONDecoder().decode(UsageResponse.self, from: data)

    check(r.fiveHour?.utilization == 0.0, "fiveHour.utilization == 0.0")
    check(r.fiveHour?.resetsAt == nil, "fiveHour.resetsAt is null")
    check(r.sevenDay?.utilization == 2.0, "sevenDay.utilization == 2.0")
    check(r.limits?.count == 0, "limits is empty array")
    check(r.sevenDayOpus == nil, "sevenDayOpus is nil")
    check(r.sevenDaySonnet == nil, "sevenDaySonnet is nil")
}

// --- Test: Decode minimal payload ---
do {
    print("Test: Decode minimal payload (only five_hour)")
    let data = fixture("usage_minimal")
    let r = try JSONDecoder().decode(UsageResponse.self, from: data)

    check(r.fiveHour?.utilization == 0.99, "fiveHour.utilization == 0.99")
    check(r.sevenDay == nil, "sevenDay is nil")
    check(r.limits == nil, "limits is nil")
}

// --- Test: Malformed payload throws ---
do {
    print("Test: Malformed payload throws DecodingError")
    let data = fixture("usage_malformed")
    var threw = false
    do {
        _ = try JSONDecoder().decode(UsageResponse.self, from: data)
    } catch is DecodingError {
        threw = true
    }
    check(threw, "should throw DecodingError")
}

// --- Test: Garbage data throws ---
do {
    print("Test: Garbage data throws")
    let data = Data("not json at all".utf8)
    var threw = false
    do {
        _ = try JSONDecoder().decode(UsageResponse.self, from: data)
    } catch {
        threw = true
    }
    check(threw, "should throw on garbage input")
}

// ============================================================
// KeychainReader JSON parsing tests (no actual Keychain access)
// ============================================================

let reader = KeychainReader()

// --- Test: Parse valid credential JSON ---
do {
    print("Test: Parse valid credential JSON")
    let json = String(data: fixture("credential_valid"), encoding: .utf8)!
    let cred = try reader.parseCredentialJSON(json)
    check(cred.accessToken == "test-token-abc123", "accessToken matches")
    check(cred.expiresAt > Date(), "token not expired (expires 2099)")
}

// --- Test: Parse expired credential throws ---
do {
    print("Test: Parse expired credential throws")
    let json = String(data: fixture("credential_expired"), encoding: .utf8)!
    var threwExpired = false
    do {
        _ = try reader.parseCredentialJSON(json)
    } catch let err as KeychainError {
        if case .tokenExpired = err { threwExpired = true }
    }
    check(threwExpired, "should throw KeychainError.tokenExpired")
}

// --- Test: Parse credential with missing fields throws ---
do {
    print("Test: Parse credential with missing fields throws")
    let json = String(data: fixture("credential_missing_fields"), encoding: .utf8)!
    var threwMissing = false
    do {
        _ = try reader.parseCredentialJSON(json)
    } catch let err as KeychainError {
        if case .missingOAuthFields = err { threwMissing = true }
    }
    check(threwMissing, "should throw KeychainError.missingOAuthFields")
}

// --- Test: Parse garbage JSON throws ---
do {
    print("Test: Parse garbage credential JSON throws")
    var threwParse = false
    do {
        _ = try reader.parseCredentialJSON("not valid json")
    } catch let err as KeychainError {
        if case .jsonParseError = err { threwParse = true }
    }
    check(threwParse, "should throw KeychainError.jsonParseError")
}

// ============================================================
// ClaudeUsageProvider mapping tests
// ============================================================

// --- Test: mapResponse produces session + weekly windows ---
do {
    print("Test: mapResponse full payload -> session + weekly")
    let data = fixture("usage_success")
    let response = try JSONDecoder().decode(UsageResponse.self, from: data)
    let windows = ClaudeUsageProvider.mapResponse(response)

    check(windows.count == 2, "should produce 2 windows")

    let session = windows.first { $0.kind == UsageWindowKind.session }!
    check(session.id == "claude-session", "session id")
    check(session.usedFraction == 0.42, "session usedFraction == 0.42 (normalized from 42.0)")
    check(session.label == "5-hour session", "session label")
    check(session.perModel != nil, "session has perModel from limits")
    check(session.perModel!.count == 1, "session has 1 per-model (session group)")
    check(session.perModel![0].displayName == "Claude Opus 4", "session perModel[0] name")
    check(session.perModel![0].usedFraction == 0.42, "session perModel[0] fraction normalized")

    let weekly = windows.first { $0.kind == UsageWindowKind.weekly }!
    check(weekly.id == "claude-weekly", "weekly id")
    check(weekly.usedFraction == 0.65, "weekly usedFraction == 0.65 (normalized from 65.0)")
    check(weekly.perModel != nil, "weekly has perModel")

    let modelNames = Set(weekly.perModel!.map { $0.displayName })
    check(modelNames.contains("Opus") || modelNames.contains("Sonnet") ||
          modelNames.contains("Fable") || modelNames.contains("Design"),
          "weekly has expected model windows")
}

// --- Test: mapResponse minimal -> session only ---
do {
    print("Test: mapResponse minimal -> session only")
    let data = fixture("usage_minimal")
    let response = try JSONDecoder().decode(UsageResponse.self, from: data)
    let windows = ClaudeUsageProvider.mapResponse(response)

    check(windows.count == 1, "should produce 1 window")
    check(windows[0].kind == UsageWindowKind.session, "should be session")
    check(windows[0].usedFraction == 0.99, "usedFraction == 0.99 (<=1 passes through)")
    check(windows[0].perModel == nil, "no perModel without limits")
}

// --- Test: mapResponse empty limits -> no perModel on session ---
do {
    print("Test: mapResponse empty limits -> session without perModel")
    let data = fixture("usage_empty_limits")
    let response = try JSONDecoder().decode(UsageResponse.self, from: data)
    let windows = ClaudeUsageProvider.mapResponse(response)

    check(windows.count == 2, "should produce 2 windows (null resetsAt gets fallback)")
    let session = windows.first { $0.kind == UsageWindowKind.session }!
    check(session.usedFraction == 0.0, "session fraction 0.0")
    check(session.perModel == nil, "no perModel with empty limits")
    let weekly = windows.first { $0.kind == UsageWindowKind.weekly }!
    check(weekly.usedFraction == 0.02, "weekly fraction 0.02 (normalized from 2.0)")
}

// ============================================================
// UsagePoller state tests (with mock provider)
// ============================================================

struct MockProvider: UsageProvider {
    let id = "mock"
    let displayName = "Mock"
    let result: @Sendable () async throws -> [UsageWindowInfo]

    func fetch() async throws -> [UsageWindowInfo] {
        try await result()
    }
}

// --- Test: Poller loaded state ---
do {
    print("Test: Poller transitions to loaded state")
    let windows = [UsageWindowInfo(
        id: "test",
        kind: .session,
        label: "Test",
        usedFraction: 0.5,
        resetsAt: Date().addingTimeInterval(3600)
    )]
    let provider = MockProvider { windows }
    let poller = UsagePoller(provider: provider)

    await poller.pollOnce()

    if case .loaded(let result) = poller.state {
        check(result.count == 1, "loaded 1 window")
        check(result[0].usedFraction == 0.5, "usedFraction == 0.5")
    } else {
        check(false, "state should be .loaded, got \(poller.state)")
    }
    check(poller.lastUpdated != nil, "lastUpdated should be set")
}

// --- Test: Poller error state ---
do {
    print("Test: Poller transitions to error state on API error")
    let provider = MockProvider { throw UsageAPIError.networkError(underlying: URLError(.notConnectedToInternet)) }
    let poller = UsagePoller(provider: provider)

    await poller.pollOnce()

    if case .error(.networkError) = poller.state {
        check(true, "state is .error(.networkError)")
    } else {
        check(false, "state should be .error(.networkError), got \(poller.state)")
    }
}

// --- Test: Poller unauthorized maps to tokenExpired ---
do {
    print("Test: Poller transitions to tokenExpired on 401")
    let provider = MockProvider { throw UsageAPIError.unauthorized }
    let poller = UsagePoller(provider: provider)

    await poller.pollOnce()

    if case .tokenExpired = poller.state {
        check(true, "401 maps to tokenExpired")
    } else {
        check(false, "state should be .tokenExpired, got \(poller.state)")
    }
}

// --- Test: Poller token expired state ---
do {
    print("Test: Poller transitions to tokenExpired state")
    let provider = MockProvider {
        throw KeychainError.tokenExpired(expiresAt: Date().addingTimeInterval(-3600))
    }
    let poller = UsagePoller(provider: provider)

    await poller.pollOnce()

    if case .tokenExpired = poller.state {
        check(true, "state is tokenExpired")
    } else {
        check(false, "state should be .tokenExpired")
    }
}

// --- Test: Poller convenience accessors ---
do {
    print("Test: Poller sessionWindow/weeklyWindow accessors")
    let windows = [
        UsageWindowInfo(id: "s", kind: .session, label: "S", usedFraction: 0.3, resetsAt: Date().addingTimeInterval(3600)),
        UsageWindowInfo(id: "w", kind: .weekly, label: "W", usedFraction: 0.7, resetsAt: Date().addingTimeInterval(86400)),
    ]
    let provider = MockProvider { windows }
    let poller = UsagePoller(provider: provider)
    await poller.pollOnce()

    check(poller.sessionWindow?.id == "s", "sessionWindow returns session")
    check(poller.weeklyWindow?.id == "w", "weeklyWindow returns weekly")
}

// ============================================================
// TimerEngine tests
// ============================================================

// --- Test: CountdownTimer duration constructor ---
do {
    print("Test: CountdownTimer duration constructor")
    let now = Date()
    let t = CountdownTimer(label: "Test", duration: 300, now: now)
    check(t.label == "Test", "label")
    check(t.state == .running, "state is running")
    let remaining = t.remaining(at: now)
    check(remaining >= 299 && remaining <= 301, "remaining ~300s")
}

// --- Test: CountdownTimer remaining counts down ---
do {
    print("Test: CountdownTimer remaining counts down")
    let now = Date()
    let t = CountdownTimer(label: "Test", duration: 60, now: now)
    let later = now.addingTimeInterval(45)
    let remaining = t.remaining(at: later)
    check(remaining >= 14 && remaining <= 16, "remaining ~15s after 45s")
}

// --- Test: CountdownTimer remaining floors at 0 ---
do {
    print("Test: CountdownTimer remaining floors at 0")
    let now = Date()
    let t = CountdownTimer(label: "Test", duration: 10, now: now)
    let later = now.addingTimeInterval(20)
    check(t.remaining(at: later) == 0, "remaining is 0 after expiry")
}

// --- Test: TimerEngine add and cancel ---
await MainActor.run {
    print("Test: TimerEngine add and cancel")
    let engine = TimerEngine()
    engine.addTimer(label: "A", duration: 60)
    engine.addTimer(label: "B", duration: 120)
    check(engine.timers.count == 2, "2 timers added")
    check(engine.activeTimers.count == 2, "2 active")

    let idA = engine.timers[0].id
    engine.cancelTimer(id: idA)
    check(engine.timers[0].state == .cancelled, "A is cancelled")
    check(engine.activeTimers.count == 1, "1 active after cancel")

    engine.removeTimer(id: idA)
    check(engine.timers.count == 1, "1 timer after remove")
}

// --- Test: TimerEngine tick fires expired timers ---
do {
    print("Test: TimerEngine tick fires expired timers")
    let engine = await MainActor.run { TimerEngine() }
    await MainActor.run {
        engine.addTimer(label: "Short", duration: 0.001)
        engine.addTimer(label: "Future", duration: 3600)
    }

    try? await Task.sleep(for: .milliseconds(20))

    await MainActor.run {
        nonisolated(unsafe) var firedLabels: [String] = []
        engine.onFire = { t in firedLabels.append(t.label) }
        engine.tick()

        check(firedLabels == ["Short"], "only Short fired")
        check(engine.firedTimers.count == 1, "1 fired")
        check(engine.activeTimers.count == 1, "1 still active")
    }
}

// --- Test: TimerEngine clearFired ---
do {
    print("Test: TimerEngine clearFired removes fired timers")
    let engine = await MainActor.run { TimerEngine() }
    await MainActor.run { engine.addTimer(label: "Short", duration: 0.001) }
    try? await Task.sleep(for: .milliseconds(20))
    await MainActor.run {
        engine.tick()
        check(engine.firedTimers.count == 1, "1 fired before clear")
        engine.clearFired()
        check(engine.timers.isEmpty, "empty after clearFired")
    }
}

// --- Test: TimerEngine rejects past fireAt ---
await MainActor.run {
    print("Test: TimerEngine rejects fireAt in the past")
    let engine = TimerEngine()
    engine.addTimer(label: "Past", fireAt: Date().addingTimeInterval(-100))
    check(engine.timers.isEmpty, "no timer added for past date")
}

// --- Test: TimerEngine presets from windows ---
await MainActor.run {
    print("Test: TimerEngine presets from usage windows")
    let windows = [
        UsageWindowInfo(id: "session", kind: .session, label: "5-hour session",
                        usedFraction: 0.5, resetsAt: Date().addingTimeInterval(7200)),
        UsageWindowInfo(id: "weekly", kind: .weekly, label: "7-day total",
                        usedFraction: 0.3, resetsAt: Date().addingTimeInterval(86400)),
    ]
    let presets = TimerEngine.presets(from: windows)

    check(presets.count == 4, "4 presets (2 per window: at-reset + 15min-before)")

    let resetPresets = presets.filter { $0.id.hasSuffix("-reset") }
    check(resetPresets.count == 2, "2 reset presets")

    let earlyPresets = presets.filter { $0.id.hasSuffix("-15min") }
    check(earlyPresets.count == 2, "2 15min-before presets")

    check(presets[0].label.contains("session"), "first preset mentions session")
}

// --- Test: Presets skip expired windows ---
await MainActor.run {
    print("Test: TimerEngine presets skip expired windows")
    let windows = [
        UsageWindowInfo(id: "old", kind: .session, label: "Expired",
                        usedFraction: 1.0, resetsAt: Date().addingTimeInterval(-100)),
    ]
    let presets = TimerEngine.presets(from: windows)
    check(presets.isEmpty, "no presets for expired window")
}

// ============================================================
// AppSettings tests
// ============================================================

// --- Test: Settings defaults ---
do {
    print("Test: Settings has correct defaults")
    let ud = UserDefaults(suiteName: "test-settings-defaults")!
    ud.removePersistentDomain(forName: "test-settings-defaults")
    let s = AppSettings(defaults: ud)

    check(s.thresholds == [50, 75, 90], "default thresholds are 50, 75, 90")
    check(s.launchAtLogin == false, "launchAtLogin defaults to false")
    check(s.pollInterval == 180, "pollInterval defaults to 180")
}

// --- Test: Settings persistence ---
do {
    print("Test: Settings persists to UserDefaults")
    let ud = UserDefaults(suiteName: "test-settings-persist")!
    ud.removePersistentDomain(forName: "test-settings-persist")
    let s = AppSettings(defaults: ud)

    s.toggleThreshold(50)
    check(s.thresholds == [75, 90], "50 removed after toggle")

    s.toggleThreshold(50)
    check(s.thresholds == [50, 75, 90], "50 re-added after toggle")

    s.pollInterval = 300
    s.launchAtLogin = true

    let s2 = AppSettings(defaults: ud)
    check(s2.thresholds == [50, 75, 90], "thresholds persisted")
    check(s2.pollInterval == 300, "pollInterval persisted")
    check(s2.launchAtLogin == true, "launchAtLogin persisted")

    ud.removePersistentDomain(forName: "test-settings-persist")
}

// --- Test: Settings isThresholdEnabled ---
do {
    print("Test: Settings isThresholdEnabled")
    let ud = UserDefaults(suiteName: "test-settings-enabled")!
    ud.removePersistentDomain(forName: "test-settings-enabled")
    let s = AppSettings(defaults: ud)

    check(s.isThresholdEnabled(50), "50 is enabled by default")
    check(s.isThresholdEnabled(75), "75 is enabled by default")
    check(s.isThresholdEnabled(90), "90 is enabled by default")
    check(!s.isThresholdEnabled(25), "25 is not enabled")

    ud.removePersistentDomain(forName: "test-settings-enabled")
}

// ============================================================
// ThresholdMonitor tests
// ============================================================

// --- Test: ThresholdMonitor fires on crossing ---
do {
    print("Test: ThresholdMonitor fires when threshold crossed")
    let ud = UserDefaults(suiteName: "test-threshold-fire")!
    ud.removePersistentDomain(forName: "test-threshold-fire")
    let settings = AppSettings(defaults: ud)
    let monitor = ThresholdMonitor(settings: settings)

    let windows = [
        UsageWindowInfo(id: "s", kind: .session, label: "Session",
                        usedFraction: 0.55, resetsAt: Date().addingTimeInterval(3600)),
    ]
    monitor.check(windows: windows)

    let notified = monitor.notifiedThresholds(for: "s")
    check(notified.contains(50), "50% threshold notified at 55% usage")
    check(!notified.contains(75), "75% not yet notified")
    check(!notified.contains(90), "90% not yet notified")

    ud.removePersistentDomain(forName: "test-threshold-fire")
}

// --- Test: ThresholdMonitor does not re-fire ---
do {
    print("Test: ThresholdMonitor does not re-fire already notified threshold")
    let ud = UserDefaults(suiteName: "test-threshold-nodup")!
    ud.removePersistentDomain(forName: "test-threshold-nodup")
    let settings = AppSettings(defaults: ud)
    let monitor = ThresholdMonitor(settings: settings)

    let resetTime = Date().addingTimeInterval(3600)
    let w1 = [UsageWindowInfo(id: "s", kind: .session, label: "Session",
                              usedFraction: 0.55, resetsAt: resetTime)]
    monitor.check(windows: w1)
    check(monitor.notifiedThresholds(for: "s").contains(50), "50% notified first time")

    let w2 = [UsageWindowInfo(id: "s", kind: .session, label: "Session",
                              usedFraction: 0.60, resetsAt: resetTime)]
    monitor.check(windows: w2)
    check(monitor.notifiedThresholds(for: "s").count == 1, "still only 1 threshold notified")

    ud.removePersistentDomain(forName: "test-threshold-nodup")
}

// --- Test: ThresholdMonitor resets on new cycle ---
do {
    print("Test: ThresholdMonitor resets when resetsAt changes")
    let ud = UserDefaults(suiteName: "test-threshold-reset")!
    ud.removePersistentDomain(forName: "test-threshold-reset")
    let settings = AppSettings(defaults: ud)
    let monitor = ThresholdMonitor(settings: settings)

    let reset1 = Date().addingTimeInterval(3600)
    let w1 = [UsageWindowInfo(id: "s", kind: .session, label: "Session",
                              usedFraction: 0.80, resetsAt: reset1)]
    monitor.check(windows: w1)
    check(monitor.notifiedThresholds(for: "s").count == 2, "50% and 75% notified")

    let reset2 = Date().addingTimeInterval(7200)
    let w2 = [UsageWindowInfo(id: "s", kind: .session, label: "Session",
                              usedFraction: 0.80, resetsAt: reset2)]
    monitor.check(windows: w2)
    check(monitor.notifiedThresholds(for: "s").count == 2, "re-notified after cycle reset")

    ud.removePersistentDomain(forName: "test-threshold-reset")
}

// --- Test: ThresholdMonitor respects disabled thresholds ---
do {
    print("Test: ThresholdMonitor skips disabled thresholds")
    let ud = UserDefaults(suiteName: "test-threshold-disabled")!
    ud.removePersistentDomain(forName: "test-threshold-disabled")
    let settings = AppSettings(defaults: ud)
    settings.toggleThreshold(50)

    let monitor = ThresholdMonitor(settings: settings)
    let windows = [
        UsageWindowInfo(id: "s", kind: .session, label: "Session",
                        usedFraction: 0.55, resetsAt: Date().addingTimeInterval(3600)),
    ]
    monitor.check(windows: windows)

    check(monitor.notifiedThresholds(for: "s").isEmpty, "no threshold notified when 50 disabled")

    ud.removePersistentDomain(forName: "test-threshold-disabled")
}

// --- Test: ThresholdMonitor fires multiple thresholds ---
do {
    print("Test: ThresholdMonitor fires multiple thresholds at once")
    let ud = UserDefaults(suiteName: "test-threshold-multi")!
    ud.removePersistentDomain(forName: "test-threshold-multi")
    let settings = AppSettings(defaults: ud)
    let monitor = ThresholdMonitor(settings: settings)

    let windows = [
        UsageWindowInfo(id: "s", kind: .session, label: "Session",
                        usedFraction: 0.95, resetsAt: Date().addingTimeInterval(3600)),
    ]
    monitor.check(windows: windows)

    let notified = monitor.notifiedThresholds(for: "s")
    check(notified == [50, 75, 90], "all three thresholds notified at 95%")

    ud.removePersistentDomain(forName: "test-threshold-multi")
}

// ============================================================
// LaunchAtLogin plist generation test
// ============================================================

do {
    print("Test: LaunchAtLogin generates valid plist content")
    let content = LaunchAtLogin.generatePlistContent(executablePath: "/usr/local/bin/QuotaTimer")
    check(content.contains("<string>/usr/local/bin/QuotaTimer</string>"), "plist contains executable path")
    check(content.contains("<key>RunAtLoad</key>"), "plist contains RunAtLoad")
    check(content.contains("com.quotatimer.launcher"), "plist contains label")
}

// ============================================================
// CodexAuthReader tests
// ============================================================

let codexReader = CodexAuthReader()

// --- Test: Parse valid Codex auth (tokens format) ---
do {
    print("Test: Parse valid Codex auth JSON (tokens format)")
    let data = fixture("codex_auth_valid")
    let cred = try codexReader.parseAuthJSON(data)
    check(cred.accessToken == "test-access-token-xyz", "accessToken matches")
    check(cred.accountId == "acct-12345-abcde", "accountId matches")
}

// --- Test: Parse legacy Codex auth format ---
do {
    print("Test: Parse legacy Codex auth JSON (access/accountId format)")
    let data = fixture("codex_auth_legacy")
    let cred = try codexReader.parseAuthJSON(data)
    check(cred.accessToken == "legacy-access-token-abc", "accessToken matches")
    check(cred.accountId == "acct-legacy-12345", "accountId matches")
}

// --- Test: Parse Codex auth missing fields throws ---
do {
    print("Test: Parse Codex auth missing fields throws")
    let data = Data("{\"tokens\": {}}".utf8)
    var threw = false
    do {
        _ = try codexReader.parseAuthJSON(data)
    } catch let err as CodexAuthError {
        if case .missingFields = err { threw = true }
    }
    check(threw, "should throw CodexAuthError.missingFields")
}

// --- Test: Parse Codex auth garbage throws ---
do {
    print("Test: Parse Codex auth garbage throws")
    let data = Data("not json".utf8)
    var threw = false
    do {
        _ = try codexReader.parseAuthJSON(data)
    } catch let err as CodexAuthError {
        if case .parseError = err { threw = true }
    }
    check(threw, "should throw CodexAuthError.parseError")
}

// ============================================================
// CodexUsageResponse parsing tests
// ============================================================

// --- Test: Decode full Codex usage payload ---
do {
    print("Test: Decode full Codex usage payload")
    let data = fixture("codex_usage_full")
    let r = try JSONDecoder().decode(CodexUsageResponse.self, from: data)

    check(r.planType == "plus", "planType == plus")
    check(r.rateLimit?.allowed == true, "allowed == true")
    check(r.rateLimit?.limitReached == false, "limitReached == false")
    check(r.rateLimit?.primaryWindow?.usedPercent == 45, "primary usedPercent == 45")
    check(r.rateLimit?.primaryWindow?.limitWindowSeconds == 604800, "primary window is 7 days")
    check(r.rateLimit?.primaryWindow?.resetAt == 1786536977, "primary resetAt")
    check(r.rateLimit?.secondaryWindow?.usedPercent == 20, "secondary usedPercent == 20")
    check(r.rateLimit?.secondaryWindow?.limitWindowSeconds == 18000, "secondary window is 5 hours")
    check(r.additionalRateLimits?.count == 2, "2 additional limits")
    check(r.additionalRateLimits?[0].limitName == "GPT-5.3-Codex-Spark", "first additional name")
    check(r.additionalRateLimits?[1].rateLimit?.primaryWindow?.usedPercent == 60, "second additional usedPercent")
}

// --- Test: Decode minimal Codex usage payload ---
do {
    print("Test: Decode minimal Codex usage payload")
    let data = fixture("codex_usage_minimal")
    let r = try JSONDecoder().decode(CodexUsageResponse.self, from: data)

    check(r.rateLimit?.primaryWindow?.usedPercent == 80, "primary usedPercent == 80")
    check(r.rateLimit?.secondaryWindow == nil, "no secondary window")
    check(r.additionalRateLimits?.isEmpty == true, "empty additional limits")
}

// ============================================================
// CodexUsageProvider mapping tests
// ============================================================

// --- Test: CodexUsageProvider mapResponse full payload ---
do {
    print("Test: CodexUsageProvider mapResponse full payload")
    let data = fixture("codex_usage_full")
    let response = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
    let windows = CodexUsageProvider.mapResponse(response)

    check(windows.count == 2, "2 windows (primary + secondary)")

    let primary = windows.first { $0.id == "codex-primary" }!
    check(primary.usedFraction == 0.45, "primary usedFraction == 0.45")
    check(primary.kind == UsageWindowKind.weekly, "primary is weekly (604800s)")
    check(primary.perModel != nil, "primary has per-model data")
    check(primary.perModel?.count == 2, "2 per-model entries")

    let secondary = windows.first { $0.id == "codex-secondary" }!
    check(secondary.usedFraction == 0.20, "secondary usedFraction == 0.20")
    check(secondary.kind == UsageWindowKind.session, "secondary is session (18000s)")
}

// --- Test: CodexUsageProvider mapResponse minimal ---
do {
    print("Test: CodexUsageProvider mapResponse minimal")
    let data = fixture("codex_usage_minimal")
    let response = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
    let windows = CodexUsageProvider.mapResponse(response)

    check(windows.count == 1, "1 window (primary only)")
    check(windows[0].usedFraction == 0.80, "usedFraction == 0.80")
    check(windows[0].perModel == nil, "no per-model data")
}

// --- Test: CodexUsageProvider mapResponse empty rate limit ---
do {
    print("Test: CodexUsageProvider mapResponse with no rate_limit")
    let data = Data("{\"plan_type\": \"free\"}".utf8)
    let response = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
    let windows = CodexUsageProvider.mapResponse(response)
    check(windows.isEmpty, "no windows when rate_limit is nil")
}

// --- Summary ---
print("\n\(passed) passed, \(failed) failed")
if failed > 0 {
    exit(1)
}
