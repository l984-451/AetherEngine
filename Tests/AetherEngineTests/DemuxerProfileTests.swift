import Testing
@testable import AetherEngine

struct DemuxerProfileTests {
    @Test("playback profile keeps the large probe budget + prefetch")
    func playbackDefaults() {
        let p = DemuxerOpenProfile.playback
        #expect(p.probesize == 50 * 1024 * 1024)
        #expect(p.maxAnalyzeDuration == 60 * 1_000_000)
        #expect(p.avioPrefetch == true)
        #expect(p.avioChunkSize == 4 * 1024 * 1024)
    }

    @Test("stillExtraction profile is random-access tuned")
    func stillExtractionTuned() {
        let p = DemuxerOpenProfile.stillExtraction
        #expect(p.avioPrefetch == false)
        #expect(p.avioChunkSize < DemuxerOpenProfile.playback.avioChunkSize)
        #expect(p.probesize < DemuxerOpenProfile.playback.probesize)
        #expect(p.maxAnalyzeDuration < DemuxerOpenProfile.playback.maxAnalyzeDuration)
    }

    /// Issue #27 (Sodalite): a stalled still-extraction chunk read could ride a
    /// ~35s syncRequest park times up to 3 retries times 2 URL passes, freezing the
    /// scrub-preview. The disposable thumbnail fetch must cap its per-chunk budget
    /// and retries far below the playback path.
    @Test("stillExtraction caps the per-chunk request budget below playback")
    func stillExtractionReadBudget() {
        let still = DemuxerOpenProfile.stillExtraction
        let playback = DemuxerOpenProfile.playback
        #expect(still.avioRequestTimeout < playback.avioRequestTimeout)
        #expect(still.avioMaxRetries < playback.avioMaxRetries)
        #expect(still.avioMaxRetries >= 1)
    }
}
