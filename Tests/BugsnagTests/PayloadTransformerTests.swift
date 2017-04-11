import XCTest
@testable import Vapor
@testable import Bugsnag
import HTTP

class PayloadTransformerTests: XCTestCase {
    private var config: ConfigurationMock!
    private var payloadTransformer: PayloadTransformer!
    private var payload: JSON!

    static let allTests = [
        ("testThatItUsesApiKeyFromConfig", testThatItUsesApiKeyFromConfig),
        ("testThatItBuildsErrorPayloadCorrectly", testThatItBuildsErrorPayloadCorrectly),
        ("testThatItBuildsAppPayloadCorrectly", testThatItBuildsAppPayloadCorrectly),
        ("testThatSeverityIsCorrect", testThatSeverityIsCorrect),
        ("testThatItHandlesCustomMetadata", testThatItHandlesCustomMetadata),
        ("testThatItBuildsNotifierPayloadCorrectly", testThatItBuildsNotifierPayloadCorrectly)
    ]

    override func setUp() {
        let drop = Droplet(
            arguments: nil,
            workDir: nil,
            environment: Environment.custom("mock-environment"),
            config: nil,
            localization: nil,
            log: nil
        )
        let config = ConfigurationMock()
        self.payloadTransformer = PayloadTransformer(drop: drop, config: config)
        let req = try! Request(method: .get, uri: "http://some-random-url.com/payload-test")
        req.parameters = ["url": "value"]
        req.query = ["query": "value"]
        req.formURLEncoded = ["form": "value"]
        req.json = try! JSON(node: Node(["json": "value"]))
        req.headers = ["Content-Type": "application/json"]
        self.payload = try! self.payloadTransformer.payloadFor(
            message: "Test message",
            metadata: Node(["key": "value"]),
            request: req,
            severity: .warning
        )
    }

    override func tearDown() {
        self.config = nil
        self.payloadTransformer = nil
    }


    func testThatItUsesApiKeyFromConfig() {
        XCTAssertEqual(payload["apiKey"]?.string, "1337")
    }

    func testThatItHandlesRequestPayloadCorrectly() {
        let request = payload["events"]?[0]?["metaData"]?["request"]
        let expectedHeaders = Node(["Content-Type": "application/json"])
        let expectedUrlParams = Node(["url": "value"])
        let expectedQueryParams = Node(["query": "value"])
        let expectedFormParams = Node(["form": "value"])
        let expectedJsonParams = Node(["json": "value"])

        XCTAssertEqual(request?["method"]?.string, "GET")
        XCTAssertEqual(request?["headers"]?.node, expectedHeaders)
        XCTAssertEqual(request?["urlParameters"]?.node, expectedUrlParams)
        XCTAssertEqual(request?["queryParameters"]?.node, expectedQueryParams)
        XCTAssertEqual(request?["formParameters"]?.node, expectedFormParams)
        XCTAssertEqual(request?["jsonParameters"]?.node, expectedJsonParams)
        XCTAssertEqual(request?["url"]?.string, "/payload-test")
    }

    func testThatItBuildsErrorPayloadCorrectly() {
        let event = payload["events"]?[0]

        XCTAssertEqual(event?["payloadVersion"]?.int, 2)
        XCTAssertEqual(event?["exceptions"]?[0]?["errorClass"]?.string, "Test message")
        XCTAssertEqual(event?["exceptions"]?[0]?["message"]?.string, "Test message")
    }

    func testThatItBuildsAppPayloadCorrectly() {
        let app = payload["events"]?[0]?["app"]

        XCTAssertEqual(app?["releaseStage"]?.string, "mock-environment")
        XCTAssertEqual(app?["type"]?.string, "Vapor")
    }

    func testThatSeverityIsCorrect() {
        XCTAssertEqual(payload["events"]?[0]?["severity"]?.string, Severity.warning.rawValue)
    }

    func testThatItHandlesCustomMetadata() {
        XCTAssertEqual(payload["events"]?[0]?["metaData"]?["metaData"]?["key"]?.string, "value")
    }

    func testThatItBuildsNotifierPayloadCorrectly() {
        let notifier = payload["notifier"]

        XCTAssertEqual(notifier?["name"]?.string, "Bugsnag Vapor")
        XCTAssertEqual(notifier?["version"]?.string, "1.0.11")
        XCTAssertEqual(notifier?["url"]?.string, "https://github.com/nodes-vapor/bugsnag")
    }
}