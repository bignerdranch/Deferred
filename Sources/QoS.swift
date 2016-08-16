//
//  QoS.swift
//  Deferred
//
//  Created by Zachary Waldowski on 6/16/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Dispatch

extension DispatchQoS.QoSClass {

    /// A QoS class for for when you just want to throw some work into the
    /// concurrent pile, matching the QoS of the caller.
    static var current: DispatchQoS.QoSClass {
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            // The technique is described and used in Core Foundation:
            // http://opensource.apple.com/source/CF/CF-1153.18/CFInternal.h
            // https://github.com/apple/swift-corelibs-foundation/blob/master/CoreFoundation/Base.subproj/CFInternal.h#L869-L889
            return DispatchQoS.QoSClass(rawValue: qos_class_self()) ?? .utility
        #else
            return .utility
        #endif
    }

}
