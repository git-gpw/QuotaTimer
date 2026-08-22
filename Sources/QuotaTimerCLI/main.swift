import Foundation
import QuotaTimerShared

func run() async {
    print("QuotaTimer CLI — M0 spike\n")

    // 1. Read OAuth token from Keychain
    let credential: OAuthCredential
    do {
        print("Reading Keychain...")
        credential = try KeychainReader().readCredential()
        print("  Token found, expires \(credential.expiresAt)")
        print("  Token prefix: \(String(credential.accessToken.prefix(8)))...")
    } catch let err as KeychainError {
        print("ERROR reading Keychain: \(err)")
        if case .tokenExpired(let date) = err {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let ago = formatter.localizedString(for: date, relativeTo: Date())
            print("  Token expired \(ago)")
            print("  Re-authenticate in Claude Code to refresh it")
        }
        return
    } catch {
        print("ERROR reading Keychain: \(error)")
        return
    }

    // 2. Call usage endpoint
    let response: UsageResponse
    do {
        print("\nFetching usage from API...")
        response = try await UsageAPIClient().fetch(token: credential.accessToken)
        print("  Success!\n")
    } catch {
        print("ERROR fetching usage: \(error)")
        return
    }

    // 3. Pretty-print results
    if let w = response.fiveHour {
        print("5-hour session:  \(pct(w.utilization)) used, resets \(w.resetsAt ?? "n/a")")
    }
    if let w = response.sevenDay {
        print("7-day total:     \(pct(w.utilization)) used, resets \(w.resetsAt ?? "n/a")")
    }
    if let w = response.sevenDayOpus {
        print("  Opus weekly:   \(pct(w.utilization)) used, resets \(w.resetsAt ?? "n/a")")
    }
    if let w = response.sevenDaySonnet {
        print("  Sonnet weekly: \(pct(w.utilization)) used, resets \(w.resetsAt ?? "n/a")")
    }
    if let w = response.sevenDayFable {
        print("  Fable weekly:  \(pct(w.utilization)) used, resets \(w.resetsAt ?? "n/a")")
    }
    if let w = response.sevenDayDesign {
        print("  Design weekly: \(pct(w.utilization)) used, resets \(w.resetsAt ?? "n/a")")
    }

    if let limits = response.limits, !limits.isEmpty {
        print("\nPer-model limits:")
        for limit in limits {
            let model = limit.scope?.model?.displayName ?? limit.kind
            print("  \(model): \(pct(limit.percent)) used (\(limit.kind)), resets \(limit.resetsAt ?? "n/a")")
        }
    }
}

func pct(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

await run()
