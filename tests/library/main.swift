import Foundation

func runTests() throws {
    try testMetadataStoreDefaultsAreEmpty()
    try testRecordLaunchSetsLastPlayedAndIncrementsCount()
    try testRecordSessionEndAccumulatesPlaytime()
    try testSetSystemIDPersistsAcrossReload()
    try testRemoveDeletesClientMetadata()
    try testFinalizeSessionRecordsDurationOnce()

    try testResolveTypeUsesBundledDefaults()
    try testResolveTypeUsesKnownRetroSystemID()
    try testResolveTypeFallsBackToWebForUnknownCustom()
    try testShelvesBuildRecentlyPlayedAndTypeShelves()
    try testRecentlyPlayedIsCappedAndStillAppearsInTypeShelf()
    try testTypeShelvesAreOrderedAndSortedByRecentThenName()
    print("ALL TESTS PASSED")
}

do {
    try runTests()
} catch {
    fatalError("library metadata store tests failed: \(error)")
}
