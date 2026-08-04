import Foundation
import Observation

@MainActor
@Observable
final class UsageViewModel {
    var snapshot: UsageSnapshot?
    var errorMessage: String?
    var isLoading = false
    var lastRefresh: Date?

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private let refreshInterval: Duration = .seconds(5 * 60)

    var cursorPercentText: String {
        guard let snapshot else {
            return errorMessage == nil ? "…" : "!"
        }
        return "\(Int(snapshot.cursorModelsPercent.rounded()))%"
    }

    var otherPercentText: String {
        guard let snapshot else { return "…" }
        return "\(Int(snapshot.otherModelsPercent.rounded()))%"
    }

    /// Compact menu-bar countdown, e.g. `13d`. Nil when unknown.
    var resetCountdownText: String? {
        guard let days = daysUntilReset else { return nil }
        if days <= 0 { return "0d" }
        return "\(days)d"
    }

    /// Popover copy, e.g. `Resets in 13 days (Aug 17)`.
    var resetDetailText: String? {
        guard let end = snapshot?.billingCycleEnd else { return nil }
        let date = end.formatted(date: .abbreviated, time: .omitted)
        guard let days = daysUntilReset else {
            return "Resets \(date)"
        }
        if days <= 0 {
            return "Resets today (\(date))"
        }
        if days == 1 {
            return "Resets in 1 day (\(date))"
        }
        return "Resets in \(days) days (\(date))"
    }

    var daysUntilReset: Int? {
        guard let end = snapshot?.billingCycleEnd else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: start, to: endDay).day
    }

    var planTitle: String {
        guard let snapshot else { return "Cursor Usage" }
        let plan = snapshot.membershipType.capitalized
        return "Included in \(plan)"
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.refresh()
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: self.refreshInterval)
                await self.refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let next = try await UsageService.fetch()
            snapshot = next
            errorMessage = nil
            lastRefresh = next.fetchedAt
        } catch {
            errorMessage = error.localizedDescription
            // Keep last good snapshot visible when a refresh fails.
        }
    }
}
