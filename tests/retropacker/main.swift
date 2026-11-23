import Foundation

func runTests() {
    testCleanTitleFromFilename()
    testCleanTitleKeepsMixedCaseAndHandlesMultipleDots()
    testDetectsUniqueExtension()
    testExtensionNormalizationIgnoresCaseAndLeadingDot()
    testUnknownOrMissingExtensionReturnsNoSystems()
    testAmbiguousExtensionReturnsMultipleSystems()
    testAmbiguousExtensionsCoverEverySharedExtension()
    testCatalogContainsUniversalSystems()
    testCatalogEntriesAreWellFormed()
    do {
        try testCatalogRoundTripsThroughCodable()
    } catch {
        fatalError("catalog Codable test failed: \(error)")
    }
    testParsesProgressEvent()
    testParsesCompleteEvent()
    testParsesFailureEvent()
    testIgnoresUnknownEvent()
    testAcceptsIntegerPercent()
    testRejectsPayloadsMissingRequiredKeys()
    testRejectsMalformedProgressPercent()
    testIgnoresNonDictionaryBody()
    do {
        try testPackRequestEncodesExpectedJSONKeys()
        try testPackRequestRoundTripsThroughCodable()
    } catch {
        fatalError("pack request Codable test failed: \(error)")
    }
    print("ALL TESTS PASSED")
}

runTests()
