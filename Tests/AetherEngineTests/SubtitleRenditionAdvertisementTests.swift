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

    func test_iso639TwoLanguagesAreEmittedAsBCP47ForAVKit() {
        let renditions = AetherEngine.makeSubtitleRenditions(from: [
            TrackInfo(id: 2, name: "ENG (srt)", codec: "subrip", language: "eng", isDefault: true),
            TrackInfo(id: 3, name: "German", codec: "subrip", language: "ger", isDefault: false),
            TrackInfo(id: 4, name: "Portuguese", codec: "subrip", language: "pt-BR", isDefault: false),
        ])

        XCTAssertEqual(renditions.map(\.language), ["en", "de", "pt-BR"])
        XCTAssertEqual(renditions[0].name, "English (SRT)")
        XCTAssertEqual(renditions[1].name, "German (SRT)")
        XCTAssertEqual(renditions[2].name, "Portuguese (SRT)")
    }

    func test_unknownLanguageFallsBackToUnd() {
        let renditions = AetherEngine.makeSubtitleRenditions(from: [
            TrackInfo(id: 2, name: "", codec: "subrip", language: nil, isDefault: false),
        ])

        XCTAssertEqual(renditions[0].language, "und")
        XCTAssertEqual(renditions[0].name, "Subtitle 1 (SRT)")
    }

    func test_genericTrackTitleIsNotUsedAsDisplayName() {
        let renditions = AetherEngine.makeSubtitleRenditions(from: [
            TrackInfo(id: 2, name: "Track 2 (srt)", codec: "subrip", language: nil, isDefault: false),
            TrackInfo(id: 3, name: "Subtitle 3", codec: "subrip", language: nil, isDefault: false),
            TrackInfo(id: 4, name: "Track 4 (pgs)", codec: "hdmv_pgs_subtitle", language: nil, isDefault: false),
        ])

        XCTAssertEqual(renditions.map(\.name), [
            "Subtitle 1 (SRT)",
            "Subtitle 2 (SRT)",
            "Subtitle 3 (PGS)",
        ])
    }

    func test_hlsLanguageTagCanonicalizesCommonContainerCodes() {
        XCTAssertEqual(AetherEngine.hlsLanguageTag(from: "eng"), "en")
        XCTAssertEqual(AetherEngine.hlsLanguageTag(from: "deu"), "de")
        XCTAssertEqual(AetherEngine.hlsLanguageTag(from: "ger"), "de")
        XCTAssertEqual(AetherEngine.hlsLanguageTag(from: "EN_us"), "en-US")
        XCTAssertEqual(AetherEngine.hlsLanguageTag(from: nil), "und")
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
