//
//  FutureComposition.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

// swiftlint:disable force_cast
// swiftlint:disable function_parameter_count
// swiftlint:disable line_length
// We darn well know what unholiness we are pulling

extension FutureProtocol {
    private func toAny() -> Future<Any> {
        return every { $0 }
    }

    /// Returns a value that becomes determined after both the callee and the
    /// given future become determined.
    ///
    /// - see: SequenceType.allFilled()
    public func and<Other1: FutureProtocol>(_ one: Other1) -> Future<(Value, Other1.Value)> {
        return [ toAny(), one.toAny() ].allFilled().every { (array) in
            let zero = array[0] as! Value
            let one = array[1] as! Other1.Value
            return (zero, one)
        }
    }

    /// Returns a value that becomes determined after the callee and both other
    /// futures become determined.
    ///
    /// - see: SequenceType.allFilled()
    public func and<Other1: FutureProtocol, Other2: FutureProtocol>(_ one: Other1, _ two: Other2) -> Future<(Value, Other1.Value, Other2.Value)> {
        return [ toAny(), one.toAny(), two.toAny() ].allFilled().every { (array) in
            let zero = array[0] as! Value
            let one = array[1] as! Other1.Value
            let two = array[2] as! Other2.Value
            return (zero, one, two)
        }
    }

    /// Returns a value that becomes determined after the callee and all other
    /// futures become determined.
    ///
    /// - see: SequenceType.allFilled()
    public func and<Other1: FutureProtocol, Other2: FutureProtocol, Other3: FutureProtocol>(_ one: Other1, _ two: Other2, _ three: Other3) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value)> {
        return [ toAny(), one.toAny(), two.toAny(), three.toAny() ].allFilled().every { (array) in
            let zero = array[0] as! Value
            let one = array[1] as! Other1.Value
            let two = array[2] as! Other2.Value
            let three = array[3] as! Other3.Value
            return (zero, one, two, three)
        }
    }

    /// Returns a value that becomes determined after the callee and all other
    /// futures become determined.
    ///
    /// - see: SequenceType.allFilled()
    public func and<Other1: FutureProtocol, Other2: FutureProtocol, Other3: FutureProtocol, Other4: FutureProtocol>(_ one: Other1, _ two: Other2, _ three: Other3, _ four: Other4) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value, Other4.Value)> {
        return [ toAny(), one.toAny(), two.toAny(), three.toAny(), four.toAny() ].allFilled().every { (array) in
            let zero = array[0] as! Value
            let one = array[1] as! Other1.Value
            let two = array[2] as! Other2.Value
            let three = array[3] as! Other3.Value
            let four = array[4] as! Other4.Value
            return (zero, one, two, three, four)
        }
    }

    /// Returns a value that becomes determined after the callee and all other
    /// futures become determined.
    ///
    /// - see: SequenceType.allFilled()
    public func and<Other1: FutureProtocol, Other2: FutureProtocol, Other3: FutureProtocol, Other4: FutureProtocol, Other5: FutureProtocol>(_ one: Other1, _ two: Other2, _ three: Other3, _ four: Other4, _ five: Other5) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value, Other4.Value, Other5.Value)> {
        return [ toAny(), one.toAny(), two.toAny(), three.toAny(), four.toAny(), five.toAny() ].allFilled().every { (array) in
            let zero = array[0] as! Value
            let one = array[1] as! Other1.Value
            let two = array[2] as! Other2.Value
            let three = array[3] as! Other3.Value
            let four = array[4] as! Other4.Value
            let five = array[5] as! Other5.Value
            return (zero, one, two, three, four, five)
        }
    }

    /// Returns a value that becomes determined after the callee and all other
    /// futures become determined.
    ///
    /// - see: SequenceType.allFilled()
    public func and<Other1: FutureProtocol, Other2: FutureProtocol, Other3: FutureProtocol, Other4: FutureProtocol, Other5: FutureProtocol, Other6: FutureProtocol>(_ one: Other1, _ two: Other2, _ three: Other3, _ four: Other4, _ five: Other5, _ six: Other6) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value, Other4.Value, Other5.Value, Other6.Value)> {
        return [ toAny(), one.toAny(), two.toAny(), three.toAny(), four.toAny(), five.toAny(), six.toAny() ].allFilled().every { (array) in
            let zero = array[0] as! Value
            let one = array[1] as! Other1.Value
            let two = array[2] as! Other2.Value
            let three = array[3] as! Other3.Value
            let four = array[4] as! Other4.Value
            let five = array[5] as! Other5.Value
            let six = array[6] as! Other6.Value
            return (zero, one, two, three, four, five, six)
        }
    }

    /// Returns a value that becomes determined after the callee and all other
    /// futures become determined.
    ///
    /// - see: SequenceType.allFilled()
    public func and<Other1: FutureProtocol, Other2: FutureProtocol, Other3: FutureProtocol, Other4: FutureProtocol, Other5: FutureProtocol, Other6: FutureProtocol, Other7: FutureProtocol>(_ one: Other1, _ two: Other2, _ three: Other3, _ four: Other4, _ five: Other5, _ six: Other6, _ seven: Other7) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value, Other4.Value, Other5.Value, Other6.Value, Other7.Value)> {
        return [ toAny(), one.toAny(), two.toAny(), three.toAny(), four.toAny(), five.toAny(), six.toAny(), seven.toAny() ].allFilled().every { (array) in
            let zero = array[0] as! Value
            let one = array[1] as! Other1.Value
            let two = array[2] as! Other2.Value
            let three = array[3] as! Other3.Value
            let four = array[4] as! Other4.Value
            let five = array[5] as! Other5.Value
            let six = array[6] as! Other6.Value
            let seven = array[7] as! Other7.Value
            return (zero, one, two, three, four, five, six, seven)
        }
    }
}

// swiftlint:enable line_length
// swiftlint:enable function_parameter_count
// swiftlint:enable force_cast
