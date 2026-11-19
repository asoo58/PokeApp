import XCTest
@testable import AlexisAsya

/// Vérifie que plusieurs clics rapprochés sont bien traités comme un seul.
@MainActor
final class DebouncedActionTests: XCTestCase {

    private func makeGuard(
        interval: TimeInterval = 1,
        now: @escaping () -> Date
    ) -> DebouncedAction {
        DebouncedAction(interval: interval, now: now)
    }

    func testFirstTapRunsImmediately() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard { clock }
        var executions = 0

        let executed = guardAction.run { executions += 1 }

        XCTAssertTrue(executed)
        XCTAssertEqual(executions, 1)
    }

    func testTenRapidTapsCountAsOne() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard { clock }
        var executions = 0

        for _ in 0..<10 {
            guardAction.run { executions += 1 }
        }

        XCTAssertEqual(executions, 1)
    }

    func testIgnoredTapsReturnFalseAndDoNotRunAction() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard { clock }

        XCTAssertTrue(guardAction.run {})

        clock = clock.addingTimeInterval(0.5)
        let results = (0..<5).map { _ in guardAction.run {} }

        XCTAssertEqual(results, Array(repeating: false, count: 5))
    }

    func testTapJustBeforeIntervalIsIgnored() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard(interval: 1) { clock }
        var executions = 0

        guardAction.run { executions += 1 }
        clock = clock.addingTimeInterval(0.999)
        guardAction.run { executions += 1 }

        XCTAssertEqual(executions, 1)
    }

    func testTapExactlyAtIntervalRunsAgain() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard(interval: 1) { clock }
        var executions = 0

        guardAction.run { executions += 1 }
        clock = clock.addingTimeInterval(1)
        guardAction.run { executions += 1 }

        XCTAssertEqual(executions, 2)
    }

    func testResetAllowsImmediateNewTap() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard(interval: 10) { clock }
        var executions = 0

        guardAction.run { executions += 1 }
        guardAction.reset()
        clock = clock.addingTimeInterval(0.01)
        guardAction.run { executions += 1 }

        XCTAssertEqual(executions, 2)
    }

    func testDifferentKeysHaveIndependentWindows() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard(interval: 10) { clock }
        var executedKeys: [String] = []

        guardAction.run(key: "pikachu") { executedKeys.append("pikachu") }
        guardAction.run(key: "pikachu") { executedKeys.append("pikachu") }
        guardAction.run(key: "raichu") { executedKeys.append("raichu") }

        XCTAssertEqual(executedKeys, ["pikachu", "raichu"])
    }

    func testResetOneKeyKeepsOtherKeyBlocked() {
        var clock = Date(timeIntervalSince1970: 0)
        var guardAction = makeGuard(interval: 10) { clock }
        var executions: [String] = []

        guardAction.run(key: "a") { executions.append("a") }
        guardAction.run(key: "b") { executions.append("b") }
        guardAction.reset(key: "a")
        guardAction.run(key: "a") { executions.append("a") }
        guardAction.run(key: "b") { executions.append("b") }

        XCTAssertEqual(executions, ["a", "b", "a"])
    }
}
