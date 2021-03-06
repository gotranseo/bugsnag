import XCTest
@testable import Vapor
@testable import Bugsnag
import HTTP

class MiddlewareTests: XCTestCase {
    private var middleware: Bugsnag.Middleware!
    private var reporter: ReporterMock!

    static let allTests = [
        ("testThatErrorsNotConformingToAbortErrorAreRethrown", testThatErrorsNotConformingToAbortErrorAreRethrown),
        ("testThatAbortErrorsAreRethrown", testThatAbortErrorsAreRethrown),
        ("testThatAbortErrorsAreReported", testThatAbortErrorsAreReported),
        ("testThatErrorsNotConformingToAbortErrorAreReported", testThatErrorsNotConformingToAbortErrorAreReported),
    ]


    override func setUp() {
        self.reporter = ReporterMock()
        self.middleware = try! Bugsnag.Middleware(reporter: reporter)
    }

    override func tearDown() {
        self.reporter = nil
        self.middleware = nil
    }


    // MARK: - Rethrowing.

    func testThatErrorsNotConformingToAbortErrorAreRethrown() {
        let next = ErrorResponderMock(error: MyCustomError())
        let req = Request(method: .get, uri: "some-random-uri")

        do {
            _ = try middleware.respond(to: req, chainingTo: next)
            XCTFail("Error not conforming to AbortError wasn't rethrown.")
        } catch {}
    }

    func testThatAbortErrorsAreRethrown() {
        let next = ErrorResponderMock(error: Abort.badRequest)
        let req = Request(method: .get, uri: "some-random-uri")

        do {
            _ = try middleware.respond(to: req, chainingTo: next)
            XCTFail("Error conforming to AbortError wasn't rethrown.")
        } catch {}
    }


    // MARK: - Reporting

    func testThatAbortErrorsAreReported() {
        let next = ErrorResponderMock(error: Abort.badRequest)
        let req = Request(method: .get, uri: "some-random-uri")

        do {
            _ = try middleware.respond(to: req, chainingTo: next)
        } catch {}

        let reportedError = self.reporter.lastReport?.0 as? AbortError

        XCTAssertEqual(reportedError?.reason, Abort.badRequest.reason)
        XCTAssertEqual(reportedError?.status, Abort.badRequest.status)
        XCTAssertEqual(reportedError?.metadata, Abort.badRequest.metadata)
        XCTAssertEqual(reporter.lastReport!.request?.uri.description, req.uri.description)
    }

    func testThatErrorsNotConformingToAbortErrorAreReported() {
        let next = ErrorResponderMock(error: MyCustomError())
        let req = Request(method: .get, uri: "some-random-uri")

        do {
            _ = try middleware.respond(to: req, chainingTo: next)
        } catch {}

        let reportedError = self.reporter.lastReport?.0 as? MyCustomError

        XCTAssertEqual(reportedError?.value, 1337)
        XCTAssertEqual(reporter.lastReport!.request?.uri.description, req.uri.description)
    }
}
