import XCTest
@testable import MCPCore

final class MediaSkipReasonTests: XCTestCase {

    func testExpectedSkips() {
        let expectedCases: [MediaSkipReason] = [
            .noExtractDomain("instagram.com"),
            .noContent,
            .noSpeech,
            .noProcessor,
            .placeholderOnly("document"),
        ]
        for reason in expectedCases {
            XCTAssertTrue(reason.isExpectedSkip, "\(reason) should be an expected skip")
        }
    }

    func testFailureCases() {
        let failureCases: [MediaSkipReason] = [
            .fileNotFound,
            .fileUnreadable,
            .fileOversized(25_000_000),
            .processingFailed("keyframe extraction"),
            .processingTimedOut,
            .notAuthorized,
            .ssrfBlocked,
            .httpError(404),
        ]
        for reason in failureCases {
            XCTAssertFalse(reason.isExpectedSkip, "\(reason) should NOT be an expected skip")
        }
    }

    func testReportLabelIncludesDomain() {
        let reason = MediaSkipReason.noExtractDomain("instagram.com")
        XCTAssertTrue(reason.reportLabel.contains("instagram.com"))
    }

    func testReportLabelIncludesFileSize() {
        let reason = MediaSkipReason.fileOversized(25_000_000)
        XCTAssertTrue(reason.reportLabel.contains("25"))
    }

    func testReportLabelIncludesHTTPCode() {
        let reason = MediaSkipReason.httpError(404)
        XCTAssertTrue(reason.reportLabel.contains("404"))
    }

    func testReportLabelIncludesErrorDescription() {
        let reason = MediaSkipReason.processingFailed("keyframe extraction")
        XCTAssertTrue(reason.reportLabel.contains("keyframe extraction"))
    }

    func testCodableRoundTrip() throws {
        let reasons: [MediaSkipReason] = [
            .noExtractDomain("instagram.com"),
            .fileOversized(25_000_000),
            .httpError(404),
            .processingFailed("test error"),
            .fileNotFound,
            .noContent,
        ]
        let data = try JSONEncoder().encode(reasons)
        let decoded = try JSONDecoder().decode([MediaSkipReason].self, from: data)
        XCTAssertEqual(reasons, decoded)
    }
}

final class MediaAuditReportTests: XCTestCase {

    func testEmptyReportReturnsNil() {
        let report = MediaAuditReport()
        XCTAssertNil(report.formatted())
    }

    func testAllSuccessShowsAnalyzedOnly() {
        var report = MediaAuditReport()
        report.recordSuccess(category: .photos)
        report.recordSuccess(category: .photos)
        report.recordSuccess(category: .audios)

        let text = report.formatted()!
        XCTAssertTrue(text.contains("[MEDIA AUDIT]"))
        XCTAssertTrue(text.contains("Total: 3 media items"))
        XCTAssertTrue(text.contains("Analyzed: 3 (100.0%)"))
        XCTAssertTrue(text.contains("Photos:"))
        XCTAssertTrue(text.contains("Audios:"))
        XCTAssertFalse(text.contains("Failed:"))
        XCTAssertFalse(text.contains("Skipped"))
        XCTAssertFalse(text.contains("Not analyzed"))
    }

    func testMixedReport() {
        var report = MediaAuditReport()
        report.recordSuccess(category: .photos)
        report.recordSuccess(category: .photos)
        report.recordFailure(category: .photos, path: "/path/to/img.heic", reason: .fileOversized(25_000_000))
        report.recordSuccess(category: .audios)
        report.recordExpectedSkip(category: .links, reason: .noExtractDomain("instagram.com"))
        report.recordExpectedSkip(category: .links, reason: .noExtractDomain("instagram.com"))
        report.recordPlaceholder(typeName: "document")

        let text = report.formatted()!
        XCTAssertTrue(text.contains("Total: 7 media items"))
        XCTAssertTrue(text.contains("Analyzed: 3"))
        XCTAssertTrue(text.contains("Photos:"))
        XCTAssertTrue(text.contains("2/3"))
        XCTAssertTrue(text.contains("Failed: 1"))
        XCTAssertTrue(text.contains("img.heic"))
        XCTAssertTrue(text.contains("file too large (25MB)"))
        XCTAssertTrue(text.contains("Skipped (expected): 2"))
        XCTAssertTrue(text.contains("2x no-extract domain (instagram.com)"))
        XCTAssertTrue(text.contains("Not analyzed (placeholder only): 1"))
        XCTAssertTrue(text.contains("1x document"))
    }

    func testOnlyPlaceholders() {
        var report = MediaAuditReport()
        report.recordPlaceholder(typeName: "document")
        report.recordPlaceholder(typeName: "document")
        report.recordPlaceholder(typeName: "contact")

        let text = report.formatted()!
        XCTAssertTrue(text.contains("Total: 3 media items"))
        XCTAssertTrue(text.contains("Analyzed: 0 (0.0%)"))
        XCTAssertTrue(text.contains("Not analyzed (placeholder only): 3"))
        XCTAssertTrue(text.contains("2x document"))
        XCTAssertTrue(text.contains("1x contact"))
    }

    func testTotalAndAnalyzedCounts() {
        var report = MediaAuditReport()
        report.recordSuccess(category: .photos)
        report.recordFailure(category: .videos, path: "/v.mp4", reason: .fileNotFound)
        report.recordExpectedSkip(category: .links, reason: .noContent)
        report.recordPlaceholder(typeName: "location")

        XCTAssertEqual(report.total, 4)
        XCTAssertEqual(report.analyzed, 1)
    }

    func testMerge() {
        var a = MediaAuditReport()
        a.recordSuccess(category: .photos)
        a.recordSuccess(category: .photos)

        var b = MediaAuditReport()
        b.recordSuccess(category: .audios)
        b.recordFailure(category: .videos, path: "/v.mp4", reason: .fileNotFound)

        a.merge(b)

        XCTAssertEqual(a.total, 4)
        XCTAssertEqual(a.analyzed, 3)
        XCTAssertEqual(a.failures.count, 1)
    }

    func testCodableRoundTrip() throws {
        var report = MediaAuditReport()
        report.recordSuccess(category: .photos)
        report.recordFailure(category: .videos, path: "/v.mp4", reason: .fileNotFound)
        report.recordExpectedSkip(category: .links, reason: .noExtractDomain("facebook.com"))
        report.recordPlaceholder(typeName: "document")

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(MediaAuditReport.self, from: data)
        XCTAssertEqual(decoded.formatted(), report.formatted())
    }
}
