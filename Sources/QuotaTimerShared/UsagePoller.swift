import Foundation
import Observation

public enum PollerState: Sendable {
    case idle
    case loading
    case loaded([UsageWindowInfo])
    case error(String)
    case tokenExpired(String)
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
            if case .tokenExpired(let date) = err {
                state = .tokenExpired("Token expired at \(date)")
            } else {
                state = .error(err.description)
            }
        } catch let err as UsageAPIError {
            if case .rateLimited = err {
                currentBackoff = min(currentBackoff * 2, maxBackoff)
            }
            state = .error(err.description)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func nextDelay() -> TimeInterval {
        if case .error(let msg) = state, msg.contains("429") {
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
