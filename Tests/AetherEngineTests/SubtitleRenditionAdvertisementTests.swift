import XCTest
@testable import AetherEngine

/// Covers the subtitle rendition list used to populate AVKit's picker.
/// AVPlayer does not expose in-segment mov_text tracks as legible options
/// by itself on the loopback HLS path, so every source subtitle track gets
/// an advertised rendition and the host overlay paints the selected cues.
final class SubtitleRenditionAdvertisementTests: XCTestCase {

    private func sampleTracks() -> [TrackInfo] {
        [
            TrackInfo(id: 2, name: "English (SRT)", codec: "subrip", language: "en", isDefault: true),
            TrackInfo(id: 3, name: "Chinese (PGS)", codec: "hdmv_pgs_subtitle", language: "zh", isDefault: false),
            TrackInfo(id: 4, name: "German (ASS)", codec: "ass", language: "de", isDefault: false),
            TrackInfo(id: 5, name: "French (VOBSUB)", codec: "dvd_subtitle", language: "fr", isDefault: false),
        ]
    }

    func test_allTracksAdvertised() {
        let renditions = AetherEngine.makeSubtitleRenditions(from: sampleTracks())
        XCTAssertEqual(Set(renditions.map(\.trackIndex)), [2, 3, 4, 5])
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
