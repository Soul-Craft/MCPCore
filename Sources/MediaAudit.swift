import Foundation

/// Categorized reason for why a media item was not analyzed.
/// Used by both Messages and Groups servers for audit reporting.
public enum MediaSkipReason: Sendable, Codable, Equatable {
    // Expected skips — normal behavior, not errors
    case noExtractDomain(String)
    case noContent
    case noSpeech
    case noProcessor
    case placeholderOnly(String)

    // Failures — actual errors
    case fileNotFound
    case fileUnreadable
    case fileOversized(Int64)
    case processingFailed(String)
    case processingTimedOut
    case notAuthorized
    case ssrfBlocked
    case httpError(Int)

    /// Whether this is normal/expected behavior rather than an error.
    public var isExpectedSkip: Bool {
        switch self {
        case .noExtractDomain, .noContent, .noSpeech, .noProcessor, .placeholderOnly:
            return true
        default:
            return false
        }
    }

    /// Human-readable label for aggregated skip reporting.
    public var reportLabel: String {
        switch self {
        case .noExtractDomain(let domain): return "no-extract domain (\(domain))"
        case .noContent: return "no useful content"
        case .noSpeech: return "no speech detected"
        case .noProcessor: return "no processor for type"
        case .placeholderOnly(let type): return "\(type)"
        case .fileNotFound: return "file not found"
        case .fileUnreadable: return "file unreadable"
        case .fileOversized(let size): return "file too large (\(size / 1_000_000)MB)"
        case .processingFailed(let desc): return "processing failed: \(desc)"
        case .processingTimedOut: return "processing timed out"
        case .notAuthorized: return "not authorized (speech recognition)"
        case .ssrfBlocked: return "blocked by SSRF defense"
        case .httpError(let code): return "HTTP error (\(code))"
        }
    }
}

/// Collects media processing outcomes and formats a diagnostic report block.
/// Both Messages and Groups servers build one of these per import and append
/// `.formatted()` to the MCP response.
public struct MediaAuditReport: Sendable, Codable {

    public enum MediaCategory: String, CaseIterable, Codable, Sendable {
        case photos = "Photos"
        case videos = "Videos"
        case audios = "Audios"
        case links = "Links"
    }

    public struct CategoryStats: Sendable, Codable {
        public var total: Int = 0
        public var analyzed: Int = 0
        public init() {}
    }

    public struct FailureEntry: Sendable, Codable {
        public let path: String
        public let reason: MediaSkipReason
        public init(path: String, reason: MediaSkipReason) {
            self.path = path
            self.reason = reason
        }
    }

    public var stats: [String: CategoryStats] = [:]
    public var failures: [FailureEntry] = []
    public var expectedSkips: [MediaSkipReason] = []
    public var notAnalyzed: [String] = []

    public init() {}

    public mutating func recordSuccess(category: MediaCategory) {
        incrementStats(category: category, analyzed: true)
    }

    public mutating func recordFailure(category: MediaCategory, path: String, reason: MediaSkipReason) {
        incrementStats(category: category, analyzed: false)
        failures.append(FailureEntry(path: path, reason: reason))
    }

    public mutating func recordExpectedSkip(category: MediaCategory, reason: MediaSkipReason) {
        incrementStats(category: category, analyzed: false)
        expectedSkips.append(reason)
    }

    private mutating func incrementStats(category: MediaCategory, analyzed: Bool) {
        var s = stats[category.rawValue] ?? CategoryStats()
        s.total += 1
        if analyzed { s.analyzed += 1 }
        stats[category.rawValue] = s
    }

    public mutating func recordPlaceholder(typeName: String) {
        notAnalyzed.append(typeName)
    }

    public mutating func merge(_ other: MediaAuditReport) {
        for (key, otherStats) in other.stats {
            var s = stats[key] ?? CategoryStats()
            s.total += otherStats.total
            s.analyzed += otherStats.analyzed
            stats[key] = s
        }
        failures.append(contentsOf: other.failures)
        expectedSkips.append(contentsOf: other.expectedSkips)
        notAnalyzed.append(contentsOf: other.notAnalyzed)
    }

    public var total: Int {
        stats.values.reduce(0) { $0 + $1.total } + notAnalyzed.count
    }

    public var analyzed: Int {
        stats.values.reduce(0) { $0 + $1.analyzed }
    }

    /// Produce the [MEDIA AUDIT] diagnostic block. Returns nil if no media was encountered.
    public func formatted() -> String? {
        guard total > 0 else { return nil }

        var lines: [String] = []
        lines.append("[MEDIA AUDIT]")
        lines.append("Total: \(total) media items")

        let pct = Double(analyzed) / Double(total) * 100
        lines.append("Analyzed: \(analyzed) (\(String(format: "%.1f", pct))%)")

        // By type — only categories that have items
        let categoryOrder: [MediaCategory] = [.photos, .videos, .audios, .links]
        let activeCategories = categoryOrder.filter { stats[$0.rawValue] != nil }
        if !activeCategories.isEmpty {
            lines.append("")
            lines.append("By type:")
            let maxLabelLen = activeCategories.map { $0.rawValue.count }.max() ?? 6
            for cat in activeCategories {
                let s = stats[cat.rawValue]!
                let label = cat.rawValue + ":"
                let padding = String(repeating: " ", count: max(1, maxLabelLen + 1 - label.count))
                let catPct = s.total > 0 ? Double(s.analyzed) / Double(s.total) * 100 : 0
                let fraction = "\(s.analyzed)/\(s.total)"
                lines.append("  \(label)\(padding) \(fraction.padding(toLength: 7, withPad: " ", startingAt: 0))(\(String(format: "%.1f", catPct))%)")
            }
        }

        // Failed items — per-item with paths
        if !failures.isEmpty {
            lines.append("")
            let failPct = Double(failures.count) / Double(total) * 100
            lines.append("Failed: \(failures.count) (\(String(format: "%.1f", failPct))%)")
            for entry in failures {
                let filename = (entry.path as NSString).lastPathComponent
                lines.append("  \(filename) — \(entry.reason.reportLabel)")
            }
        }

        // Expected skips — aggregated by reason
        if !expectedSkips.isEmpty {
            lines.append("")
            let skipPct = Double(expectedSkips.count) / Double(total) * 100
            lines.append("Skipped (expected): \(expectedSkips.count) (\(String(format: "%.1f", skipPct))%)")
            var labelCounts: [String: Int] = [:]
            for reason in expectedSkips {
                labelCounts[reason.reportLabel, default: 0] += 1
            }
            for (label, count) in labelCounts.sorted(by: { $0.value > $1.value }) {
                lines.append("  \(count)x \(label)")
            }
        }

        // Not analyzed — aggregated by type name
        if !notAnalyzed.isEmpty {
            lines.append("")
            lines.append("Not analyzed (placeholder only): \(notAnalyzed.count)")
            var typeCounts: [String: Int] = [:]
            for name in notAnalyzed {
                typeCounts[name, default: 0] += 1
            }
            let parts = typeCounts.sorted(by: { $0.value > $1.value })
                .map { "\($0.value)x \($0.key)" }
            lines.append("  \(parts.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }
}
