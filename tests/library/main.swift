import Foundation

func runTests() throws {
    try testMetadataStoreDefaultsAreEmpty()
    try testRecordLaunchSetsLastPlayedAndIncrementsCount()
    try testRecordSessionEndAccumulatesPlaytime()
    try testSetSystemIDPersistsAcrossReload()
    try testRemoveDeletesClientMetadata()
    try testFinalizeSessionRecordsDurationOnce()
    try testPauseRecordsSegmentAndKeepsSessionStart()
    try testFailureThenRetryKeepsSessionStartAndLaunchCount()
    try testFailureThenBackToClientsFinalizesPausedSession()
    try testCorruptMetadataFileFallsBackToEmpty()

    try testResolveTypeUsesBundledDefaults()
    try testResolveTypeUsesKnownRetroSystemID()
    try testResolveTypeFallsBackToWebForUnknownCustom()
    try testShelvesBuildRecentlyPlayedAndTypeShelves()
    try testRecentlyPlayedIsCappedAndStillAppearsInTypeShelf()
    try testTypeShelvesAreOrderedAndSortedByRecentThenName()
    try testLibraryNavigationModelMapsDynamicSectionsWithPackerLast()

    try testCoverStorePrefersManualOverAuto()
    try testCoverStoreFallsBackToAutoWhenNoManual()
    try testLegacyRootCoverIsTreatedAsManual()
    try testResetManualCoverKeepsAuto()
    try testRemoveAllCoversDeletesManualAndAuto()

    try testBundledCoverSearchNamesAreCurated()
    try testCustomCoverSearchNameFallsBackToTrimmedName()
    try testWikipediaParseSearchResultsReturnsThumbnailCandidates()
    try testWikipediaBestCandidatePrefersFirstThumbnailResult()
    print("ALL TESTS PASSED")
}

do {
    try runTests()
} catch {
    fatalError("library metadata store tests failed: \(error)")
}
