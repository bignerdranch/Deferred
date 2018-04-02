import XCTest
import Dispatch
import Deferred

class PerformanceTests: XCTestCase {

    private let iterationCount = 10_000

    // MARK: - GCD

    func testDispatchAsyncOnSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let semaphore = DispatchSemaphore(value: 0)

        measure {
            for _ in 0 ..< iterationCount {
                queue.async {
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
    }

    func testDoubleDispatchAsyncOnSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let semaphore = DispatchSemaphore(value: 0)

        measure {
            for _ in 0 ..< iterationCount {
                queue.async {
                    queue.async {
                        semaphore.signal()
                    }
                }
                semaphore.wait()
            }
        }
    }

    func testTripleDispatchAsyncOnSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let semaphore = DispatchSemaphore(value: 0)

        measure {
            for _ in 0 ..< iterationCount {
                queue.async {
                    queue.async {
                        queue.async {
                            semaphore.signal()
                        }
                    }
                }
                semaphore.wait()
            }
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
        let semaphore = DispatchSemaphore(value: 0)

        measure {
            for _ in 0 ..< iterationCount {
                Deferred(filledWith: true).upon(queue) { _ in
                    semaphore.signal()
                }

                semaphore.wait()
            }
        }
    }

    func testDoubleUponToSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let semaphore = DispatchSemaphore(value: 0)

        measure {
            for _ in 0 ..< iterationCount {
                Deferred(filledWith: true).map(upon: .any()) { $0 }.upon(queue) { _ in
                    semaphore.signal()
                }

                semaphore.wait()
            }
        }
    }

    func testTripleUponSerialQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let semaphore = DispatchSemaphore(value: 0)

        measure {
            for _ in 0 ..< iterationCount {
                Deferred(filledWith: true).map(upon: .any()) { $0 }.map(upon: .any()) { $0 }.upon(queue) { _ in
                    semaphore.signal()
                }

                semaphore.wait()
            }
        }
    }

    func testFillWithUponToConcurrentQueue() {
        let queue = DispatchQueue(label: #function, qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()
        var deferreds = [Deferred<Bool>]()

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || swift(>=4.1)
        let metrics = PerformanceTests.defaultPerformanceMetrics
        #else
        let metrics = PerformanceTests.defaultPerformanceMetrics()
        #endif

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
