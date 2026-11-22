import Foundation

func testDownloaderStoresAssetsOnSuccess() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let served = root.appendingPathComponent("served", isDirectory: true)
    try FileManager.default.createDirectory(at: served, withIntermediateDirectories: true)
    let archive = makeArchive(folders: [
        ("vcbr", ReVCDOSAssetStore.assetNames.map { ($0, "DATA-\($0)") }),
    ])
    try archive.write(to: served.appendingPathComponent("archive.bin"))
    let fakeDist = served.appendingPathComponent("dist", isDirectory: true)
    try FileManager.default.createDirectory(at: fakeDist, withIntermediateDirectories: true)
    for name in ["index.html", "index.js", "game.js"] {
        try Data("x".utf8).write(to: fakeDist.appendingPathComponent(name))
    }

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    proc.arguments = ["-m", "http.server", "18317", "--bind", "127.0.0.1", "--directory", served.path]
    try proc.run()
    defer { proc.terminate() }
    Thread.sleep(forTimeInterval: 0.5)

    let dest = root.appendingPathComponent("dest", isDirectory: true)
    let downloader = ReVCDOSAssetDownloader(
        archiveURL: URL(string: "http://127.0.0.1:18317/archive.bin")!,
        destinationRoot: dest,
        distSourceURL: fakeDist,
        callbackQueue: .global()
    )
    var progress: [Double] = []
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Void, Error>?
    downloader.download(progress: { progress.append($0) }, completion: { result = $0; semaphore.signal() })
    _ = semaphore.wait(timeout: .now() + 30)
    guard case .success? = result else {
        fatalError("download failed: \(String(describing: result))")
    }
    assert(ReVCDOSAssetStore.isReady(at: dest))
    assert(!progress.isEmpty)
    assert(!downloader.isDownloading)
}

func testDownloaderFailureLeavesNoMarker() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let dest = root.appendingPathComponent("dest", isDirectory: true)
    let downloader = ReVCDOSAssetDownloader(
        archiveURL: URL(string: "http://127.0.0.1:1/nope.bin")!,
        destinationRoot: dest,
        callbackQueue: .global()
    )
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Void, Error>?
    downloader.download(progress: { _ in }, completion: { result = $0; semaphore.signal() })
    _ = semaphore.wait(timeout: .now() + 20)
    guard case .failure? = result else {
        fatalError("expected failure")
    }
    assert(!ReVCDOSAssetStore.isReady(at: dest))
    downloader.cancel()
    assert(!downloader.isDownloading)
}
