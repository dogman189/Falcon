import Foundation

func testBundledCoverSearchNamesAreCurated() throws {
    let minecraft = GameClient.bundled.first { $0.id == "bundled:1.8.8-wasm" }
    let revcdos = GameClient.bundled.first { $0.id == "bundled:reVCDOS" }

    assert(minecraft?.coverSearchName == "Minecraft Java Edition")
    assert(revcdos?.coverSearchName == "Grand Theft Auto: Vice City")
}

func testCustomCoverSearchNameFallsBackToTrimmedName() throws {
    let custom = GameClient(
        id: "custom:test",
        name: "  My Game  ",
        source: .custom(fileURL: URL(fileURLWithPath: "/tmp/MyGame.html"))
    )

    assert(custom.coverSearchName == "My Game")
}

func testWikipediaParseSearchResultsReturnsThumbnailCandidates() throws {
    let json = """
    {
      "query": {
        "pages": {
          "2": {
            "pageid": 2,
            "index": 2,
            "title": "No Thumbnail Game",
            "description": "A game without art"
          },
          "1": {
            "pageid": 1,
            "index": 1,
            "title": "Cover Game",
            "description": "A game with art",
            "thumbnail": {
              "source": "https://upload.wikimedia.org/cover.jpg",
              "width": 600,
              "height": 800
            }
          }
        }
      }
    }
    """
    let data = Data(json.utf8)

    let candidates = try WikipediaCoverService.parseSearchResults(data: data)

    assert(candidates.count == 1)
    assert(candidates[0].title == "Cover Game")
    assert(candidates[0].description == "A game with art")
    assert(candidates[0].thumbnailURL == URL(string: "https://upload.wikimedia.org/cover.jpg"))
}

func testWikipediaBestCandidatePrefersFirstThumbnailResult() throws {
    let candidates = [
        WikipediaCoverCandidate(
            title: "First Match",
            description: "Best match",
            thumbnailURL: URL(string: "https://upload.wikimedia.org/first.jpg")!
        ),
        WikipediaCoverCandidate(
            title: "Second Match",
            description: "Another match",
            thumbnailURL: URL(string: "https://upload.wikimedia.org/second.jpg")!
        ),
    ]

    let best = WikipediaCoverService.bestCandidate(from: candidates, term: "First Match")

    assert(best == candidates[0])
}
