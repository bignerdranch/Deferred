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

#if !defined(OS_INLINE)
#if __GNUC__
#define OS_INLINE static __inline__
#else
#define OS_INLINE
#endif // !__GNUC__
#endif // !OS_INLINE

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
    bnr_atomic_memory_order_relaxed OS_SWIFT_NAME(relaxed) = __ATOMIC_RELAXED,
    bnr_atomic_memory_order_consume OS_SWIFT_NAME(consume) = __ATOMIC_CONSUME,
    bnr_atomic_memory_order_acquire OS_SWIFT_NAME(acquire) = __ATOMIC_ACQUIRE,
    bnr_atomic_memory_order_release OS_SWIFT_NAME(release) = __ATOMIC_RELEASE,
    bnr_atomic_memory_order_acq_rel OS_SWIFT_NAME(acquireRelease) = __ATOMIC_ACQ_REL,
    bnr_atomic_memory_order_seq_cst OS_SWIFT_NAME(sequentiallyConsistent) = __ATOMIC_SEQ_CST
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

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeNativeLock.setup(self:))
void bnr_native_lock_create(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        address->__impl.modern = OS_UNFAIR_LOCK_INIT;
        return;
    }
#endif

    pthread_mutex_init(&address->__impl.legacy, NULL);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeNativeLock.invalidate(self:))
void bnr_native_lock_destroy(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        return;
    }
#endif

    pthread_mutex_destroy(&address->__impl.legacy);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeNativeLock.lock(self:))
void bnr_native_lock_lock(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_lock != NULL) {
        return os_unfair_lock_lock(&address->__impl.modern);
    }
#endif

    pthread_mutex_lock(&address->__impl.legacy);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeNativeLock.tryLock(self:))
bool bnr_native_lock_trylock(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_trylock != NULL) {
        return os_unfair_lock_trylock(&address->__impl.modern);
    }
#endif

    return pthread_mutex_trylock(&address->__impl.legacy) == 0;
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeNativeLock.unlock(self:))
void bnr_native_lock_unlock(bnr_spinlock_t *_Nonnull address) {
#if defined(__APPLE__)
    if (&os_unfair_lock_unlock != NULL) {
        return os_unfair_lock_unlock(&address->__impl.modern);
    }
#endif

    pthread_mutex_unlock(&address->__impl.legacy);
}

OS_SWIFT_NAME(UnsafeAtomicInt32)
typedef struct {
    _Atomic(int32_t) value;
} bnr_atomic_int32_t;

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicInt32.load(self:order:))
int32_t bnr_atomic_int32_load(volatile bnr_atomic_int32_t *_Nonnull target, bnr_atomic_memory_order_t order) {
    return __c11_atomic_load(&target->value, order);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicInt32.store(self:_:order:))
void bnr_atomic_int32_store(volatile bnr_atomic_int32_t *_Nonnull target, int32_t desired, bnr_atomic_memory_order_t order) {
    __c11_atomic_store(&target->value, desired, order);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicInt32.compareAndSwap(self:from:to:success:failure:))
bool bnr_atomic_int32_compare_and_swap(volatile bnr_atomic_int32_t *_Nonnull target, int32_t expected, int32_t desired, bnr_atomic_memory_order_t success, bnr_atomic_memory_order_t failure) {
    return __c11_atomic_compare_exchange_strong(&target->value, &expected, desired, success, failure);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicInt32.add(self:_:order:))
int32_t bnr_atomic_int32_add(volatile bnr_atomic_int32_t *_Nonnull target, int32_t amount, bnr_atomic_memory_order_t order) {
    return __c11_atomic_fetch_add(&target->value, amount, order) + amount;
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicInt32.subtract(self:_:order:))
int32_t bnr_atomic_int32_subtract(volatile bnr_atomic_int32_t *_Nonnull target, int32_t amount, bnr_atomic_memory_order_t order) {
    return __c11_atomic_fetch_sub(&target->value, amount, order) - amount;
}

OS_SWIFT_NAME(UnsafeAtomicRawPointer)
typedef struct {
    _Atomic(void *_Nullable) value;
} bnr_atomic_ptr_t;

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicRawPointer.load(self:order:))
void *_Nullable bnr_atomic_ptr_load(volatile bnr_atomic_ptr_t *_Nonnull target, bnr_atomic_memory_order_t order) {
    return __c11_atomic_load(&target->value, order);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicRawPointer.compareAndSwap(self:from:to:order:))
bool bnr_atomic_ptr_compare_and_swap(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable expected, void *_Nullable desired, bnr_atomic_memory_order_t order) {
    return __c11_atomic_compare_exchange_strong(&target->value, &expected, desired, order, __ATOMIC_RELAXED);
}

OS_SWIFT_NAME(UnsafeAtomicBool)
typedef struct {
    _Atomic(bool) value;
} bnr_atomic_flag_t;

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicBool.testAndSet(self:))
bool bnr_atomic_flag_test_and_set(volatile bnr_atomic_flag_t *_Nonnull target) {
    return __c11_atomic_exchange(&target->value, 1, __ATOMIC_RELAXED);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicBool.test(self:))
bool bnr_atomic_flag_test(volatile bnr_atomic_flag_t *_Nonnull target) {
    return __c11_atomic_load(&target->value, __ATOMIC_RELAXED);
}

OS_ASSUME_NONNULL_END

#endif // __BNR_DEFERRED_ATOMIC_SHIMS__
