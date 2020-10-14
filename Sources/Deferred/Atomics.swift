//
//  Atomics.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/22/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

// swiftlint:disable type_name
// swiftlint:disable identifier_name

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if SWIFT_PACKAGE || (canImport(CAtomics) && !FORCE_PLAYGROUND_COMPATIBILITY)
@_implementationOnly import CAtomics
#elseif canImport(Darwin)
#warning("Using fallback implementation for Swift Playgrounds. This is unsafe for use in production. Check your build setup.")

typealias bnr_atomic_memory_order_t = memory_order

extension bnr_atomic_memory_order_t {
    static let relaxed = memory_order_relaxed
    static let acquire = memory_order_acquire
    static let release = memory_order_release
    static let acq_rel = memory_order_acq_rel
    static let seq_cst = memory_order_seq_cst
}

private extension Optional where Wrapped == UnsafeMutableRawPointer {
    func symbol<T>(named name: String, of _: T.Type = T.self, file: StaticString = #file, line: UInt = #line) -> T {
        assert("\(T.self)".hasPrefix("@convention(c)"), "Type must be a C symbol", file: file, line: line)
        guard let symbol = dlsym(self, name) else { preconditionFailure(String(cString: dlerror()), file: file, line: line) }
        return unsafeBitCast(symbol, to: T.self)
    }
}

/// Follows the routines in Apple's libc, defined by:
/// http://llvm.org/docs/Atomics.html#libcalls-atomic
private struct DarwinAtomics {
    let load: @convention(c) (Int, UnsafeMutableRawPointer, UnsafeMutableRawPointer, bnr_atomic_memory_order_t) -> Void
    let store: @convention(c) (Int, UnsafeMutableRawPointer, UnsafeMutableRawPointer, bnr_atomic_memory_order_t) -> Void
    let exchange: @convention(c) (Int, UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer, bnr_atomic_memory_order_t) -> Void
    let compareExchange: @convention(c) (Int, UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer, bnr_atomic_memory_order_t, bnr_atomic_memory_order_t) -> Bool

    static let shared: DarwinAtomics = {
        let library = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        return DarwinAtomics(
            load: library.symbol(named: "__atomic_load"),
            store: library.symbol(named: "__atomic_store"),
            exchange: library.symbol(named: "__atomic_exchange"),
            compareExchange: library.symbol(named: "__atomic_compare_exchange"))
    }()
}

typealias bnr_atomic_ptr_t = UnsafeMutablePointer<UnsafeRawPointer?>

func bnr_atomic_load(_ target: bnr_atomic_ptr_t, _ order: bnr_atomic_memory_order_t) -> UnsafeRawPointer? {
    var result: UnsafeRawPointer?
    DarwinAtomics.shared.load(MemoryLayout<UnsafeRawPointer?>.size, target, &result, order)
    return result
}

func bnr_atomic_exchange(_ target: bnr_atomic_ptr_t, _ desired: UnsafeRawPointer?, _ order: bnr_atomic_memory_order_t) -> UnsafeRawPointer? {
    var new = desired
    var old: UnsafeRawPointer?
    DarwinAtomics.shared.exchange(MemoryLayout<UnsafeRawPointer?>.size, target, &new, &old, order)
    return old
}

func bnr_atomic_compare_and_swap(_ target: bnr_atomic_ptr_t, _ expected: UnsafeRawPointer?, _ desired: UnsafeRawPointer?, _ order: bnr_atomic_memory_order_t, _ failureOrder: bnr_atomic_memory_order_t) -> Bool {
    var expected = expected
    var desired = desired
    return DarwinAtomics.shared.compareExchange(MemoryLayout<UnsafeRawPointer?>.size, target, &expected, &desired, order, failureOrder)
}

typealias bnr_atomic_flag_t = UnsafeMutablePointer<Bool>

func bnr_atomic_load(_ target: bnr_atomic_flag_t, _ order: bnr_atomic_memory_order_t) -> Bool {
    var result: Bool = false
    DarwinAtomics.shared.load(MemoryLayout<Bool>.size, target, &result, order)
    return result
}

func bnr_atomic_store(_ target: bnr_atomic_flag_t, _ desired: Bool, _ order: bnr_atomic_memory_order_t) {
    var desired = desired
    DarwinAtomics.shared.store(MemoryLayout<Bool>.size, target, &desired, order)
}
#else
#error("An implementation of threading primitives is not available on this platform. Please open an issue with the Deferred project.")
#endif

func bnr_atomic_load<T: AnyObject>(_ target: UnsafeMutablePointer<T?>, _ order: bnr_atomic_memory_order_t) -> T? {
    let rawTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: UnsafeRawPointer?.self)
    guard let opaqueResult = bnr_atomic_load(rawTarget, order) else { return nil }
    return Unmanaged<T>.fromOpaque(opaqueResult).takeUnretainedValue()
}

@discardableResult
func bnr_atomic_store<T: AnyObject>(_ target: UnsafeMutablePointer<T?>, _ desired: T?, _ order: bnr_atomic_memory_order_t) -> T? {
    let rawTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: UnsafeRawPointer?.self)
    let opaqueDesired: UnsafeMutableRawPointer?
    if let desired = desired {
        opaqueDesired = Unmanaged.passRetained(desired).toOpaque()
    } else {
        opaqueDesired = nil
    }
    guard let opaquePrevious = bnr_atomic_exchange(rawTarget, opaqueDesired, order) else { return nil }
    return Unmanaged<T>.fromOpaque(opaquePrevious).takeRetainedValue()
}

func bnr_atomic_initialize_once<T: AnyObject>(_ target: UnsafeMutablePointer<T?>, _ desired: T) -> Bool {
    let rawTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: UnsafeRawPointer?.self)
    let retainedDesired = Unmanaged.passRetained(desired)
    let wonRace = bnr_atomic_compare_and_swap(rawTarget, nil, retainedDesired.toOpaque(), .acq_rel, .acquire)
    if !wonRace {
        retainedDesired.release()
    }
    return wonRace
}

func bnr_atomic_load_and_wait<T: AnyObject>(_ target: UnsafeMutablePointer<T?>) -> T {
    let rawTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: UnsafeRawPointer?.self)
    var opaqueResult = bnr_atomic_load(rawTarget, .acquire)
    while opaqueResult == nil {
        #if canImport(Darwin)
        pthread_yield_np()
        #elseif canImport(Glibc)
        sched_yield()
        #endif
        opaqueResult = bnr_atomic_load(rawTarget, .relaxed)
    }
    return Unmanaged.fromOpaque(opaqueResult!).takeUnretainedValue()
}

@discardableResult
func bnr_atomic_initialize_once(_ target: UnsafeMutablePointer<Bool>, _ handler: () -> Void) -> Bool {
    guard !bnr_atomic_load(target, .acquire) else { return false }
    handler()
    bnr_atomic_store(target, true, .release)
    return true
}
