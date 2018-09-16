import XCTest
import Dispatch
import Deferred

class PerformanceTests: XCTestCase {

    private let iterationCount = 10_000

    // MARK: - GCD

    func testDispatchAsyncOnSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let group = DispatchGroup()

        measure {
            for _ in 0 ..< iterationCount {
                group.enter()
                queue.async {
                    group.leave()
                }
            }

            group.wait()
        }
    }

    func testDoubleDispatchAsyncOnSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let group = DispatchGroup()

        measure {
            for _ in 0 ..< iterationCount {
                group.enter()
                queue.async {
                    queue.async {
                        group.leave()
                    }
                }
            }

            group.wait()
        }
    }

    func testTripleDispatchAsyncOnSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let group = DispatchGroup()

        measure {
            for _ in 0 ..< iterationCount {
                group.enter()
                queue.async {
                    queue.async {
                        queue.async {
                            group.leave()
                        }
                    }
                }
            }

            group.wait()
        }
    }

    func testDispatchAsyncOnConcurrentQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()
        func noop() {}

        measure {
            for _ in 0 ..< iterationCount {
                queue.async(group: group, execute: noop)
            }

            XCTAssertEqual(group.wait(timeout: .now() + 1), .success)
        }
    }

    // MARK: - Deferred

    func testUponToSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let group = DispatchGroup()

        measure {
            let deferred = Deferred<Bool>()

            for _ in 0 ..< iterationCount {
                group.enter()
                deferred.upon(queue) { _ in
                    group.leave()
                }
            }

            deferred.fill(with: true)
            group.wait()
        }
    }

    func testDoubleUponToSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let group = DispatchGroup()

        measure {
            let deferred = Deferred<Bool>()

            for _ in 0 ..< iterationCount {
                group.enter()
                deferred.upon(queue) { _ in
                    deferred.upon(queue) { _ in
                        group.leave()
                    }
                }
            }

            deferred.fill(with: true)
            group.wait()
        }
    }

    func testTripleUponSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let group = DispatchGroup()

        measure {
            let deferred = Deferred<Bool>()

            for _ in 0 ..< iterationCount {
                group.enter()
                deferred.upon(queue) { _ in
                    deferred.upon(queue) { _ in
                        deferred.upon(queue) { _ in
                            group.leave()
                        }
                    }
                }
            }

            deferred.fill(with: true)
            group.wait()
        }
    }

    func testFillWithUponToConcurrentQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()
        var deferreds = [Deferred<Bool>]()

        let metrics = PerformanceTests.defaultPerformanceMetrics
        measureMetrics(metrics, automaticallyStartMeasuring: false) {
            deferreds.removeAll(keepingCapacity: true)

            for _ in 0 ..< iterationCount {
                let deferred = Deferred<Bool>()
                group.enter()
                deferred.upon(queue) { _ in
                    group.leave()
                }
                deferreds.append(deferred)
            }

            startMeasuring()
            for deferred in deferreds {
                deferred.fill(with: true)
            }

            XCTAssertEqual(group.wait(timeout: .now() + 1), .success)
            stopMeasuring()
        }
    }

}
