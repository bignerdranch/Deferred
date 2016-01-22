//
//  Deferred.h
//  Deferred
//
//  Created by John Gallagher on 8/11/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

//! Project version number for Deferred.
extern double DeferredVersionNumber;

//! Project version string for Deferred.
extern const unsigned char DeferredVersionString[];

// https://github.com/bignerdranch/AtomicSwift/blob/master/AtomicSwift.h
static inline void __attribute__((always_inline, used)) _OSAtomicSpin(void) {
#if defined(__x86_64__) || defined(__i386__)
    __asm__ __volatile__("pause" ::: "memory");
#elif defined(__arm__) || defined(__arm64__)
    __asm__ __volatile__("yield" ::: "memory");
#else
    do {} while (0);
#endif
}
