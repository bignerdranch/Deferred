//
//  CAtomics.h
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//
//  Each of the types defined in this file have specific usage requirements, the
//  precise semantics of which are defined in the C11 standard. In Swift, they
//  are tricky to use correctly because of writeback semantics.
//
//  It is best to use the below methods directly on C pointers
//  (`UnsafeMutablePointer<UnsafeMutablePointer<T>>`) that are known to
//  point directly to the memory where the value is stored.
//
//  The shared memory that you are accessing much be located inside a heap
//  allocation, such as a Swift class instance property, a `ManagedBuffer`,
//  a pointer to an `Array` element, etc.]
//
//  If the above conditions are not met, the code may still compile, but still
//  cause races due to Swift writeback or other undefined behavior.

#ifndef __BNR_DEFERRED_ATOMIC_SHIMS__
#define __BNR_DEFERRED_ATOMIC_SHIMS__

#if !__has_include(<stdatomic.h>)
#error An implementation of threading primitives is not available on this platform. Please open an issue with the Deferred project.
#endif

#include <stdbool.h>
#include <stdatomic.h>

#define BNR_ATOMIC_INLINE static inline __attribute__((always_inline))
#define BNR_ATOMIC_OVERLOAD __attribute__((overloadable))
#define BNR_ATOMIC_WARN_UNUSED_RESULT __attribute__((warn_unused_result))

#if !defined(SWIFT_ENUM)
#define SWIFT_ENUM(_type, _name) enum _name _name##_t; enum _name
#endif

// Swift looks for enums declared using a particular macro named SWIFT_ENUM
#define BNR_ATOMIC_ENUM(_type, _name) SWIFT_ENUM(_type, _name)

typedef BNR_ATOMIC_ENUM(int, bnr_atomic_memory_order) {
    bnr_atomic_memory_order_relaxed = memory_order_relaxed,
    bnr_atomic_memory_order_acquire = memory_order_acquire,
    bnr_atomic_memory_order_release = memory_order_release,
    bnr_atomic_memory_order_acq_rel = memory_order_acq_rel,
    bnr_atomic_memory_order_seq_cst = memory_order_seq_cst
};

typedef const void *_Nullable volatile *_Nonnull bnr_atomic_ptr_t;

BNR_ATOMIC_INLINE BNR_ATOMIC_WARN_UNUSED_RESULT BNR_ATOMIC_OVERLOAD
const void *_Nullable bnr_atomic_load(bnr_atomic_ptr_t target, bnr_atomic_memory_order_t order) {
    return atomic_load_explicit((const void *_Atomic *)target, order);
}

BNR_ATOMIC_INLINE BNR_ATOMIC_WARN_UNUSED_RESULT
const void *_Nullable bnr_atomic_exchange(bnr_atomic_ptr_t target, const void *_Nullable desired, bnr_atomic_memory_order_t order) {
    return atomic_exchange_explicit((const void *_Atomic *)target, desired, order);
}

BNR_ATOMIC_INLINE BNR_ATOMIC_WARN_UNUSED_RESULT
bool bnr_atomic_compare_and_swap(bnr_atomic_ptr_t target, const void *_Nullable expected, const void *_Nullable desired, bnr_atomic_memory_order_t order, bnr_atomic_memory_order_t failureOrder) {
    return atomic_compare_exchange_strong_explicit((const void *_Atomic *)target, &expected, desired, order, failureOrder);
}

typedef volatile bool *_Nonnull bnr_atomic_flag_t;

BNR_ATOMIC_INLINE BNR_ATOMIC_WARN_UNUSED_RESULT BNR_ATOMIC_OVERLOAD
bool bnr_atomic_load(bnr_atomic_flag_t target, bnr_atomic_memory_order_t order) {
    return atomic_load_explicit((atomic_bool *)target, order);
}

BNR_ATOMIC_INLINE BNR_ATOMIC_OVERLOAD
void bnr_atomic_store(bnr_atomic_flag_t target, bool desired, bnr_atomic_memory_order_t order) {
    atomic_store_explicit((atomic_bool *)target, desired, order);
}

#undef SWIFT_ENUM

#endif // __BNR_DEFERRED_ATOMIC_SHIMS__
