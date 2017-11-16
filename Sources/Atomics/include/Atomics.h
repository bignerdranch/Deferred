//
//  Atomics.h
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#ifndef __BNR_DEFERRED_ATOMIC_SHIMS__
#define __BNR_DEFERRED_ATOMIC_SHIMS__

#if defined(__APPLE__)
#include <os/lock.h>
#else
#include <stdint.h>
#include <stdbool.h>
#include <os/linux_base.h>
#endif // !__APPLE__
#include <pthread.h>

#if !defined(OS_ALWAYS_INLINE)
#if __GNUC__
#define OS_ALWAYS_INLINE __attribute__((__always_inline__))
#else
#define OS_ALWAYS_INLINE
#endif // !__GNUC__
#endif // !OS_ALWAYS_INLINE

// We should be using OS_ENUM, but Swift looks for particular macro patterns.
#if !defined(SWIFT_ENUM)
#define SWIFT_ENUM(_name, ...) enum { __VA_ARGS__ } _name##_t
#endif

OS_ASSUME_NONNULL_BEGIN

OS_SWIFT_NAME(AtomicMemoryOrder)
typedef SWIFT_ENUM(bnr_atomic_memory_order,
    bnr_atomic_memory_order_relaxed OS_SWIFT_NAME(none) = __ATOMIC_RELAXED,
    bnr_atomic_memory_order_acquire OS_SWIFT_NAME(read) = __ATOMIC_ACQUIRE,
    bnr_atomic_memory_order_release OS_SWIFT_NAME(write) = __ATOMIC_RELEASE,
    bnr_atomic_memory_order_acq_rel OS_SWIFT_NAME(thread) = __ATOMIC_ACQ_REL,
    bnr_atomic_memory_order_seq_cst OS_SWIFT_NAME(global) = __ATOMIC_SEQ_CST
);

OS_SWIFT_NAME(UnsafeNativeLock)
typedef struct {
    union {
        pthread_mutex_t legacy;
#if defined(__APPLE__)
        os_unfair_lock modern;
#endif
    } __impl;
} bnr_spinlock_t;

OS_ALWAYS_INLINE
static inline void bnr_native_lock_init(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        address->__impl.modern = OS_UNFAIR_LOCK_INIT;
        return;
    }
#endif

    pthread_mutex_init(&address->__impl.legacy, NULL);
}

OS_ALWAYS_INLINE
static inline void bnr_native_lock_destroy(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        return;
    }
#endif

    pthread_mutex_destroy(&address->__impl.legacy);
}

OS_ALWAYS_INLINE
static inline void bnr_native_lock_lock(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_lock != NULL) {
        return os_unfair_lock_lock(&address->__impl.modern);
    }
#endif

    pthread_mutex_lock(&address->__impl.legacy);
}

OS_ALWAYS_INLINE
static inline bool bnr_native_lock_trylock(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        return os_unfair_lock_trylock(&address->__impl.modern);
    }
#endif

    return pthread_mutex_trylock(&address->__impl.legacy) == 0;
}

OS_ALWAYS_INLINE
static inline void bnr_native_lock_unlock(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_unlock != NULL) {
        return os_unfair_lock_unlock(&address->__impl.modern);
    }
#endif

    pthread_mutex_unlock(&address->__impl.legacy);
}

OS_SWIFT_NAME(UnsafeAtomicRawPointer)
typedef struct {
    _Atomic(void *_Nullable) value;
} bnr_atomic_ptr_t;

OS_ALWAYS_INLINE
static inline void *_Nullable bnr_atomic_ptr_load(volatile bnr_atomic_ptr_t *_Nonnull target, bnr_atomic_memory_order_t order) {
    return __c11_atomic_load(&target->value, order);
}

OS_ALWAYS_INLINE
static inline bool bnr_atomic_ptr_compare_and_swap(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable expected, void *_Nullable desired, bnr_atomic_memory_order_t order) {
    return __c11_atomic_compare_exchange_strong(&target->value, &expected, desired, order, __ATOMIC_RELAXED);
}

OS_SWIFT_NAME(UnsafeAtomicBool)
typedef struct {
    _Atomic(bool) value;
} bnr_atomic_flag_t;

OS_ALWAYS_INLINE
static inline bool bnr_atomic_flag_test_and_set(volatile bnr_atomic_flag_t *_Nonnull target) {
    return __c11_atomic_exchange(&target->value, 1, __ATOMIC_RELAXED);
}

OS_ALWAYS_INLINE
static inline bool bnr_atomic_flag_test(volatile bnr_atomic_flag_t *_Nonnull target) {
    return __c11_atomic_load(&target->value, __ATOMIC_RELAXED);
}

OS_SWIFT_NAME(UnsafeAtomicBitmask)
typedef struct {
    _Atomic(uint_fast8_t) value;
} bnr_atomic_bitmask_t;

OS_ALWAYS_INLINE
static inline void bnr_atomic_bitmask_init(volatile bnr_atomic_bitmask_t *_Nonnull target, uint_fast8_t value) {
    __c11_atomic_init(&target->value, value);
}

OS_ALWAYS_INLINE
static inline uint_fast8_t bnr_atomic_bitmask_or(volatile bnr_atomic_bitmask_t *_Nonnull target, uint_fast8_t value, bnr_atomic_memory_order_t order) {
    return __c11_atomic_fetch_or(&target->value, value, order);
}

OS_ALWAYS_INLINE
static inline uint_fast8_t bnr_atomic_bitmask_and(volatile bnr_atomic_bitmask_t *_Nonnull target, uint_fast8_t value, bnr_atomic_memory_order_t order) {
    return __c11_atomic_fetch_and(&target->value, value, order);
}

OS_ALWAYS_INLINE
static inline bool bnr_atomic_bitmask_test(volatile bnr_atomic_bitmask_t *_Nonnull target, uint_fast8_t value) {
    return (__c11_atomic_load((_Atomic(uint_fast8_t) *)&target->value, __ATOMIC_RELAXED) & value) != 0;
}

OS_SWIFT_NAME(UnsafeAtomicCounter)
typedef struct {
    _Atomic(int_fast32_t) value;
} bnr_atomic_counter_t;

OS_ALWAYS_INLINE
static inline int_fast32_t bnr_atomic_counter_increment(volatile bnr_atomic_counter_t *_Nonnull target) {
    return __c11_atomic_fetch_add(&target->value, 1, __ATOMIC_SEQ_CST) + 1;
}

OS_ALWAYS_INLINE
static inline int_fast32_t bnr_atomic_counter_decrement(volatile bnr_atomic_counter_t *_Nonnull target) {
    return __c11_atomic_fetch_sub(&target->value, 1, __ATOMIC_SEQ_CST) - 1;
}

OS_ALWAYS_INLINE
static inline int_fast32_t bnr_atomic_counter_load(volatile bnr_atomic_counter_t *_Nonnull target) {
    return __c11_atomic_load(&target->value, __ATOMIC_SEQ_CST);
}

OS_ASSUME_NONNULL_END

#endif // __BNR_DEFERRED_ATOMIC_SHIMS__
