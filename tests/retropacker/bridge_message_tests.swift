import Foundation

func testParsesProgressEvent() {
    let body: [String: Any] = ["type": "progress", "id": "1", "percent": 0.5, "message": "Packing..."]
    assert(RetroPackerBridgeParser.parse(body) == .progress(id: "1", percent: 0.5, message: "Packing..."))
}

func testParsesCompleteEvent() {
    let body: [String: Any] = ["type": "complete", "id": "1", "fileName": "Mario.html", "htmlBase64": "PGh0bWw+"]
    assert(RetroPackerBridgeParser.parse(body) == .complete(id: "1", fileName: "Mario.html", htmlBase64: "PGh0bWw+"))
}

func testParsesFailureEvent() {
    let body: [String: Any] = ["type": "error", "id": "1", "message": "Bad ROM"]
    assert(RetroPackerBridgeParser.parse(body) == .failed(id: "1", message: "Bad ROM"))
}

func testIgnoresUnknownEvent() {
    let body: [String: Any] = ["type": "wat"]
    assert(RetroPackerBridgeParser.parse(body) == nil)
}

func testAcceptsIntegerPercent() {
    let body: [String: Any] = ["type": "progress", "id": "1", "percent": 0.0, "message": "Starting"]
    assert(RetroPackerBridgeParser.parse(body) == .progress(id: "1", percent: 0.0, message: "Starting"))

    let integerBody: [String: Any] = ["type": "progress", "id": "1", "percent": 1, "message": "Done"]
    assert(RetroPackerBridgeParser.parse(integerBody) == .progress(id: "1", percent: 1.0, message: "Done"))

    let numberBody: [String: Any] = ["type": "progress", "id": "1", "percent": NSNumber(value: 0.25), "message": "Quarter"]
    assert(RetroPackerBridgeParser.parse(numberBody) == .progress(id: "1", percent: 0.25, message: "Quarter"))
}

func testRejectsPayloadsMissingRequiredKeys() {
    assert(RetroPackerBridgeParser.parse(["type": "progress", "percent": 0.5, "message": "Packing..."]) == nil)
    assert(RetroPackerBridgeParser.parse(["id": "1", "percent": 0.5, "message": "Packing..."]) == nil)
    assert(RetroPackerBridgeParser.parse(["type": "progress", "id": "", "percent": 0.5, "message": "Packing..."]) == nil)
    assert(RetroPackerBridgeParser.parse(["type": "complete", "id": "1", "fileName": "Mario.html"]) == nil)
    assert(RetroPackerBridgeParser.parse(["type": "complete", "id": "1", "htmlBase64": "PGh0bWw+"]) == nil)
    assert(RetroPackerBridgeParser.parse(["type": "error", "id": "1"]) == nil)
}

func testRejectsMalformedProgressPercent() {
    let stringPercent: [String: Any] = ["type": "progress", "id": "1", "percent": "0.5", "message": "Packing..."]
    assert(RetroPackerBridgeParser.parse(stringPercent) == nil)

    let missingPercent: [String: Any] = ["type": "progress", "id": "1", "message": "Packing..."]
    assert(RetroPackerBridgeParser.parse(missingPercent) == nil)

    let boolPercent: [String: Any] = ["type": "progress", "id": "1", "percent": true, "message": "Packing..."]
    assert(RetroPackerBridgeParser.parse(boolPercent) == nil)
}

func testIgnoresNonDictionaryBody() {
    assert(RetroPackerBridgeParser.parse("not a message") == nil)
    assert(RetroPackerBridgeParser.parse(42) == nil)
    assert(RetroPackerBridgeParser.parse(["progress", "1"]) == nil)
}

func testPackRequestEncodesExpectedJSONKeys() throws {
    let request = RetroPackRequest(
        id: "abc",
        romBase64: "cm9t",
        romName: "mario.nes",
        system: "nes",
        title: "Mario",
        color: "#ff0000"
    )

    let data = try JSONEncoder().encode(request)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    assert(object != nil)
    assert(Set(object!.keys) == ["id", "romBase64", "romName", "system", "title", "color"])
    assert(object?["id"] as? String == "abc")
    assert(object?["romBase64"] as? String == "cm9t")
    assert(object?["romName"] as? String == "mario.nes")
    assert(object?["system"] as? String == "nes")
    assert(object?["title"] as? String == "Mario")
    assert(object?["color"] as? String == "#ff0000")
}

func testPackRequestRoundTripsThroughCodable() throws {
    let request = RetroPackRequest(
        id: "42",
        romBase64: "AAECAw==",
        romName: "sonic.md",
        system: "genesis",
        title: "Sonic",
        color: "#123456"
    )
    let data = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(RetroPackRequest.self, from: data)
    assert(decoded.id == request.id)
    assert(decoded.romBase64 == request.romBase64)
    assert(decoded.romName == request.romName)
    assert(decoded.system == request.system)
    assert(decoded.title == request.title)
    assert(decoded.color == request.color)
}
