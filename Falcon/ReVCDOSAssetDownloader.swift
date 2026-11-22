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
            let finishedTask = self.currentTask
            self.currentTask = nil
            self.activeRoot = nil
            self.stateLock.unlock()
            if let finishedTask { ProgressObserver.detach(finishedTask) }
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
                let extracted = try ReVCDOSPackedArchive.extractVcbrBRFiles(
                    from: location,
                    to: staging.appendingPathComponent("extract", isDirectory: true),
                    fileManager: self.fileManager
                )
                let stagedVcbr = staging.appendingPathComponent("vcbr", isDirectory: true)
                try self.fileManager.createDirectory(at: stagedVcbr, withIntermediateDirectories: true)
                for file in extracted {
                    try self.fileManager.copyItem(
                        at: file,
                        to: stagedVcbr.appendingPathComponent(file.lastPathComponent)
                    )
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
                    try self.fileManager.copyItem(at: sourceDist, to: stagedDist)
                }

                for folder in ["vcbr", "dist"] {
                    let target = root.appendingPathComponent(folder, isDirectory: true)
                    if self.fileManager.fileExists(atPath: target.path) {
                        try self.fileManager.removeItem(at: target)
                    }
                    try self.fileManager.moveItem(
                        at: staging.appendingPathComponent(folder, isDirectory: true),
                        to: target
                    )
                }
                try ReVCDOSAssetStore.markReady(at: root, fileManager: self.fileManager)
                try? self.fileManager.removeItem(at: resumeURL)
                try? self.fileManager.removeItem(at: staging)
                finish(.success(()))
            } catch {
                finish(.failure(error))
            }
        }

        let task: URLSessionDownloadTask
        if let resumeData = try? Data(contentsOf: resumeURL) {
            task = session.downloadTask(withResumeData: resumeData, completionHandler: handler)
        } else {
            task = session.downloadTask(with: archiveURL, completionHandler: handler)
        }
        stateLock.lock(); currentTask = task; stateLock.unlock()
        ProgressObserver.attach(to: task, progress: progress, queue: callbackQueue)
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

private final class ProgressObserver {
    private static let lock = NSLock()
    private static var observers: [URLSessionDownloadTask: ProgressObserver] = [:]
    private var observation: NSKeyValueObservation?

    static func attach(to task: URLSessionDownloadTask, progress: @escaping (Double) -> Void, queue: DispatchQueue) {
        let progressCall = progress
        let observer = ProgressObserver()
        observer.observation = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) { observed, _ in
            let fraction = observed.fractionCompleted
            queue.async { progressCall(fraction) }
        }
        lock.lock(); observers[task] = observer; lock.unlock()
    }

    static func detach(_ task: URLSessionDownloadTask) {
        lock.lock(); observers[task] = nil; lock.unlock()
    }
}
