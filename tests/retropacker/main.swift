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
    testParsesNSNumberBoundaryPercents()
    do {
        try testParsesJSONDecodedBoundaryPercents()
    } catch {
        fatalError("JSON-decoded boundary percent test failed: \(error)")
    }
    testRejectsPayloadsMissingRequiredKeys()
    testRejectsMalformedProgressPercent()
    testIgnoresNonDictionaryBody()
    do {
        try testPackRequestEncodesExpectedJSONKeys()
        try testPackRequestRoundTripsThroughCodable()
    } catch {
        fatalError("pack request Codable test failed: \(error)")
    }
    do {
        try testImportGeneratedClientWritesFileAndRecord()
        try testImportGeneratedClientKeepsDuplicateNamesDistinct()
        try testImportGeneratedClientSanitizesNameForFileName()
        try testImportGeneratedClientAvoidsDoubleHtmlExtension()
        try testFileImportStillWorksWithInjectedDirectory()
        try testImportGeneratedClientPersistsSystemIDMetadata()
    } catch {
        fatalError("custom client store test failed: \(error)")
    }
    print("ALL TESTS PASSED")
}

runTests()
