import Foundation

final class ReVCDOSAssetDownloader {
    static let defaultArchiveURL = URL(string: "https://folder.morgen.qzz.io/revcdos.bin")!

    private let session: URLSession
    private let fileManager: FileManager
    private let archiveURL: URL
    private let destinationRoot: URL?
    private let callbackQueue: DispatchQueue
    private let stateLock = NSLock()
    private var currentTask: URLSessionDownloadTask?
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
        callbackQueue: DispatchQueue = .main
    ) {
        self.session = session
        self.fileManager = fileManager
        self.archiveURL = archiveURL
        self.destinationRoot = destinationRoot
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

        let resumeURL = root.appendingPathComponent(".download-resume")
        stateLock.lock(); _isDownloading = true; stateLock.unlock()

        let finish: (Result<Void, Error>) -> Void = { result in
            self.stateLock.lock()
            self._isDownloading = false
            let finishedTask = self.currentTask
            self.currentTask = nil
            self.stateLock.unlock()
            if let finishedTask { ProgressObserver.detach(finishedTask) }
            self.callbackQueue.async { completion(result) }
        }

        let handler: (URL?, URLResponse?, Error?) -> Void = { location, _, error in
            if let error {
                if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    try? resumeData.write(to: resumeURL)
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
                    to: root.appendingPathComponent("extract", isDirectory: true),
                    fileManager: self.fileManager
                )
                let vcbr = root.appendingPathComponent("vcbr", isDirectory: true)
                if self.fileManager.fileExists(atPath: vcbr.path) {
                    try self.fileManager.removeItem(at: vcbr)
                }
                try self.fileManager.createDirectory(at: vcbr, withIntermediateDirectories: true)
                for file in extracted {
                    try self.fileManager.copyItem(
                        at: file,
                        to: vcbr.appendingPathComponent(file.lastPathComponent)
                    )
                }
                guard ReVCDOSAssetStore.assetNames.allSatisfy({ name in
                    self.fileManager.fileExists(atPath: vcbr.appendingPathComponent(name).path)
                }) else {
                    finish(.failure(DownloadError.incompleteArchive))
                    return
                }
                if let bundleDist = ReVCDOSAssetManifest.bundleRootURL(fileManager: self.fileManager)?
                    .appendingPathComponent("dist"),
                   self.fileManager.fileExists(atPath: bundleDist.path) {
                    let localDist = root.appendingPathComponent("dist")
                    if self.fileManager.fileExists(atPath: localDist.path) {
                        try self.fileManager.removeItem(at: localDist)
                    }
                    try self.fileManager.copyItem(at: bundleDist, to: localDist)
                }
                try ReVCDOSAssetStore.markReady(at: root, fileManager: self.fileManager)
                try? self.fileManager.removeItem(at: resumeURL)
                try? self.fileManager.removeItem(at: root.appendingPathComponent("extract"))
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
        stateLock.unlock()
        task?.cancel()
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
