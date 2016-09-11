//
//  Atomics.h
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#ifndef __BNR_DEFERRED_ATOMIC_SHIMS__
#define __BNR_DEFERRED_ATOMIC_SHIMS__

#include <os/lock.h>
#include <stdlib.h>

// We should be using OS_ENUM, but Swift looks for particular macro patterns.
#if !defined(SWIFT_ENUM)
#if __has_feature(objc_fixed_enum)
#if !defined(SWIFT_ENUM_EXTRA)
#define SWIFT_ENUM_EXTRA
#endif
#define SWIFT_ENUM(_name, _type, ...) enum _name : _type _name; enum SWIFT_ENUM_EXTRA _name : _type
#else
#define SWIFT_ENUM(_name, _type, ...) _type _name; enum
#endif
#endif

OS_ASSUME_NONNULL_BEGIN

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicInt32.spin())
void bnr_atomic_spin(void) {
#if defined(__x86_64__) || defined(__i386__)
    __asm__ __volatile__("pause" ::: "memory");
#elif defined(__arm__) || defined(__arm64__)
    __asm__ __volatile__("yield" ::: "memory");
#else
    do {} while (0);
#endif
}

OS_SWIFT_NAME(AtomicMemoryOrder)
typedef SWIFT_ENUM(bnr_atomic_memory_order_t, int32_t) {
    bnr_atomic_memory_order_relaxed = __ATOMIC_RELAXED,
    bnr_atomic_memory_order_consume = __ATOMIC_CONSUME,
    bnr_atomic_memory_order_acquire = __ATOMIC_ACQUIRE,
    bnr_atomic_memory_order_release = __ATOMIC_RELEASE,
    bnr_atomic_memory_order_acq_rel OS_SWIFT_NAME(acquireRelease) = __ATOMIC_ACQ_REL,
    bnr_atomic_memory_order_seq_cst OS_SWIFT_NAME(sequentiallyConsistent) = __ATOMIC_SEQ_CST
};

OS_SWIFT_NAME(UnsafeSpinLock)
typedef struct {
    union {
        _Atomic(_Bool) legacy;
        os_unfair_lock modern;
    } impl;
} bnr_spinlock_t;

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeSpinLock.tryLock(self:))
bool bnr_spinlock_trylock(bnr_spinlock_t *_Nonnull address) {
    if (os_unfair_lock_trylock != NULL) {
        return os_unfair_lock_trylock(&address->impl.modern);
    } else {
        return !__c11_atomic_exchange(&address->impl.legacy, 1, __ATOMIC_ACQUIRE);
    }
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeSpinLock.lock(self:))
void bnr_spinlock_lock(bnr_spinlock_t *_Nonnull address) {
    if (os_unfair_lock_lock != NULL) {
        return os_unfair_lock_lock(&address->impl.modern);
    } else {
        while (!OS_EXPECT(bnr_spinlock_trylock(address), true)) {
            bnr_atomic_spin();
        }
    }
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeSpinLock.unlock(self:))
void bnr_spinlock_unlock(bnr_spinlock_t *_Nonnull address) {
    if (os_unfair_lock_unlock != NULL) {
        return os_unfair_lock_unlock(&address->impl.modern);
    } else {
        __c11_atomic_store(&address->impl.legacy, 0, __ATOMIC_RELEASE);
    }
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

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicInt32.exchange(self:with:order:))
int32_t bnr_atomic_int32_exchange(volatile bnr_atomic_int32_t *_Nonnull target, int32_t desired, bnr_atomic_memory_order_t order) {
    return __c11_atomic_exchange(&target->value, desired, order);
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

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicRawPointer.store(self:_:order:))
void bnr_atomic_ptr_store(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable desired, bnr_atomic_memory_order_t order) {
    __c11_atomic_store(&target->value, desired, order);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicRawPointer.exchange(self:with:order:))
void *_Nullable bnr_atomic_ptr_exchange(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable desired, bnr_atomic_memory_order_t order) {
    return __c11_atomic_exchange(&target->value, desired, order);
}

OS_INLINE OS_ALWAYS_INLINE OS_SWIFT_NAME(UnsafeAtomicRawPointer.compareAndSwap(self:from:to:success:failure:))
bool bnr_atomic_ptr_compare_and_swap(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable expected, void *_Nullable desired, bnr_atomic_memory_order_t success, bnr_atomic_memory_order_t failure) {
    return __c11_atomic_compare_exchange_strong(&target->value, &expected, desired, success, failure);
}

OS_ASSUME_NONNULL_END

#endif // __BNR_DEFERRED_ATOMIC_SHIMS__
