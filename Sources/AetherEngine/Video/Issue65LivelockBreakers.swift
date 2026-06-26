import Foundation

// Decision helpers for the loopback-HLS VOD scrub-burst livelock (issue #65). Both are pure so the
// false-positive guards (the only thing standing between a real wedge and a healthy slow seek) are
// unit-testable without spinning up an AVPlayer or a producer.

/// Stuck-detection for the VOD backpressure park (issue #65, Piece A).
///
/// The producer parks in `awaitBackpressureRelease` until the consumer's fetch high-water
/// (`SegmentCache.targetIndex`) reaches a release target. A genuine wedge is the consumer target
/// frozen for `breakThresholdSeconds` while AVPlayer is stuck and issuing no forward segment request;
/// a slow-but-advancing consumer (cold cache, throttled CDN) keeps nudging the target up and must
/// NEVER trip the breaker. Feed `observe(currentTarget:)` once per ~1 s poll: it resets the stuck
/// timer whenever the target advances, so only a target that is frozen for the whole window trips.
struct BackpressureWedgeDetector {
    let breakThresholdSeconds: Int
    private var maxTargetSeen: Int
    private var stuckSeconds: Int = 0

    init(breakThresholdSeconds: Int, initialTarget: Int) {
        self.breakThresholdSeconds = breakThresholdSeconds
        self.maxTargetSeen = initialTarget
    }

    /// Returns `true` once the consumer fetch target has been frozen for `breakThresholdSeconds`.
    ///
    /// `wantsToPlay` is the play-intent guard (issue #65 pause false-positive). A paused or backgrounded
    /// consumer issues no forward segment request by design, so its frozen fetch target is NOT a wedge: when
    /// `wantsToPlay` is false the detector re-baselines to the current target and holds the stuck timer at
    /// zero, so a pause of any length never trips and the window after resume starts fresh. The legit wedge
    /// (AVPlayer wants to play but is starved, `timeControlStatus == .waitingToPlay`) keeps `wantsToPlay`
    /// true and still trips. Defaults to true so existing callers and live keep their prior behaviour.
    mutating func observe(currentTarget: Int, wantsToPlay: Bool = true) -> Bool {
        guard wantsToPlay else {
            if currentTarget > maxTargetSeen { maxTargetSeen = currentTarget }
            stuckSeconds = 0
            return false
        }
        if currentTarget > maxTargetSeen {
            maxTargetSeen = currentTarget
            stuckSeconds = 0
        } else {
            stuckSeconds += 1
        }
        return stuckSeconds >= breakThresholdSeconds
    }
}

/// Starvation predicate for a seek that did not land within its deadline (issue #65, Piece B).
///
/// During a pending zero-tolerance loopback seek AVPlayer holds the old frame, so `renderedTime` is
/// flat whether the seek is healthy-but-slow or wedged; it cannot distinguish them. What does: a
/// healthy seek refills AVPlayer's forward buffer (`bufferedEnd` climbs past `renderedTime`), while a
/// wedged seek is starved (the producer is parked, so `bufferedEnd` stays at the rendered position,
/// matching the reporter's `loaded=[]`). Returns `true` only when there is effectively no forward
/// buffer, i.e. AVPlayer is starved rather than slow.
func seekIsWedged(renderedTime: Double, bufferedEnd: Double, forwardBufferFloor: Double = 1.0) -> Bool {
    return (bufferedEnd - renderedTime) < forwardBufferFloor
}

/// Single-resume latch for the deadline-bounded seek (issue #65). The AVPlayer landing and the deadline
/// race to resume one continuation; whichever calls `claim()` first wins, the loser is a no-op. MainActor
/// isolated (so it is Sendable and capturable in the @Sendable seek completion) and only touched there.
@MainActor
final class SeekResumeGuard {
    private var claimed = false
    /// Returns `true` exactly once, to the first caller.
    func claim() -> Bool {
        if claimed { return false }
        claimed = true
        return true
    }
}

/// Thread-safe Double mirror so an off-main consumer (the producer pump re-anchoring on a wedge) can read
/// AVPlayer's last rendered position, which the engine updates on the main actor (issue #65).
final class AtomicDouble: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double
    init(_ initial: Double) { value = initial }
    func get() -> Double { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ newValue: Double) { lock.lock(); value = newValue; lock.unlock() }
}

/// Thread-safe Bool mirror so the off-main producer pump can read whether AVPlayer currently wants to play
/// (`timeControlStatus != .paused`), which the engine updates on the main actor. Lets the VOD backpressure
/// wedge detector suspend while the consumer is paused (issue #65 pause false-positive).
final class AtomicBool: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool
    init(_ initial: Bool) { value = initial }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ newValue: Bool) { lock.lock(); value = newValue; lock.unlock() }
}
