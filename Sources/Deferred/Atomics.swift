//
//  Atomics.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/22/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

// swiftlint:disable type_name
// swiftlint:disable identifier_name

// This #if is over-complex because there is no compilation condition associated
// with Playgrounds. <rdar://38865726>
#if SWIFT_PACKAGE || COCOAPODS
import Atomics
#elseif XCODE && !FORCE_PLAYGROUND_COMPATIBILITY
import Deferred.Atomics
#else
import Darwin.C.stdatomic

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
    let or8: @convention(c) (UnsafeMutablePointer<UInt8>, UInt8, bnr_atomic_memory_order_t) -> UInt8
    let and8: @convention(c) (UnsafeMutablePointer<UInt8>, UInt8, bnr_atomic_memory_order_t) -> UInt8

    static let shared: DarwinAtomics = {
        let library = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        return DarwinAtomics(
            load: library.symbol(named: "__atomic_load"),
            store: library.symbol(named: "__atomic_store"),
            exchange: library.symbol(named: "__atomic_exchange"),
            compareExchange: library.symbol(named: "__atomic_compare_exchange"),
            or8: library.symbol(named: "__atomic_fetch_or_1"),
            and8: library.symbol(named: "__atomic_fetch_and_1"))
    }()
}

typealias bnr_atomic_ptr_t = UnsafeMutablePointer<UnsafeRawPointer?>

func bnr_atomic_init(_ target: bnr_atomic_ptr_t, _ initial: UnsafeRawPointer?) {
    target.pointee = initial
}

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

func bnr_atomic_compare_and_swap(_ target: bnr_atomic_ptr_t, _ expected: UnsafeRawPointer?, _ desired: UnsafeRawPointer?, _ order: bnr_atomic_memory_order_t) -> Bool {
    var expected = expected
    var desired = desired
    return DarwinAtomics.shared.compareExchange(MemoryLayout<UnsafeRawPointer?>.size, target, &expected, &desired, order, .relaxed)
}

func bnr_atomic_load_and_wait(_ target: bnr_atomic_ptr_t) -> UnsafeRawPointer {
    repeat {
        guard let result = bnr_atomic_load(target, .acquire) else {
            pthread_yield_np()
            continue
        }
        return result
    } while true
}

typealias bnr_atomic_flag_t = UnsafeMutablePointer<Bool>

func bnr_atomic_init(_ target: bnr_atomic_flag_t, _ initial: Bool) {
    target.pointee = initial
}

func bnr_atomic_load(_ target: bnr_atomic_flag_t, _ order: bnr_atomic_memory_order_t) -> Bool {
    var result: Bool = false
    DarwinAtomics.shared.load(MemoryLayout<Bool>.size, target, &result, order)
    return result
}

func bnr_atomic_store(_ target: bnr_atomic_flag_t, _ desired: Bool, _ order: bnr_atomic_memory_order_t) {
    var desired = desired
    DarwinAtomics.shared.store(MemoryLayout<Bool>.size, target, &desired, order)
}

func bnr_atomic_init(_ target: bnr_atomic_bitmask_t, _ mask: UInt8) {
    target.pointee = mask
}

typealias bnr_atomic_bitmask_t = UnsafeMutablePointer<UInt8>

func bnr_atomic_load(_ target: bnr_atomic_bitmask_t, _ order: bnr_atomic_memory_order_t) -> UInt8 {
    var result: UInt8 = 0
    DarwinAtomics.shared.load(MemoryLayout<UInt8>.size, target, &result, order)
    return result
}

@discardableResult
func bnr_atomic_fetch_or(_ target: bnr_atomic_bitmask_t, _ mask: UInt8, _ order: bnr_atomic_memory_order_t) -> UInt8 {
    return DarwinAtomics.shared.or8(target, mask, order)
}

@discardableResult
func bnr_atomic_fetch_and(_ target: bnr_atomic_bitmask_t, _ mask: UInt8, _ order: bnr_atomic_memory_order_t) -> UInt8 {
    return DarwinAtomics.shared.and8(target, mask, order)
}
#endif

func bnr_atomic_init<T: AnyObject>(_ target: UnsafeMutablePointer<T?>) {
    let rawTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: UnsafeRawPointer?.self)
    bnr_atomic_init(rawTarget, nil)
}

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
    let wonRace = bnr_atomic_compare_and_swap(rawTarget, nil, retainedDesired.toOpaque(), .acq_rel)
    if !wonRace {
        retainedDesired.release()
    }
    return wonRace
}

func bnr_atomic_load_and_wait<T: AnyObject>(_ target: UnsafeMutablePointer<T?>) -> T {
    let rawTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: UnsafeRawPointer?.self)
    let opaqueResult = bnr_atomic_load_and_wait(rawTarget)
    return Unmanaged<T>.fromOpaque(opaqueResult).takeUnretainedValue()
}

@discardableResult
func bnr_atomic_initialize_once(_ target: UnsafeMutablePointer<Bool>, _ handler: () -> Void) -> Bool {
    guard !bnr_atomic_load(target, .acquire) else { return false }
    handler()
    bnr_atomic_store(target, true, .release)
    return true
}
