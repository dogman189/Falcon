import Foundation
import Network

enum ReVCDOSLocalServerError: Error {
    case startFailed(String)
}

extension ReVCDOSLocalServerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .startFailed(let message): return message
        }
    }
}

final class ReVCDOSLocalServer {
    private let rootURL: URL
    private let port: UInt16
    private let queue = DispatchQueue(label: "revcdos.local.server")
    private var listeners: [NWListener] = []
    private(set) var isRunning = false

    init(rootURL: URL, port: UInt16 = ReVCDOSAssetManifest.port) {
        self.rootURL = rootURL
        self.port = port
    }

    func start() throws {
        guard listeners.isEmpty else { return }

        var started: [NWListener] = []
        var firstFailure: Error?
        for host in [NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!), .ipv6(IPv6Address("::1")!)] {
            do {
                started.append(try makeListener(host: host))
            } catch {
                if firstFailure == nil { firstFailure = error }
            }
        }
        guard !started.isEmpty else {
            throw firstFailure ?? ReVCDOSLocalServerError.startFailed("No loopback listener could start")
        }
        listeners = started
        isRunning = true
    }

    func stop() {
        listeners.forEach { $0.cancel() }
        listeners.removeAll()
        isRunning = false
    }

    private func makeListener(host: NWEndpoint.Host) throws -> NWListener {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ReVCDOSLocalServerError.startFailed("Invalid port \(self.port)")
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: host, port: port)
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            throw ReVCDOSLocalServerError.startFailed(error.localizedDescription)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var failureMessage: String?
        let lock = NSLock()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            case .failed(let error):
                lock.lock()
                failureMessage = error.localizedDescription
                lock.unlock()
                semaphore.signal()
            case .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)

        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            lock.lock()
            failureMessage = "Listener start timed out"
            lock.unlock()
        }
        lock.lock()
        let failure = failureMessage
        lock.unlock()
        if let failure {
            listener.cancel()
            throw ReVCDOSLocalServerError.startFailed("\(host): \(failure)")
        }
        return listener
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(from: connection, accumulated: Data())
    }

    private func receiveRequest(from connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer.subdata(in: 0..<end.lowerBound)
                let firstLine = String(data: headerData.split(separator: 0x0A).first ?? Data(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let response: ReVCDOSHTTPResponse
                if let parsed = ReVCDOSHTTPResponder.parseRequestLine(firstLine) {
                    response = ReVCDOSHTTPResponder.response(
                        method: parsed.method, path: parsed.path, rootURL: rootURL
                    )
                } else {
                    response = ReVCDOSHTTPResponse(
                        status: 400,
                        reason: "Bad Request",
                        headers: [
                            ("Content-Type", "text/plain"),
                            ("Content-Length", "11"),
                            ("Connection", "close"),
                        ],
                        body: Data("Bad Request".utf8)
                    )
                }
                self.send(response, on: connection)
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receiveRequest(from: connection, accumulated: buffer)
        }
    }

    private func send(_ response: ReVCDOSHTTPResponse, on connection: NWConnection) {
        var payload = Data("HTTP/1.1 \(response.status) \(response.reason)\r\n".utf8)
        for (name, value) in response.headers {
            payload.append(Data("\(name): \(value)\r\n".utf8))
        }
        payload.append(Data("Connection: close\r\n\r\n".utf8))
        payload.append(response.body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
