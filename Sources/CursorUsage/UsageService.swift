import Foundation

struct UsageSnapshot: Equatable {
    let membershipType: String
    let cursorModelsPercent: Double
    let otherModelsPercent: Double
    let totalPercent: Double
    let billingCycleEnd: Date?
    let cursorModelsMessage: String?
    let otherModelsMessage: String?
    let fetchedAt: Date
}

enum UsageError: LocalizedError {
    case missingCursorDB
    case databaseOpenFailed
    case missingAccessToken
    case badHTTPStatus(Int)
    case decodeFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingCursorDB:
            return "Cursor state database not found. Is Cursor installed and signed in?"
        case .databaseOpenFailed:
            return "Could not open Cursor’s local database."
        case .missingAccessToken:
            return "No Cursor access token found. Sign in to Cursor, then try again."
        case .badHTTPStatus(let code):
            return "Usage API returned HTTP \(code)."
        case .decodeFailed:
            return "Could not parse usage response."
        case .notAuthenticated:
            return "Cursor session expired. Sign in to Cursor again."
        }
    }
}

enum UsageService {
    private static let endpoint = URL(
        string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage"
    )!

    static func fetch() async throws -> UsageSnapshot {
        let credentials = try AuthTokenReader.load()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status == 401 || status == 403 {
            throw UsageError.notAuthenticated
        }
        guard (200...299).contains(status) else {
            throw UsageError.badHTTPStatus(status)
        }

        let decoded = try JSONDecoder().decode(PeriodUsageResponse.self, from: data)
        guard let plan = decoded.planUsage else {
            throw UsageError.decodeFailed
        }

        let membership = (credentials.membershipType ?? decoded.membershipType ?? "unknown")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayMembership = membership.isEmpty ? "unknown" : membership

        return UsageSnapshot(
            membershipType: displayMembership,
            cursorModelsPercent: plan.autoPercentUsed ?? 0,
            otherModelsPercent: plan.apiPercentUsed ?? 0,
            totalPercent: plan.totalPercentUsed ?? 0,
            billingCycleEnd: decoded.billingCycleEndDate,
            cursorModelsMessage: decoded.autoModelSelectedDisplayMessage,
            otherModelsMessage: decoded.namedModelSelectedDisplayMessage,
            fetchedAt: Date()
        )
    }
}

// MARK: - API models

private struct PeriodUsageResponse: Decodable {
    let planUsage: PlanUsage?
    let membershipType: String?
    let billingCycleEnd: String?
    let autoModelSelectedDisplayMessage: String?
    let namedModelSelectedDisplayMessage: String?

    var billingCycleEndDate: Date? {
        guard let billingCycleEnd else { return nil }
        if let ms = Double(billingCycleEnd) {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        return ISO8601DateFormatter().date(from: billingCycleEnd)
    }
}

private struct PlanUsage: Decodable {
    let autoPercentUsed: Double?
    let apiPercentUsed: Double?
    let totalPercentUsed: Double?
}
