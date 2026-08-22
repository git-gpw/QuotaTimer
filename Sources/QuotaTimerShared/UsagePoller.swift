import Foundation
import Observation

public enum PollerErrorKind: Sendable {
    case credentialNotFound
    case tokenExpired
    case networkError
    case rateLimited
    case decodingError
    case httpError(Int)
    case unknown

    public var userMessage: String {
        switch self {
        case .credentialNotFound:
            return "Not logged in"
        case .tokenExpired:
            return "Token expired — re-authenticate"
        case .networkError:
            return "Network unavailable"
        case .rateLimited:
            return "Rate limited — retrying soon"
        case .decodingError:
            return "Unexpected API response"
        case .httpError(let code):
            return "Server error (\(code))"
        case .unknown:
            return "Something went wrong"
        }
    }
}

public enum PollerState: Sendable {
    case idle
    case loading
    case loaded([UsageWindowInfo])
    case error(PollerErrorKind)
    case tokenExpired
}

@MainActor
@Observable
public final class UsagePoller: @unchecked Sendable {
    public let providerName: String
    public private(set) var state: PollerState = .idle
    public private(set) var lastUpdated: Date?

    private let provider: any UsageProvider
    private let baseInterval: TimeInterval
    private let minBackoff: TimeInterval
    private let maxBackoff: TimeInterval

    private var currentBackoff: TimeInterval
    private var pollTask: Task<Void, Never>?

    public init(
        provider: any UsageProvider,
        baseInterval: TimeInterval = 180,
        minBackoff: TimeInterval = 300,
        maxBackoff: TimeInterval = 1800
    ) {
        self.providerName = provider.displayName
        self.provider = provider
        self.baseInterval = baseInterval
        self.minBackoff = minBackoff
        self.maxBackoff = maxBackoff
        self.currentBackoff = minBackoff
    }

    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollOnce()
                let delay = self.nextDelay()
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func pollOnce() async {
        state = .loading
        do {
            let windows = try await provider.fetch()
            state = .loaded(windows)
            lastUpdated = Date()
            currentBackoff = minBackoff
        } catch let err as KeychainError {
            DebugLog.shared.logError(err, source: providerName, context: "credential read")
            if err.isTokenExpired {
                state = .tokenExpired
            } else if case .itemNotFound = err {
                state = .error(.credentialNotFound)
            } else if case .missingOAuthFields = err {
                state = .error(.credentialNotFound)
            } else {
                state = .error(.unknown)
            }
        } catch let err as CodexAuthError {
            DebugLog.shared.logError(err, source: providerName, context: "credential read")
            switch err {
            case .tokenExpired:
                state = .tokenExpired
            case .fileNotFound, .missingFields:
                state = .error(.credentialNotFound)
            case .parseError:
                state = .error(.unknown)
            }
        } catch let err as UsageAPIError {
            DebugLog.shared.logError(err, source: providerName, context: "API fetch")
            switch err {
            case .unauthorized:
                state = .tokenExpired
            case .rateLimited:
                currentBackoff = min(currentBackoff * 2, maxBackoff)
                state = .error(.rateLimited)
            case .httpError(let code, _):
                state = .error(.httpError(code))
            case .networkError:
                state = .error(.networkError)
            case .decodingError:
                state = .error(.decodingError)
            }
        } catch {
            DebugLog.shared.logError(error, source: providerName, context: "poll")
            state = .error(.unknown)
        }
    }

    private func nextDelay() -> TimeInterval {
        if case .error(.rateLimited) = state {
            return currentBackoff
        }
        if case .tokenExpired = state {
            return maxBackoff
        }
        return baseInterval
    }

    public var windows: [UsageWindowInfo] {
        if case .loaded(let w) = state { return w }
        return []
    }

    public var sessionWindow: UsageWindowInfo? {
        windows.first { $0.kind == .session }
    }

    public var weeklyWindow: UsageWindowInfo? {
        windows.first { $0.kind == .weekly }
    }
}
