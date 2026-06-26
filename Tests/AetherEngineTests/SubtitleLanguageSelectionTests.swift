import Testing
import Foundation
@testable import AetherEngine

/// Issue #73: at the end of a successful load the engine activates the first subtitle track whose
/// language matches an ordered preference, so a host honors a saved subtitle-language preference from
/// one open instead of language-matching `subtitleTracks` itself. Unlike audio there is no explicit
/// index override and no default fallback: no match means "keep subtitles off". These cover the pure
/// resolution in isolation.
struct SubtitleLanguageSelectionTests {

    private func track(_ id: Int, _ lang: String?) -> TrackInfo {
        TrackInfo(id: id, name: "s\(id)", codec: "subrip", language: lang, channels: 0, isDefault: false)
    }

    @Test("first matching preference selects its track")
    func firstMatch() {
        let tracks = [track(0, "en"), track(1, "de")]
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["de"]) == 1)
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["en"]) == 0)
    }

    @Test("preference order beats track order")
    func preferenceOrder() {
        let tracks = [track(0, "fr"), track(1, "de"), track(2, "en")]
        // en is on a later track than de, but en is the earlier preference -> en wins.
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["en", "de"]) == 2)
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["de", "en"]) == 1)
    }

    @Test("no preference match selects nothing (subtitles stay off)")
    func noMatchIsNil() {
        let tracks = [track(0, "fr"), track(1, "es")]
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["en"]) == nil)
    }

    @Test("empty preferences select nothing (the default-off no-op)")
    func emptyPreferences() {
        let tracks = [track(0, "en"), track(1, "de")]
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: []) == nil)
    }

    @Test("a source with no subtitle tracks selects nothing")
    func noSubtitles() {
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: [], preferredLanguages: ["en"]) == nil)
    }

    @Test("preference matches a track tagged with a 3-letter code")
    func synonymTrack() {
        let tracks = [track(0, "jpn"), track(1, "eng")]
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["en"]) == 1)
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["ja"]) == 0)
    }

    @Test("an untagged subtitle track never matches")
    func untaggedNeverMatches() {
        let tracks = [track(0, nil), track(1, "")]
        #expect(AetherEngine.selectSubtitleIndex(
            tracks: tracks, preferredLanguages: ["en"]) == nil)
    }
}
