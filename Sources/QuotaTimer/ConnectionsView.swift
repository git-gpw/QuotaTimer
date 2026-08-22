import SwiftUI
import QuotaTimerShared

struct ConnectionsView: View {
    let pollers: [UsagePoller]
    let settings: AppSettings
    @State private var claudeStatus: CredentialStatus?
    @State private var codexStatus: CredentialStatus?
    @State private var checking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connections")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    checkAll()
                } label: {
                    if checking {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Text("Check")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(checking)
            }

            ProviderRow(
                name: "Claude",
                icon: "diamond",
                color: .orange,
                status: effectiveStatus(credential: claudeStatus, pollerName: "Claude"),
                enabled: Binding(
                    get: { settings.claudeEnabled },
                    set: { settings.claudeEnabled = $0 }
                ),
                hint: "Run `claude` in Terminal to log in",
                onReconnect: {
                    openTerminalWithCommand("claude")
                }
            )

            ProviderRow(
                name: "Codex",
                icon: "chevron.left.forwardslash.chevron.right",
                color: .green,
                status: effectiveStatus(credential: codexStatus, pollerName: "Codex"),
                enabled: Binding(
                    get: { settings.codexEnabled },
                    set: { settings.codexEnabled = $0 }
                ),
                hint: "Run `codex` in Terminal to log in",
                onReconnect: {
                    openTerminalWithCommand("codex")
                }
            )
        }
        .onAppear { checkAll() }
    }

    private func effectiveStatus(credential: CredentialStatus?, pollerName: String) -> CredentialStatus {
        let poller = pollers.first {
            $0.providerName.lowercased().contains(pollerName.lowercased())
        }

        if let cred = credential {
            if cred.isConnected, let poller {
                switch poller.state {
                case .loaded:
                    return .connected(expiresAt: nil)
                case .error(let kind):
                    return .error(kind.userMessage)
                case .tokenExpired:
                    return .expired(at: nil)
                case .idle, .loading:
                    return cred
                }
            }
            return cred
        }

        guard let poller else {
            return .notFound(hint: "Provider not configured")
        }
        switch poller.state {
        case .loaded:
            return .connected(expiresAt: nil)
        case .tokenExpired:
            return .expired(at: nil)
        case .error(let kind):
            return .error(kind.userMessage)
        case .idle, .loading:
            return .checking
        }
    }

    private func checkAll() {
        checking = true
        let checker = CredentialChecker()
        Task.detached {
            let claude = checker.checkClaude()
            let codex = checker.checkCodex()
            await MainActor.run {
                claudeStatus = claude
                codexStatus = codex
                checking = false
            }
        }
    }

    private func openTerminalWithCommand(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

struct ProviderRow: View {
    let name: String
    let icon: String
    let color: Color
    let status: CredentialStatus
    let enabled: Binding<Bool>
    let hint: String
    let onReconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(color)
                        .frame(width: 16)
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                }

                Spacer()

                statusBadge

                Toggle("", isOn: enabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            if !status.isConnected && !status.isChecking {
                actionRow
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .connected:
            HStack(spacing: 3) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Connected")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        case .expired:
            HStack(spacing: 3) {
                Circle().fill(.orange).frame(width: 6, height: 6)
                Text("Expired")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        case .notFound:
            HStack(spacing: 3) {
                Circle().fill(.secondary).frame(width: 6, height: 6)
                Text("Not found")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        case .error:
            HStack(spacing: 3) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Text("Error")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        case .checking:
            HStack(spacing: 3) {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 6) {
            switch status {
            case .expired:
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text("Token expired — re-authenticate")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            case .notFound(let h):
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(h)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            case .error(let msg):
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("View Log") {
                    NSWorkspace.shared.open(DebugLog.shared.logFileURL)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
            case .connected, .checking:
                EmptyView()
            }

            Spacer()

            if case .connected = status {} else if case .checking = status {} else {
                Button("Open Terminal") {
                    onReconnect()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
                .foregroundStyle(.blue)
            }
        }
        .padding(.leading, 22)
    }
}
