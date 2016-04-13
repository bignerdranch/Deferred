# Deferred

Deferred lets you work with values that haven't been determined yet, like an array that's coming later (one day!) from a web service call. It was originally inspired by [OCaml's Deferred](https://ocaml.janestreet.com/ocaml-core/111.25.00/doc/async_kernel/#Deferred) library.

### Vital Statistics

|                                                                                               |
|-----------------------------------------------------------------------------------------------|
|[![Swift 2.2 supported](https://img.shields.io/badge/swift-2.2-EF5138.svg?)][Swift]            |
|[![Under MIT License](https://img.shields.io/badge/license-MIT-blue.svg)][MIT License]         |
|![iOS, OS X, tvOS, and watchOS](https://img.shields.io/cocoapods/p/BNRDeferred.svg)            |
|[!["BNRDeferred" on CocoaPods](https://img.shields.io/cocoapods/v/BNRDeferred.svg)][CocoaPods] |
|[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)][Carthage]|

[Swift]: https://swift.org
[MIT License]: https://github.com/bignerdranch/Deferred/blob/master/LICENSE.txt
[CocoaPods]: https://cocoapods.org/pods/BNRDeferred
[Carthage]: https://github.com/Carthage/Carthage

## Table of Contents

<!-- Hi there, readme editor! You look nice today. -->
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Intuition](#intuition)
    - [Gotcha: No Double-Stuffed `Deferred`s](#gotcha-no-double-stuffed-deferreds)
- [Why Deferred?](#why-deferred)
  - [Async Programming with Callbacks Is Bad News](#async-programming-with-callbacks-is-bad-news)
  - [Enter Deferred](#enter-deferred)
  - [More Than Just a Callback](#more-than-just-a-callback)
- [Basic Tasks](#basic-tasks)
  - [Vending a Future Value](#vending-a-future-value)
  - [Taking Action when a Future Is Filled](#taking-action-when-a-future-is-filled)
  - [Peeking at the Current Value](#peeking-at-the-current-value)
  - [Blocking on Fulfillment](#blocking-on-fulfillment)
  - [Chaining Deferreds](#chaining-deferreds)
  - [Combining Deferreds](#combining-deferreds)
  - [Cancellation](#cancellation)
- [Mastering The `Future` Type](#mastering-the-future-type)
  - [Read-Only Views](#read-only-views)
  - [Other Patterns](#other-patterns)
- [Getting Started](#getting-started)
  - [Carthage](#carthage)
  - [CocoaPods](#cocoapods)
  - [Swift Package Manager](#swift-package-manager)
- [Further Information](#further-information)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Intuition

A `Deferred<Value>` is a value that might be unknown now but is expected to resolve to a definite `Value` at some time in the future. It is resolved by being "filled" with a `Value`.

A `Deferred<Value>` represents a `Value`. If you just want to work with the eventual `Value`, use `upon`. If you want to produce an `OtherValue` future from a `Deferred<Value>`, check out `map` and `flatMap`.

You can wait for an array of values to resolve with `CollectionType.joinedValues`, or just take the first one to resolve with `SequenceType.earliestFilled`. (`joinedValues ` for just a handful of futures is so common, there's a few versions `FutureType.and` to save you the trouble of putting them in an array.)

#### Gotcha: No Double-Stuffed `Deferred`s

It's a no-op to `fill` an already-`fill`ed `Deferred`. Use `fill(_:assertIfFilled:)` if you want to treat this as an error.

## Why Deferred?

If you're a computer, people are really slow. And networks are REALLY slow.

### Async Programming with Callbacks Is Bad News

The standard solution to this in Cocoaland is writing async methods with
a callback, either to a delegate or a completion block.

Async programming with callbacks rapidly descends into callback hell:
you're transforming your program into what amounts to a series of
gotos. This is hard to understand, hard to reason about, and hard to
debug.

### Enter Deferred

When you're writing synchronous code,
you call a function, you get a return value,
you work with that return value:

```swift
let friends = getFriends(forUser: jimbob)
let names = friends.map { $0.name }
dataSource.array = names
tableView.reloadData()
```

Deferred enables this comfortable linear flow for async programming:

```swift
let friends = fetchFriends(forUser: jimbob)
friends.upon { friends in
    let names = friends.map { $0.name }
    dataSource.array = names
    tableView.reloadData()
}
```

A `Deferred<Value>` is a `Value` whose value is unknown till some future time.
The method passed to `upon` gets run once the value becomes known.

### More Than Just a Callback

You might be thinking, "Wait! That's just a callback!" You got me: `upon` is indeed a callback: the closure gets the `Value` that the `Deferred` was determined to represent and can work with it.

Where `Deferred` shines is the situations where callbacks make you
want to run screaming. Like, say, chaining async calls, or fork–join
of calls. What if getting a friend's name also required a remote call?
We'd want to do this:

- Fetch jimbob's friends
- For each friend, fetch their name
- Once you have all the friends' names, now update the data source
  and reload the table view.

This gets really messy with callbacks. But with `Deferred`, it's just:

```swift
// Let's use type annotations to make it easier to see what's going on here.
let friends: Deferred<[Friend]> = fetchFriends(forUser: jimbob)
let names: Future<[Name]> = friends.flatMap { (friends: [Friend]) -> Future<[Name]> in
    // fork: get an array of not-yet-determined names
    let names: [Deferred<Name>] = friends.map { AsynchronousCall(.Name, friend: $0) }

    // join: get a not-yet-determined array of now-determined names
    return names.joinedValues
}

names.upon { (names: [Name]) in
    // names has been determined - use it!
    dataSource.array = names
    tableView.reloadData()
}
```

## Basic Tasks

### Vending a Future Value

```swift
// Potentially long-running operation.
func performOperation() -> Deferred<Int> {
    // 1. Create deferred.
    let deferred = Deferred<Int>()

    // 2. Kick off asynchronous code that will eventually…
    let queue = /* … */
    dispatch_async(queue) {
        let result = compute_result()

        // 3. … fill the deferred in with its value
        deferred.fill(result)
    }

    // 4. Return the (currently still unfilled) deferred
    return deferred
}
```

### Taking Action when a Future Is Filled

<a name="upon"></a>

You can use the `upon(_:body:)` method to run a closure once the `Deferred` has been filled. `upon(_:body:)` can be called multiple times, and the closures will be called in the order they were supplied to `upon(_:body:)`.

By default, `upon(_:)` will run the closures on a background concurrent GCD queue. You can change this by passing a different queue when by using the full `upon(_:body:)` method to specify a queue for the closure.

```swift
let deferredResult = performOperation()

deferredResult.upon { result in
    print("got \(result)")
}
```
### Peeking at the Current Value

Use the `peek()` method to determine whether or not the `Deferred` is currently
filled.

```swift
let deferredResult = performOperation()

if let result = deferredResult.peek() {
    print("filled with \(result)")
} else {
    print("currently unfilled")
}
```

### Blocking on Fulfillment

Use the `wait(_:)` method to wait for a `Deferred` to be filled, and return the value.

The `wait(_:)` method supports a few timeout values, including an arbitrary number of seconds.

```swift
// WARNING: Blocks the calling thread!
let result: Int = performOperation().wait(.Forever)!
```

### Chaining Deferreds

Monadic `map` and `flatMap` are available to chain `Deferred` results. For example, suppose you have a method that asynchronously reads a string, and you want to call `Int.init(_:)` on that string:

```swift
// Producer
func readString() -> Deferred<String> {
    let deferredResult = Deferred<String>()
    // dispatch_async something to fill deferredResult…
    return deferredResult
}

// Consumer
let deferredInt: Future<Int?> = readString().map { Int($0) }
```

`map(upon:_:)` and `flatMap(upon:_:)`, like `upon(_:body:)`, execute on a concurrent background thread by default (once the instance has been filled). The `upon` peramater is if you want to specify the GCD queue as the consumer.

### Combining Deferreds

There are three functions available for combining multiple `Deferred` instances:

```swift
// MARK: and

// `and` creates a new future that is filled once both inputs are available:
let d1: Deferred<Int> = /* … */
let d2: Deferred<String> = /* … */
let dBoth: Future<(Int, String)> = d1.and(d2)

// MARK: joinedValues

// `joinedValues` creates a new future that is filled once all inputs are available.
// All of the input Deferreds must contain the same type.
var deferreds: [Deferred<Int>] = []
for i in 0 ..< 10 {
    deferreds.append(/* … */)
}

// Once all 10 input deferreds are filled, the item at index `i` in the array passed to `upon` will contain the result of `deferreds[i]`.
let allDeferreds: Future<[Int]> = deferreds.joinedValues

// MARK: earliestFilled

// `earliestFilled` creates a new future that is filled once any one of its inputs is available.
// If multiple inputs become available simultaneously, no guarantee is made about which will be selected.
// Once any one of the 10 inputs is filled, `anyDeferred` will be filled with that value.
let anyDeferred: Future<Int> = deferreds.earliestFilled
```

### Cancellation

Cancellation gets pretty ugly with callbacks.
You often have to fork a bunch of, "Wait, has this been cancelled?"
checks throughout your code.

With `Deferred`, it's nothing special:
You resolve the `Deferred` to a default value,
and all the work waiting for your `Deferred` to resolve
is unchanged. It's still a `Value`, whatever its provenance.
This is the power of regarding a `Deferred<Value>` as just a `Value` that
hasn't quite been nailed down yet.

That solves cancellation for consumers of the value.
But generally you have some value-producer work you'd like to abort
on cancellation, like stopping a web request that's in flight.
To do this, the producer adds an `upon` closure to the `Deferred<Value>`
before vending it to your API consumer.
This closure is responsible for aborting the operation if needed.
Now, if someone defaults the `Deferred<Value>` to some `Value`,
the `upon` closure will run and cancel the in-flight operation.

Let's look at cancelling our `fetchFriends(forUser:)` request:

```swift
// MARK: - Client

extension FriendsViewController {

    private var friends: Deferred<Value>?

    func refreshFriends() {
        let friends = fetchFriends(forUser: jimbob)
        friends.upon { friends in
            let names = friends.map { $0.name }
            dataSource.array = names
            tableView.reloadData()
        }

        /* Stash the `Deferred<Value>` for defaulting later. */
        self.friends = friends
    }

    func cancelFriends() {
        friends?.fill([])
    }

}

// MARK: - Producer

func fetchFriends(forUser user: User) -> Deferred<[Friend]> {
    let deferredFriends = Deferred<[Friend]>()
    let session: NSURLSession = /* … */
    let request: NSURLRequest = /* … */
    let task = session.dataTaskWithRequest(request) { data, response, error in
        let friends: [Friend] = parseFriends(data, response, error)
        // fillIfUnfulfilled since we might be racing with another producer
        // to fill this value
        deferredFriends.fillIfUnfulfilled(friends)
    }

    // arrange to cancel on fill
    deferredFriends.upon { [weak task] _ in
        task?.cancel()
    }

    // start the operation that will eventually resolve the deferred value
    task.resume()

    // finally, pass the deferred value to the caller
    return deferredFriends
}
```

## Mastering The `Future` Type

Deferred is designed to scale with the fundamentals you see above. Large applications can be built using just `Deferred` and its `upon` and `fill` methods.

### Read-Only Views

It sometimes just doesn't make *sense* to be able to `fill` something; if you have a `Deferred` wrapping `UIApplication`'s push notification token, what does it mean if someone in your codebase calls `fill` on it?

You may have noticed that anybody can call `upon` on a `Deferred` type; this is fundamental. But the same is true of `fill`, and this may be a liability as different pieces of code interact with each other. How can we make it **read-only**?

For this reason, Deferred is split into `FutureType` and `PromiseType`, both protocols the `Deferred` type conforms to. You can think of these as the "reading" and "writing" sides of a deferred value; a future can only be `upon`ed, and a promise can only be `fill`ed.

Deferred also provides the `Future` type, a wrapper for anything that's a `FutureType` much like the Swift standard library's `Any` types. You can use it protectively to make a `Deferred` read-only. Reconsider the example from above:

```
extension FriendsViewController {

    // `FriendsViewController` is the only of the `Deferred` in its
    // `PromiseType` role, and can use it as it pleases.
    private var friends: Deferred<Value>?

    // Now this method can vend a `Future` and not worry about the
    // rules of accessing its private `Deferred`.
    func refreshFriends() -> Future<[Friend]> {
        let friends = fetchFriends(forUser: jimbob)
        friends.upon { friends in
            let names = friends.map { $0.name }
            dataSource.array = names
            tableView.reloadData()
        }

        /* Stash the `Deferred<Value>` for defaulting later. */
        self.friends = friends

        return Future(friends)
    }

    func cancelFriends() {
        friends?.fill([])
    }

}
```

Use of the `Future` type isn't only defensive, it encapsulates and hides implementation details.

```swift

extension FriendsStore {

    // dependency, injected later on
    var context: NSManagedObjectContext?

    func getLocalFriends(forUser user: User) -> Future<[Friend]> {
        guard let context = context else {
            // a future can be created with an immediate value, allowing the benefits
            // of Deferred's design even if values are available already (consider a
            // stub object, for instance).
            return Future([])
        }

        let predicate: NSPredicate = /* … */

        return Friend.findAll(matching: predicate, inContext: context)
    }

}

```

### Other Patterns

As a codebase or team using Deferred gets larger, it may become important to reduce repetition and noise.

Deferred's abstractions can be extended using protocols. [`FutureType`](http://bignerdranch.github.io/Deferred/Protocols/FutureType.html) gives you all the power of the `Deferred` type on anything you build, and [`ExecutorType`](http://bignerdranch.github.io/Deferred/Protocols/ExecutorType.html) allows different asynchronous semantics in `upon`.

An example algorithm, included in Deferred, is the `IgnoringFuture`. Simply call `ignored()` to create a future that gets "filled" with `Void`:

```swift
func whenFriendsAreLoaded() -> IgnoringFuture<Void> {
    return self.deferredFriends.ignored()
}
```

This method erases the `Value` of the `Deferred` without the boilerplate of creating a new `Deferred<Void>` and having to wait on an `upon`.

## Getting Started

Deferred is designed to be used as an embedded framework, which require a minimum deployment target of iOS 8 or OS X Yosemite (10.10). Embedding through any other means may work, but is not officially supported.

Linux is not yet supported.

There are a few different options to install Deferred.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized, hands-off package manager built in Swift.

Add the following to your Cartfile:

```ruby
github "bignerdranch/Deferred" ~> 2.0
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][carthage-installation]
for up to date installation instructions.

[carthage-installation]: https://github.com/Carthage/Carthage/blob/master/README.md

### CocoaPods

[CocoaPods](https://cocoapods.org) is a popular, Ruby-inspired Cocoa package manager.

Add the following to your [Podfile](http://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod 'BNRDeferred'
```

You will also need to make sure you're opting into using frameworks:

```ruby
use_frameworks!
```

Then run `pod install`.

### Swift Package Manager

We include provisional support for [Swift Package Manager](https://swift.org/package-manager/) on the 2.2 toolchain.

Add us to your `Package.swift`:

```
import PackageDescription

let package = Package(
    name: "My Extremely Nerdy App",
    dependencies: [
        .Package(url: "https://github.com/bignerdranch/Deferred.git", majorVersion: 2),
    ]
)
```

## Further Information

For further info, please refer to comments in the module interface or [the documentation](http://bignerdranch.github.io/Deferred/).

If you have a question not answered by this README or the comments, please open an issue!
