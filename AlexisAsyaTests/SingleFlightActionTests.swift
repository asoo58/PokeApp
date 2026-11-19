import XCTest
@testable import AlexisAsya

/// Petit verrou de test : retient la première opération tant qu'on ne l'ouvre pas.
private actor TestGate {
    private var isOpen = false
    private var didStart = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    /// Retient l'opération tant que `open()` n'a pas été appelé.
    func wait() async {
        didStart = true
        resumeAll(&startWaiters)
        guard !isOpen else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    /// Attend que `wait()` ait été atteint, sans risque de course avec lui.
    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func open() {
        isOpen = true
        resumeAll(&openWaiters)
    }

    private func resumeAll(_ waiters: inout [CheckedContinuation<Void, Never>]) {
        let pending = waiters
        waiters.removeAll()
        for continuation in pending { continuation.resume() }
    }
}

@MainActor
private final class Counter {
    var value = 0
    func increment() { value += 1 }
}

/// Vérifie que deux chargements réseau identiques ne tournent pas en parallèle.
@MainActor
final class SingleFlightActionTests: XCTestCase {

    func testConcurrentCallsExecuteOnlyOnce() async {
        let action = SingleFlightAction()
        let gate = TestGate()
        let counter = Counter()

        let first = Task { @MainActor in
            await action.run {
                counter.increment()
                await gate.wait()
            }
        }
        await gate.waitUntilStarted()

        let second = Task { @MainActor in
            await action.run { counter.increment() }
        }
        let third = Task { @MainActor in
            await action.run { counter.increment() }
        }

        await gate.open()
        await first.value
        await second.value
        await third.value

        XCTAssertEqual(counter.value, 1)
    }

    func testRunningFlagReflectsCurrentOperation() async {
        let action = SingleFlightAction()
        let gate = TestGate()

        let task = Task { @MainActor in
            await action.run {
                await gate.wait()
            }
        }
        await gate.waitUntilStarted()

        XCTAssertTrue(action.running)

        await gate.open()
        await task.value

        XCTAssertFalse(action.running)
    }

    func testNextCallAfterCompletionRunsAgain() async {
        let action = SingleFlightAction()
        var executions = 0

        await action.run { executions += 1 }
        await action.run { executions += 1 }
        await action.run { executions += 1 }

        XCTAssertEqual(executions, 3)
    }

    func testCallDuringOperationWithNoAwaitIsStillRejected() async {
        let action = SingleFlightAction()
        let gate = TestGate()
        let counter = Counter()

        let first = Task { @MainActor in
            await action.run {
                counter.increment()
                await gate.wait()
            }
        }
        await gate.waitUntilStarted()

        // La tâche est suspendue dans `gate.wait()` : une nouvelle tentative
        // doit être ignorée, même si son action n'a aucun `await`.
        await action.run { counter.increment() }
        await gate.open()
        await first.value

        XCTAssertEqual(counter.value, 1)
    }
}
