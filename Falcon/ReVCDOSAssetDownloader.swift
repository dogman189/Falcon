import Foundation

final class ReVCDOSAssetDownloader {
    static let defaultArchiveURL = URL(string: "https://folder.morgen.qzz.io/revcdos.bin")!

    private let session: URLSession
    private let fileManager: FileManager
    private let archiveURL: URL
    private let destinationRoot: URL?
    private let distSourceURL: URL?
    private let callbackQueue: DispatchQueue
    private let stateLock = NSLock()
    private var currentTask: URLSessionDownloadTask?
    private var currentSession: URLSession?
    private var activeRoot: URL?
    private var _isDownloading = false

    var isDownloading: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _isDownloading
    }

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        archiveURL: URL = ReVCDOSAssetDownloader.defaultArchiveURL,
        destinationRoot: URL? = nil,
        distSourceURL: URL? = nil,
        callbackQueue: DispatchQueue = .main
    ) {
        self.session = session
        self.fileManager = fileManager
        self.archiveURL = archiveURL
        self.destinationRoot = destinationRoot
        self.distSourceURL = distSourceURL
        self.callbackQueue = callbackQueue
    }

    func download(
        progress: @escaping (Double) -> Void,
        status: @escaping (String) -> Void = { _ in },
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !isDownloading else {
            completion(.failure(DownloadError.alreadyDownloading))
            return
        }
        let root: URL
        if let destinationRoot {
            root = destinationRoot
        } else if let appRoot = ReVCDOSAssetStore.rootURL(fileManager: fileManager) {
            root = appRoot
        } else {
            completion(.failure(DownloadError.noDestination))
            return
        }
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        // Any new attempt invalidates the current install immediately.
        ReVCDOSAssetStore.clearMarker(at: root, fileManager: fileManager)
        let staging = root.appendingPathComponent("staging", isDirectory: true)
        if fileManager.fileExists(atPath: staging.path) {
            try? fileManager.removeItem(at: staging)
        }
        try? fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

        let resumeURL = root.appendingPathComponent(".download-resume")
        stateLock.lock()
        _isDownloading = true
        activeRoot = root
        stateLock.unlock()

        let finish: (Result<Void, Error>) -> Void = { result in
            self.stateLock.lock()
            self._isDownloading = false
            self.currentTask = nil
            let finishedSession = self.currentSession
            self.currentSession = nil
            self.activeRoot = nil
            self.stateLock.unlock()
            finishedSession?.finishTasksAndInvalidate()
            if case .failure = result {
                try? self.fileManager.removeItem(at: staging)
            }
            self.callbackQueue.async { completion(result) }
        }

        let handler: (URL?, URLResponse?, Error?) -> Void = { location, _, error in
            if let error {
                if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    self.storeResumeData(resumeData, root: root)
                }
                finish(.failure(error))
                return
            }
            guard let location else {
                finish(.failure(DownloadError.noDestination))
                return
            }
            do {
                self.callbackQueue.async { status("Extracting…"); progress(1.0) }
                let extractRoot = staging.appendingPathComponent("extract", isDirectory: true)
                let extracted = try ReVCDOSPackedArchive.extract(
                    from: location,
                    to: extractRoot,
                    fileManager: self.fileManager
                )
                let stagedVcbr = staging.appendingPathComponent("vcbr", isDirectory: true)
                if self.fileManager.fileExists(atPath: stagedVcbr.path) {
                    try self.fileManager.removeItem(at: stagedVcbr)
                }
                let extractedVcbr = extractRoot.appendingPathComponent("vcbr", isDirectory: true)
                if self.fileManager.fileExists(atPath: extractedVcbr.path) {
                    try self.fileManager.moveItem(at: extractedVcbr, to: stagedVcbr)
                } else {
                    try self.fileManager.createDirectory(at: stagedVcbr, withIntermediateDirectories: true)
                    for file in extracted.vcbr {
                        try self.fileManager.moveItem(
                            at: file,
                            to: stagedVcbr.appendingPathComponent(file.lastPathComponent)
                        )
                    }
                }
                guard ReVCDOSAssetStore.assetNames.allSatisfy({ name in
                    self.fileManager.fileExists(atPath: stagedVcbr.appendingPathComponent(name).path)
                }) else {
                    finish(.failure(DownloadError.incompleteArchive))
                    return
                }

                let stagedDist = staging.appendingPathComponent("dist", isDirectory: true)
                let sourceDist = self.distSourceURL ?? ReVCDOSAssetManifest.bundleRootURL(fileManager: self.fileManager)?
                    .appendingPathComponent("dist")
                if let sourceDist, self.fileManager.fileExists(atPath: sourceDist.path) {
                    if self.fileManager.fileExists(atPath: stagedDist.path) {
                        try self.fileManager.removeItem(at: stagedDist)
                    }
                    try self.fileManager.copyItem(at: sourceDist, to: stagedDist)
                }

                let extractedVcsky = extractRoot.appendingPathComponent("vcsky", isDirectory: true)
                let stagedVcsky = staging.appendingPathComponent("vcsky", isDirectory: true)
                if self.fileManager.fileExists(atPath: extractedVcsky.path) {
                    if self.fileManager.fileExists(atPath: stagedVcsky.path) {
                        try self.fileManager.removeItem(at: stagedVcsky)
                    }
                    try self.fileManager.moveItem(at: extractedVcsky, to: stagedVcsky)
                }

                self.callbackQueue.async { status("Installing…") }
                for folder in ["vcbr", "dist", "vcsky"] {
                    let staged = staging.appendingPathComponent(folder, isDirectory: true)
                    let target = root.appendingPathComponent(folder, isDirectory: true)
                    guard self.fileManager.fileExists(atPath: staged.path) else { continue }
                    if self.fileManager.fileExists(atPath: target.path) {
                        try self.fileManager.removeItem(at: target)
                    }
                    try self.fileManager.moveItem(at: staged, to: target)
                }
                try ReVCDOSAssetStore.markReady(at: root, fileManager: self.fileManager)
                try? self.fileManager.removeItem(at: resumeURL)
                try? self.fileManager.removeItem(at: staging)
                finish(.success(()))
            } catch {
                finish(.failure(error))
            }
        }

        let delegate = DownloadProgressDelegate(progress: progress, queue: callbackQueue)
        let downloadSession = URLSession(configuration: session.configuration, delegate: delegate, delegateQueue: nil)
        let task: URLSessionDownloadTask
        if let resumeData = try? Data(contentsOf: resumeURL) {
            task = downloadSession.downloadTask(withResumeData: resumeData, completionHandler: handler)
        } else {
            task = downloadSession.downloadTask(with: archiveURL, completionHandler: handler)
        }
        stateLock.lock()
        currentTask = task
        currentSession = downloadSession
        stateLock.unlock()
        task.resume()
    }

    func cancel() {
        stateLock.lock()
        let task = currentTask
        let root = activeRoot
        stateLock.unlock()
        guard let task else { return }
        task.cancel { resumeData in
            guard let root, let resumeData else { return }
            self.storeResumeData(resumeData, root: root)
        }
    }

    func storeResumeData(_ data: Data, root: URL) {
        try? data.write(to: root.appendingPathComponent(".download-resume"))
    }

    enum DownloadError: Error {
        case alreadyDownloading
        case noDestination
        case incompleteArchive
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let progress: (Double) -> Void
    let queue: DispatchQueue

    init(progress: @escaping (Double) -> Void, queue: DispatchQueue) {
        self.progress = progress
        self.queue = queue
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fraction = downloadTask.progress.fractionCompleted
        if fraction.isFinite && fraction >= 0 {
            queue.async { self.progress(min(max(fraction, 0), 1)) }
        } else if totalBytesExpectedToWrite > 0 {
            let writtenFraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            queue.async { self.progress(min(max(writtenFraction, 0), 1)) }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
