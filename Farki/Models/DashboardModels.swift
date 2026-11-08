import Foundation

/// Metric item representing a progress item on the dashboard (Vocab, Kanji, Particles, GuideBook chapters)
public struct DashboardMetricItem: Identifiable, Equatable {
    public let id: String
    public var title: String
    public var completed: Int
    public var total: Int
    public var unit: String
    public var progressOverride: Double?
    public var percentageOverride: String?
    public var customSubtitle: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        completed: Int = 0,
        total: Int,
        unit: String,
        progressOverride: Double? = nil,
        percentageOverride: String? = nil,
        customSubtitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.completed = completed
        self.total = total
        self.unit = unit
        self.progressOverride = progressOverride
        self.percentageOverride = percentageOverride
        self.customSubtitle = customSubtitle
    }

    /// Progress value normalized between 0.0 and 1.0
    public var progress: Double {
        if let override = progressOverride {
            return min(max(override, 0.0), 1.0)
        }
        guard total > 0 else { return 0.0 }
        return min(max(Double(completed) / Double(total), 0.0), 1.0)
    }

    /// Formatted percentage string matching the monospace aesthetic (e.g. "00%", "66%")
    public var percentageText: String {
        if let override = percentageOverride {
            return override
        }
        let pct = Int(round(progress * 100))
        return String(format: "%02d%%", pct)
    }

    /// Formatted subtitle description matching the mockup (e.g. "You completed 00/800 words")
    public var subtitleText: String {
        if let custom = customSubtitle {
            return custom
        }
        let completedFormatted = String(format: "%02d", completed)
        return "You completed \(completedFormatted)/\(total) \(unit)"
    }
}

/// Pace/Velocity progress item for the "Progress" section
public struct DashboardPaceItem: Equatable {
    public var title: String
    public var subtitle: String
    public var targetDays: Int
    public var daysUnit: String
    public var progress: Double

    public init(
        title: String = "Current",
        subtitle: String = "With current pase will complete Shokyū I on time",
        targetDays: Int = 51,
        daysUnit: String = "D",
        progress: Double = 0.0 // Default empty bar
    ) {
        self.title = title
        self.subtitle = subtitle
        self.targetDays = targetDays
        self.daysUnit = daysUnit
        self.progress = progress
    }

    /// Formatted display value (e.g. "51 D")
    public var valueText: String {
        "\(targetDays) \(daysUnit)"
    }
}
