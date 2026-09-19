import Foundation

public struct FocusActivitySource: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let appName: String
    public let browserName: String?
    public let websiteHost: String?

    public init(appName: String, browserName: String? = nil, websiteHost: String? = nil) {
        self.appName = appName
        self.browserName = browserName
        self.websiteHost = websiteHost?.lowercased()
    }

    public var id: String {
        if let websiteHost {
            return "host:\(websiteHost)"
        }
        return "app:\(appName.lowercased())"
    }

    public var displayName: String {
        if let websiteHost {
            return browserName.map { "\(websiteHost) (\($0))" } ?? websiteHost
        }
        return appName
    }
}

public struct FocusActivitySegment: Codable, Equatable, Sendable {
    public let source: FocusActivitySource
    public let startedAt: Date
    public let endedAt: Date

    public init(source: FocusActivitySource, startedAt: Date, endedAt: Date) {
        self.source = source
        self.startedAt = startedAt
        self.endedAt = max(endedAt, startedAt)
    }

    public var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}

public enum FocusGapReason: String, Codable, Equatable, Sendable {
    case noInput
    case unobserved
}

public struct FocusGap: Codable, Equatable, Sendable {
    public let reason: FocusGapReason
    public let startedAt: Date
    public let endedAt: Date

    public init(reason: FocusGapReason, startedAt: Date, endedAt: Date) {
        self.reason = reason
        self.startedAt = startedAt
        self.endedAt = max(endedAt, startedAt)
    }

    public var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}

public enum FocusBlockOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case partiallyCompleted
    case notCompleted
}

public struct FocusBlockReview: Codable, Equatable, Sendable {
    public let outcome: FocusBlockOutcome
    public let note: String?
    /// Activity identifiers the user explicitly labeled as distracting for this block.
    public let distractionSourceIDs: Set<String>

    public init(outcome: FocusBlockOutcome, note: String? = nil, distractionSourceIDs: Set<String> = []) {
        self.outcome = outcome
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.distractionSourceIDs = distractionSourceIDs
    }
}

public struct FocusBlock: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let intention: String
    public let startedAt: Date
    public let endedAt: Date
    public let timeZoneIdentifier: String
    public let utcOffsetSeconds: Int
    public let baselineSource: FocusActivitySource
    public let segments: [FocusActivitySegment]
    public let gaps: [FocusGap]
    public var review: FocusBlockReview?

    public init(
        id: UUID = UUID(),
        intention: String,
        startedAt: Date,
        endedAt: Date,
        timeZoneIdentifier: String,
        utcOffsetSeconds: Int,
        baselineSource: FocusActivitySource,
        segments: [FocusActivitySegment],
        gaps: [FocusGap],
        review: FocusBlockReview? = nil
    ) {
        self.id = id
        self.intention = intention
        self.startedAt = startedAt
        self.endedAt = max(endedAt, startedAt)
        self.timeZoneIdentifier = timeZoneIdentifier
        self.utcOffsetSeconds = utcOffsetSeconds
        self.baselineSource = baselineSource
        self.segments = segments
        self.gaps = gaps
        self.review = review
    }

    public var observedDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    public var noInputDuration: TimeInterval {
        gaps.filter { $0.reason == .noInput }.reduce(0) { $0 + $1.duration }
    }

    public var unobservedDuration: TimeInterval {
        gaps.filter { $0.reason == .unobserved }.reduce(0) { $0 + $1.duration }
    }

    public var sourceDurations: [(source: FocusActivitySource, duration: TimeInterval)] {
        let totals = Dictionary(grouping: segments, by: \.source).mapValues { segments in
            segments.reduce(0) { $0 + $1.duration }
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.duration > $1.duration }
    }
}

private struct FocusBlockInProgress: Codable, Equatable, Sendable {
    let id: UUID
    let intention: String
    let startedAt: Date
    let timeZoneIdentifier: String
    let utcOffsetSeconds: Int
    let baselineSource: FocusActivitySource
    var segments: [FocusActivitySegment]
    var gaps: [FocusGap]
    var activeSource: FocusActivitySource?
    var activeStartedAt: Date?
    var lastObservedAt: Date
}

/// Local persistence and measurement for intentional focus blocks.
///
/// It records only app names and browser hosts. It never infers distraction:
/// the user can explicitly label observed sources after the block ends.
public struct FocusDataStore: Codable, Equatable, Sendable {
    public private(set) var completedBlocks: [FocusBlock]
    private var activeBlock: FocusBlockInProgress?

    public init(completedBlocks: [FocusBlock] = []) {
        self.completedBlocks = completedBlocks.sorted { $0.startedAt < $1.startedAt }
        self.activeBlock = nil
    }

    public var hasActiveBlock: Bool {
        activeBlock != nil
    }

    public var activeIntention: String? {
        activeBlock?.intention
    }

    public mutating func resume(at date: Date) {
        guard var activeBlock else { return }
        closeActiveSegment(in: &activeBlock, at: activeBlock.lastObservedAt)
        if date > activeBlock.lastObservedAt {
            activeBlock.gaps.append(FocusGap(reason: .unobserved, startedAt: activeBlock.lastObservedAt, endedAt: date))
        }
        activeBlock.lastObservedAt = date
        self.activeBlock = activeBlock
    }

    public mutating func start(
        intention: String,
        source: FocusActivitySource,
        at date: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        guard activeBlock == nil else { return }
        activeBlock = FocusBlockInProgress(
            id: UUID(),
            intention: intention.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: date,
            timeZoneIdentifier: timeZone.identifier,
            utcOffsetSeconds: timeZone.secondsFromGMT(for: date),
            baselineSource: source,
            segments: [],
            gaps: [],
            activeSource: source,
            activeStartedAt: date,
            lastObservedAt: date
        )
    }

    public mutating func record(source: FocusActivitySource, at date: Date = Date()) {
        guard var activeBlock, date >= activeBlock.lastObservedAt else { return }

        if activeBlock.activeSource == source {
            activeBlock.lastObservedAt = date
            self.activeBlock = activeBlock
            return
        }

        closeActiveSegment(in: &activeBlock, at: date)
        activeBlock.activeSource = source
        activeBlock.activeStartedAt = date
        activeBlock.lastObservedAt = date
        self.activeBlock = activeBlock
    }

    public mutating func recordUnobservedGap(since lastObservedAt: Date, at date: Date = Date()) {
        guard var activeBlock, date >= activeBlock.lastObservedAt else { return }
        let gapStart = max(activeBlock.startedAt, min(lastObservedAt, date))
        closeActiveSegment(in: &activeBlock, at: gapStart)
        if date > gapStart {
            activeBlock.gaps.append(FocusGap(reason: .unobserved, startedAt: gapStart, endedAt: date))
        }
        activeBlock.lastObservedAt = date
        self.activeBlock = activeBlock
    }

    /// Excludes a verified no-input interval from observed activity. It is
    /// retained as evidence, not treated as a distraction classification.
    public mutating func recordNoInput(since lastInputAt: Date, at date: Date = Date()) {
        guard var activeBlock, date >= activeBlock.lastObservedAt else { return }
        let gapStart = max(activeBlock.startedAt, min(lastInputAt, date))
        closeActiveSegment(in: &activeBlock, at: gapStart)

        if date > gapStart {
            if let lastGap = activeBlock.gaps.last,
               lastGap.reason == .noInput,
               lastGap.endedAt >= gapStart {
                activeBlock.gaps.removeLast()
                activeBlock.gaps.append(FocusGap(reason: .noInput, startedAt: min(lastGap.startedAt, gapStart), endedAt: date))
            } else {
                activeBlock.gaps.append(FocusGap(reason: .noInput, startedAt: gapStart, endedAt: date))
            }
        }
        activeBlock.lastObservedAt = date
        self.activeBlock = activeBlock
    }

    @discardableResult
    public mutating func finish(at date: Date = Date()) -> FocusBlock? {
        guard var activeBlock else { return nil }
        closeActiveSegment(in: &activeBlock, at: date)
        let block = FocusBlock(
            id: activeBlock.id,
            intention: activeBlock.intention,
            startedAt: activeBlock.startedAt,
            endedAt: date,
            timeZoneIdentifier: activeBlock.timeZoneIdentifier,
            utcOffsetSeconds: activeBlock.utcOffsetSeconds,
            baselineSource: activeBlock.baselineSource,
            segments: activeBlock.segments,
            gaps: activeBlock.gaps
        )
        completedBlocks.append(block)
        completedBlocks.sort { $0.startedAt < $1.startedAt }
        self.activeBlock = nil
        return block
    }

    public mutating func review(blockID: UUID, review: FocusBlockReview) {
        guard let index = completedBlocks.firstIndex(where: { $0.id == blockID }) else { return }
        completedBlocks[index].review = review
    }

    private mutating func closeActiveSegment(in activeBlock: inout FocusBlockInProgress, at date: Date) {
        guard let source = activeBlock.activeSource, let startedAt = activeBlock.activeStartedAt else { return }
        let endedAt = max(startedAt, date)
        if endedAt > startedAt {
            activeBlock.segments.append(FocusActivitySegment(source: source, startedAt: startedAt, endedAt: endedAt))
        }
        activeBlock.activeSource = nil
        activeBlock.activeStartedAt = nil
        activeBlock.lastObservedAt = endedAt
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
