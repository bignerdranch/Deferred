//
//  Atomics.h
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//
//  Each of the types defined in this file have specific usage requirements, the
//  precise semantics of which are defined in the POSIX (for the lock) and C11
//  (for the atomics) standards. In Swift, they are tricky to use correctly
//  because of writeback semantics.
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

#include <stdatomic.h>
#if defined(__APPLE__)
#include <os/lock.h>
#endif
#include <pthread.h>
#include <dispatch/dispatch.h>

#if defined(__has_attribute) && __has_attribute(always_inline)
#define BNR_ATOMIC_INLINE static inline __attribute__((always_inline))
#else
#define BNR_ATOMIC_INLINE static inline
#endif

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

typedef struct bnr_native_lock_s {
    union {
        pthread_mutex_t legacy;
#if defined(__APPLE__)
        os_unfair_lock modern;
#endif
    } impl;
} bnr_native_lock, *_Nonnull bnr_native_lock_t;

BNR_ATOMIC_INLINE
void bnr_native_lock_init(bnr_native_lock_t address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        address->impl.modern = OS_UNFAIR_LOCK_INIT;
        return;
    }
#endif

    pthread_mutex_init(&address->impl.legacy, NULL);
}

BNR_ATOMIC_INLINE
void bnr_native_lock_deinit(bnr_native_lock_t address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        return;
    }
#endif

    pthread_mutex_destroy(&address->impl.legacy);
}

BNR_ATOMIC_INLINE
void bnr_native_lock_lock(bnr_native_lock_t address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_lock != NULL) {
        return os_unfair_lock_lock(&address->impl.modern);
    }
#endif

    pthread_mutex_lock(&address->impl.legacy);
}

BNR_ATOMIC_INLINE
bool bnr_native_lock_trylock(bnr_native_lock_t address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        return os_unfair_lock_trylock(&address->impl.modern);
    }
#endif

    return pthread_mutex_trylock(&address->impl.legacy) == 0;
}

BNR_ATOMIC_INLINE void bnr_native_lock_unlock(bnr_native_lock_t address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_unlock != NULL) {
        return os_unfair_lock_unlock(&address->impl.modern);
    }
#endif

    pthread_mutex_unlock(&address->impl.legacy);
}

typedef volatile struct bnr_atomic_ptr_s {
    _Atomic(const void *_Nullable) value;
} bnr_atomic_ptr, *_Nonnull bnr_atomic_ptr_t;

BNR_ATOMIC_INLINE
const void *_Nullable bnr_atomic_ptr_load(bnr_atomic_ptr_t target, bnr_atomic_memory_order_t order) {
    return atomic_load_explicit(&target->value, order);
}

BNR_ATOMIC_INLINE
const void *_Nullable bnr_atomic_ptr_exchange(bnr_atomic_ptr_t target, const void *_Nullable desired, bnr_atomic_memory_order_t order) {
    return atomic_exchange_explicit(&target->value, desired, order);
}

BNR_ATOMIC_INLINE
bool bnr_atomic_ptr_compare_and_swap(bnr_atomic_ptr_t target, const void *_Nullable expected, const void *_Nullable desired, bnr_atomic_memory_order_t order) {
    return atomic_compare_exchange_strong_explicit(&target->value, &expected, desired, order, memory_order_relaxed);
}

typedef volatile struct bnr_atomic_flag_s {
    _Atomic(_Bool) value;
} bnr_atomic_flag, *_Nonnull bnr_atomic_flag_t;

BNR_ATOMIC_INLINE
bool bnr_atomic_flag_load(bnr_atomic_flag_t target, bnr_atomic_memory_order_t order) {
    return atomic_load_explicit(&target->value, order);
}

BNR_ATOMIC_INLINE
bool bnr_atomic_flag_test_and_set(bnr_atomic_flag_t target, bnr_atomic_memory_order_t order) {
    return atomic_exchange_explicit(&target->value, true, order);
}

typedef volatile struct bnr_atomic_bitmask_s {
    _Atomic(uint8_t) value;
} bnr_atomic_bitmask, *_Nonnull bnr_atomic_bitmask_t;

BNR_ATOMIC_INLINE
void bnr_atomic_bitmask_init(bnr_atomic_bitmask_t target, uint8_t mask) {
    atomic_init(&target->value, mask);
}

BNR_ATOMIC_INLINE
uint8_t bnr_atomic_bitmask_add(bnr_atomic_bitmask_t target, uint8_t mask, bnr_atomic_memory_order_t order) {
    return atomic_fetch_or_explicit(&target->value, mask, order);
}

BNR_ATOMIC_INLINE
uint8_t bnr_atomic_bitmask_remove(bnr_atomic_bitmask_t target, uint8_t mask, bnr_atomic_memory_order_t order) {
    return atomic_fetch_and_explicit(&target->value, ~mask, order);
}

BNR_ATOMIC_INLINE
bool bnr_atomic_bitmask_test(bnr_atomic_bitmask_t target, uint8_t mask, bnr_atomic_memory_order_t order) {
    return (atomic_load_explicit(&target->value, order) & mask) != 0;
}

typedef volatile struct bnr_atomic_counter_s {
    _Atomic(long) value;
} bnr_atomic_counter, *_Nonnull bnr_atomic_counter_t;

BNR_ATOMIC_INLINE
long bnr_atomic_counter_load(bnr_atomic_counter_t target) {
    return atomic_load(&target->value);
}

BNR_ATOMIC_INLINE
long bnr_atomic_counter_increment(bnr_atomic_counter_t target) {
    return atomic_fetch_add(&target->value, 1) + 1;
}

BNR_ATOMIC_INLINE
long bnr_atomic_counter_decrement(bnr_atomic_counter_t target) {
    return atomic_fetch_sub(&target->value, 1) - 1;
}

#undef SWIFT_ENUM

#endif // __BNR_DEFERRED_ATOMIC_SHIMS__
