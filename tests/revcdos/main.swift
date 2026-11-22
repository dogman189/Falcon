func runTests() {
    testManifestConstants()
    testMissingAssetsReportsBinaries()
    testResolvedFileURLRejectsTraversal()
    testContentTypeAndBrotliRules()
    testBundledClientDefinition()
    testPreflightReportsMissingBinary()
    testPreflightAllowsCompleteBundle()
    testVCSKYPathServedFromBundleRoot()
    do { try testArchiveRejectsDeduplicatedVcbrEntry() } catch { fatalError("dedup test failed: \(error)") }
    testStoreRootIsInApplicationSupport()
    do { try testReadinessIncludesDist() } catch { fatalError("readiness test failed: \(error)") }
    do { try testFailedRedownloadClearsMarker() } catch { fatalError("redownload test failed: \(error)") }
    do { try testCancelWritesResumeData() } catch { fatalError("cancel test failed: \(error)") }
    testDownloadPromptWhenMissing()
    do { try testServerRootSelection() } catch { fatalError("root selection test failed: \(error)") }
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
