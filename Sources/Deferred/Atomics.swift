//
//  Atomics.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/22/18.
//  Copyright © 2018 Big Nerd Ranch. All rights reserved.
//

// swiftlint:disable type_name
// swiftlint:disable identifier_name

// This #if is over-complex because there is no compilation condition associated
// with Playgrounds. <rdar://38865726>
#if SWIFT_PACKAGE
import Atomics
#elseif (XCODE && !FORCE_PLAYGROUND_COMPATIBILITY) || COCOAPODS
import Deferred.Atomics
#else
import Darwin.C.stdatomic
import Darwin.POSIX.pthread

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
        assert("\(T.self)".contains("@convention(c)"), "Type must be a C symbol", file: file, line: line)
        guard let symbol = dlsym(self, name) else { preconditionFailure(String(cString: dlerror()), file: file, line: line) }
        return unsafeBitCast(symbol, to: T.self)
    }
}

private struct DarwinAtomics {
    let load: @convention(c) (CInt, UnsafeMutableRawPointer, UnsafeMutableRawPointer, bnr_atomic_memory_order_t) -> Void
    let exchange: @convention(c) (CInt, UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer, bnr_atomic_memory_order_t) -> Void
    let compareExchange: @convention(c) (CInt, UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer, bnr_atomic_memory_order_t, bnr_atomic_memory_order_t) -> CInt
    let or8: @convention(c) (UnsafeMutablePointer<UInt8>, UInt8, bnr_atomic_memory_order_t) -> UInt8
    let and8: @convention(c) (UnsafeMutablePointer<UInt8>, UInt8, bnr_atomic_memory_order_t) -> UInt8

    static let shared: DarwinAtomics = {
        let library = UnsafeMutableRawPointer(bitPattern: -2)
        return DarwinAtomics(
            load: library.symbol(named: "__atomic_load"),
            exchange: library.symbol(named: "__atomic_exchange"),
            compareExchange: library.symbol(named: "__atomic_compare_exchange"),
            or8: library.symbol(named: "__atomic_fetch_or_1"),
            and8: library.symbol(named: "__atomic_fetch_and_1"))
    }()
}

typealias bnr_atomic_ptr = UnsafeRawPointer?
typealias bnr_atomic_ptr_t = UnsafeMutablePointer<bnr_atomic_ptr>

func bnr_atomic_ptr_load(_ target: bnr_atomic_ptr_t, _ order: bnr_atomic_memory_order_t) -> UnsafeRawPointer? {
    var result: UnsafeRawPointer?
    DarwinAtomics.shared.load(CInt(MemoryLayout<UnsafeRawPointer>.size), target, &result, order)
    return result
}

func bnr_atomic_ptr_exchange(_ target: bnr_atomic_ptr_t, _ desired: UnsafeRawPointer?, _ order: bnr_atomic_memory_order_t) -> UnsafeRawPointer? {
    var new = desired
    var old: UnsafeRawPointer?
    DarwinAtomics.shared.exchange(CInt(MemoryLayout<UnsafeRawPointer>.size), target, &new, &old, order)
    return old
}

func bnr_atomic_ptr_compare_and_swap(_ target: bnr_atomic_ptr_t, _ expected: UnsafeRawPointer?, _ desired: UnsafeRawPointer?, _ order: bnr_atomic_memory_order_t) -> Bool {
    var expected = expected
    var desired = desired
    return DarwinAtomics.shared.compareExchange(CInt(MemoryLayout<UnsafeRawPointer>.size), target, &expected, &desired, order, .relaxed) == 1
}

typealias bnr_atomic_flag = Bool
typealias bnr_atomic_flag_t = UnsafeMutablePointer<bnr_atomic_flag>

func bnr_atomic_flag_load(_ target: bnr_atomic_flag_t, _ order: bnr_atomic_memory_order_t) -> Bool {
    var result: Bool = false
    DarwinAtomics.shared.load(CInt(MemoryLayout<Bool>.size), target, &result, order)
    return result
}

func bnr_atomic_flag_test_and_set(_ target: bnr_atomic_flag_t, _ order: bnr_atomic_memory_order_t) -> Bool {
    var new = true
    var old = false
    DarwinAtomics.shared.exchange(CInt(MemoryLayout<Bool>.size), target, &new, &old, order)
    return old
}

typealias bnr_atomic_bitmask = UInt8
typealias bnr_atomic_bitmask_t = UnsafeMutablePointer<bnr_atomic_bitmask>

func bnr_atomic_bitmask_init(_ target: bnr_atomic_bitmask_t, _ mask: UInt8) {
    target.pointee = mask
}

func bnr_atomic_bitmask_add(_ target: bnr_atomic_bitmask_t, _ mask: UInt8, _ order: bnr_atomic_memory_order_t) -> UInt8 {
    return DarwinAtomics.shared.or8(target, mask, order)
}

func bnr_atomic_bitmask_remove(_ target: bnr_atomic_bitmask_t, _ mask: UInt8, _ order: bnr_atomic_memory_order_t) -> UInt8 {
    return DarwinAtomics.shared.and8(target, ~mask, order)
}

func bnr_atomic_bitmask_test(_ target: bnr_atomic_bitmask_t, _ mask: UInt8, _ order: bnr_atomic_memory_order_t) -> Bool {
    var result: UInt8 = 0
    DarwinAtomics.shared.load(CInt(MemoryLayout<UInt8>.size), target, &result, order)
    return (result & mask) != 0
}
#endif

func bnr_atomic_load<T: AnyObject>(_ target: UnsafeMutablePointer<T?>) -> T? {
    let atomicTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: bnr_atomic_ptr.self)
    guard let opaqueResult = bnr_atomic_ptr_load(atomicTarget, .seq_cst) else { return nil }
    return Unmanaged<T>.fromOpaque(opaqueResult).takeUnretainedValue()
}

func bnr_atomic_load_relaxed<T: AnyObject>(_ target: UnsafeMutablePointer<T?>) -> T? {
    let atomicTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: bnr_atomic_ptr.self)
    guard let opaqueResult = bnr_atomic_ptr_load(atomicTarget, .relaxed) else { return nil }
    return Unmanaged<T>.fromOpaque(opaqueResult).takeUnretainedValue()
}

func bnr_atomic_initialize_once<T: AnyObject>(_ target: UnsafeMutablePointer<T?>, _ desired: T) -> Bool {
    let atomicTarget = UnsafeMutableRawPointer(target).assumingMemoryBound(to: bnr_atomic_ptr.self)
    let retainedDesired = Unmanaged.passRetained(desired)
    return bnr_atomic_ptr_compare_and_swap(atomicTarget, nil, retainedDesired.toOpaque(), .acq_rel)
}
