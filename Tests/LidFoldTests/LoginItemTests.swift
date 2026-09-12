import XCTest
import ServiceManagement
@testable import LidFoldKit

private final class FakeLoginService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registerCount = 0
    var unregisterCount = 0
    var failure: Error?
    var result: SMAppService.Status = .enabled
    func register() throws {
        registerCount += 1
        if let failure { throw failure }
        status = result
    }
    func unregister() async throws {
        unregisterCount += 1
        if let failure { throw failure }
        status = .notRegistered
    }
}

@MainActor final class LoginItemTests: XCTestCase {
    func testRegistrationAndUnregistrationUseSystemState() async {
        let service = FakeLoginService()
        let model = LoginItemController(service: service)
        await model.setEnabled(true)
        XCTAssertEqual(model.status, .enabled)
        await model.setEnabled(true)
        XCTAssertEqual(service.registerCount, 1)
        await model.setEnabled(false)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertEqual(service.unregisterCount, 1)
    }

    func testPendingApprovalIsNotReportedAsEnabled() async {
        let service = FakeLoginService()
        service.result = .requiresApproval
        let model = LoginItemController(service: service)
        await model.setEnabled(true)
        XCTAssertTrue(model.registered)
        XCTAssertEqual(model.status, .requiresApproval)
        await model.setEnabled(true)
        XCTAssertEqual(service.registerCount, 1)
    }

    func testFailureDoesNotLeaveAnOptimisticOnSwitch() async {
        let service = FakeLoginService()
        service.failure = NSError(domain: "test", code: 1)
        let model = LoginItemController(service: service)
        await model.setEnabled(true)
        XCTAssertFalse(model.registered)
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.busy)
    }

    func testExternalSystemChangeIsReflectedOnRefresh() {
        let service = FakeLoginService()
        service.status = .enabled
        let model = LoginItemController(service: service)
        service.status = .notRegistered
        model.refresh()
        XCTAssertFalse(model.registered)
    }

    func testNotFoundBeforeFirstRegistrationCanStillRegister() async {
        let service = FakeLoginService()
        service.status = .notFound
        let model = LoginItemController(service: service)
        await model.setEnabled(true)
        XCTAssertTrue(model.registered)
        XCTAssertNil(model.error)
    }
}
