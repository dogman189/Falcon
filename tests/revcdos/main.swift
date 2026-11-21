func runTests() {
    testManifestConstants()
    testMissingAssetsReportsBinaries()
    testResolvedFileURLRejectsTraversal()
    testContentTypeAndBrotliRules()
    testBundledClientDefinition()
    testBrotliResponseHeaders()
    do {
        try testServerAppliesHeadersOverHTTP()
        try testStartThrowsWhenPortUnavailable()
    } catch {
        fatalError("server tests failed: \(error)")
    }
    print("ALL TESTS PASSED")
}

runTests()
