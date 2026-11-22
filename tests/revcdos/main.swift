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
    do { try testArchiveExtractsVcbrFiles() } catch { fatalError("archive test failed: \(error)") }
    testArchiveTruncatedThrows()
    do { try testDownloaderStoresAssetsOnSuccess() } catch { fatalError("downloader test failed: \(error)") }
    do { try testDownloaderFailureLeavesNoMarker() } catch { fatalError("downloader failure test failed: \(error)") }
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
