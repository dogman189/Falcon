import Foundation

/// A packing request handed to the hidden packing engine web view.
///
/// Encoded as JSON and injected into the vendored universal packer page by
/// `RetroPackerEngine` (Task 6). Keys stay camelCase so they match the shape
/// the injected JavaScript reads.
struct RetroPackRequest: Codable, Equatable {
    let id: String
    let romBase64: String
    let romName: String
    let system: String
    let title: String
    let color: String
}

/// An event emitted by the packing engine back into native code.
///
/// Mirrors the `type` values posted by the injected bridge script:
/// `progress`, `complete` and `error`.
enum RetroPackerBridgeEvent: Equatable {
    case progress(id: String, percent: Double, message: String)
    case complete(id: String, fileName: String, htmlBase64: String)
    case failed(id: String, message: String)
}

/// Defensive parser for `WKScriptMessage.body` payloads.
///
/// Messages arrive as `[String: Any]` from WebKit, so every field is
/// type-checked and malformed or unknown messages return `nil` instead of
/// trapping. `type` and a non-empty `id` are always required; each event
/// additionally requires its own fields.
enum RetroPackerBridgeParser {
    static func parse(_ body: Any) -> RetroPackerBridgeEvent? {
        guard let dictionary = body as? [String: Any],
              let type = dictionary["type"] as? String,
              let id = dictionary["id"] as? String,
              !id.isEmpty
        else {
            return nil
        }

        switch type {
        case "progress":
            guard let percent = double(dictionary["percent"]),
                  let message = dictionary["message"] as? String
            else {
                return nil
            }
            return .progress(id: id, percent: percent, message: message)

        case "complete":
            guard let fileName = dictionary["fileName"] as? String,
                  let htmlBase64 = dictionary["htmlBase64"] as? String
            else {
                return nil
            }
            return .complete(id: id, fileName: fileName, htmlBase64: htmlBase64)

        case "error":
            guard let message = dictionary["message"] as? String else {
                return nil
            }
            return .failed(id: id, message: message)

        default:
            return nil
        }
    }

    /// Accepts any numeric bridging for `percent` (`Double`, `Int`, `NSNumber`)
    /// while rejecting strings, booleans, NaN and infinity.
    private static func double(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        // Booleans bridge to CFBoolean-backed NSNumbers. Do not use `is Bool`:
        // on Darwin numeric 0/1 (including JSON-decoded and `NSNumber` values)
        // also satisfies it, which would drop 0% and 100% progress messages.
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
        let result = number.doubleValue
        return result.isFinite ? result : nil
    }
}
