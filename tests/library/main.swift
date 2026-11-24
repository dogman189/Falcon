import Foundation

func runTests() throws {
    try testMetadataStoreDefaultsAreEmpty()
    try testRecordLaunchSetsLastPlayedAndIncrementsCount()
    try testRecordSessionEndAccumulatesPlaytime()
    try testSetSystemIDPersistsAcrossReload()
    try testRemoveDeletesClientMetadata()
    print("ALL TESTS PASSED")
}

do {
    try runTests()
} catch {
    fatalError("library metadata store tests failed: \(error)")
}
