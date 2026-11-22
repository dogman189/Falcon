func runTests() {
    testManifestConstants()
    testMissingAssetsReportsBinaries()
    testResolvedFileURLRejectsTraversal()
    testContentTypeAndBrotliRules()
    testBundledClientDefinition()
    testPreflightReportsMissingBinary()
    testPreflightAllowsCompleteBundle()
    testVCSKYPathServedFromBundleRoot()
    do { try testAssetStoreReadiness() } catch { fatalError("asset store test failed: \(error)") }
    testBrotliResponseHeaders()
    testServerErrorDescribesItself()
    do {
        try testServerAppliesHeadersOverHTTP()
        try testStartThrowsWhenPortUnavailable()
    } catch {
        fatalError("server tests failed: \(error)")
    }
    print("ALL TESTS PASSED")
}

runTests()
