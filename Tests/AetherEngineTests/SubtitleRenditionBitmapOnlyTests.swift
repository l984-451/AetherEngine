import XCTest
@testable import AetherEngine

/// Covers the bitmap-only decoy filter. When the native mov_text path
/// (`prepareNativeSubtitles`, #55) is active it already lists every TEXT
/// subtitle track in AVKit's picker, so the decoy path
/// (`advertiseSubtitleRenditions`) must advertise ONLY bitmap tracks
/// (PGS / DVB / DVD / XSUB) to avoid double-listing — while keeping image
/// subs selectable (the host overlay paints them). With the filter off the
/// behavior is unchanged: every track is advertised.
final class SubtitleRenditionBitmapOnlyTests: XCTestCase {

    private func sampleTracks() -> [TrackInfo] {
        [
            TrackInfo(id: 2, name: "English (SRT)", codec: "subrip", language: "en", isDefault: true),
            TrackInfo(id: 3, name: "Chinese (PGS)", codec: "hdmv_pgs_subtitle", language: "zh", isDefault: false),
            TrackInfo(id: 4, name: "German (ASS)", codec: "ass", language: "de", isDefault: false),
            TrackInfo(id: 5, name: "French (VOBSUB)", codec: "dvd_subtitle", language: "fr", isDefault: false),
        ]
    }

    func test_allTracksAdvertisedWhenNotBitmapOnly() {
        // Today's behavior: text + bitmap all advertised (decoy is the only path).
        let renditions = AetherEngine.makeSubtitleRenditions(from: sampleTracks(), bitmapOnly: false)
        XCTAssertEqual(Set(renditions.map(\.trackIndex)), [2, 3, 4, 5])
    }

    func test_bitmapOnlySkipsTextTracksKeepsImage() {
        // Combined mode: native mov_text owns text, decoy owns image only.
        let renditions = AetherEngine.makeSubtitleRenditions(from: sampleTracks(), bitmapOnly: true)
        let indices = Set(renditions.map(\.trackIndex))
        XCTAssertEqual(indices, [3, 5], "Only PGS (3) and DVD/VOBSUB (5) should survive")
        XCTAssertFalse(indices.contains(2), "SRT (text) must not double-list")
        XCTAssertFalse(indices.contains(4), "ASS (text) must not double-list")
    }

    func test_bitmapCodecPredicateMatchesNativeExclusionSet() {
        for codec in ["hdmv_pgs_subtitle", "dvb_subtitle", "dvd_subtitle", "xsub", "vobsub", "pgssub"] {
            XCTAssertTrue(AetherEngine.isBitmapSubtitleCodec(codec), "\(codec) should be bitmap")
        }
        for codec in ["subrip", "ass", "ssa", "mov_text", "webvtt"] {
            XCTAssertFalse(AetherEngine.isBitmapSubtitleCodec(codec), "\(codec) should be text")
        }
    }
}
