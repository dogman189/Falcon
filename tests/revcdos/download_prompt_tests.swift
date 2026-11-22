import Foundation

func testDownloadPromptWhenMissing() {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    // A fresh install has no downloaded assets, so the UI must prompt instead of launching.
    assert(!ReVCDOSAssetStore.isReady(at: root))
    assert(ReVCDOSAssetStore.shouldPromptForDownload(at: root))
    assert(ReVCDOSAssetStore.assetNames.count == 4)
    let downloader = ReVCDOSAssetDownloader(destinationRoot: root)
    assert(!downloader.isDownloading)
}
