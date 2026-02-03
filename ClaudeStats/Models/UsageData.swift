import Foundation

// MARK: - Claude.ai Usage API Response
struct UsageResponse: Codable {
    let currentSession: SessionUsage?
    let weeklyLimits: WeeklyUsage?

    // Alternative field names the API might use
    let session: SessionUsage?
    let weekly: WeeklyUsage?

    var effectiveSession: SessionUsage? {
        currentSession ?? session
    }

    var effectiveWeekly: WeeklyUsage? {
        weeklyLimits ?? weekly
    }
}

struct SessionUsage: Codable {
    let percentUsed: Double?
    let used: Double?
    let limit: Double?
    let resetsAt: String?
    let resetsIn: Int? // seconds

    enum CodingKeys: String, CodingKey {
        case percentUsed = "percent_used"
        case used
        case limit
        case resetsAt = "resets_at"
        case resetsIn = "resets_in"
    }

    var percentage: Double {
        if let p = percentUsed { return p }
        if let u = used, let l = limit, l > 0 { return u / l }
        return 0
    }
}

struct WeeklyUsage: Codable {
    let percentUsed: Double?
    let used: Double?
    let limit: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case percentUsed = "percent_used"
        case used
        case limit
        case resetsAt = "resets_at"
    }

    var percentage: Double {
        if let p = percentUsed { return p }
        if let u = used, let l = limit, l > 0 { return u / l }
        return 0
    }
}

// MARK: - Organization Usage Response (alternative API format)
struct OrgUsageResponse: Codable {
    let usage: UsageDetails?
}

struct UsageDetails: Codable {
    let daily: UsagePeriod?
    let weekly: UsagePeriod?
    let session: UsagePeriod?
}

struct UsagePeriod: Codable {
    let current: Double?
    let limit: Double?
    let resetTime: String?
    let percentUsed: Double?

    enum CodingKeys: String, CodingKey {
        case current
        case limit
        case resetTime = "reset_time"
        case percentUsed = "percent_used"
    }
}
