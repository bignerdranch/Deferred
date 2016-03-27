# Deferred

This is an implementation of [OCaml's Deferred](https://ocaml.janestreet.com/ocaml-core/111.25.00/doc/async_kernel/#Deferred) for Swift.

## Vital Statistics
- What: Lets you work with values that haven't been determined yet,
        like an array that's coming (one day!) from a web service call.
- Who: John Gallagher <jgallagher@bignerdranch.com> wrote this.
- Swift: 2.2
- License: MIT
- Carthage: Yup.
- CocoaPods: As [`BNRDeferred`](https://cocoapods.org/pods/BNRDeferred).

## Installation

### [Carthage]

[Carthage]: https://github.com/Carthage/Carthage

Add the following to your Cartfile:

```ruby
github "bignerdranch/Deferred" "2.0b6"
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][carthage-installation]
for up to date installation instructions.

[carthage-installation]: https://github.com/Carthage/Carthage/blob/master/README.md

### [CocoaPods]

[CocoaPods]: http://cocoapods.org

Add the following to your [Podfile](http://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod 'BNRDeferred'
```

You will also need to make sure you're opting into using frameworks:

```ruby
use_frameworks!
```

Then run `pod install`.

## Intuition
A `Deferred<Value>` is a value that might be unknown now
but is expected to resolve to a definite `Value` at some time in the future.
It is resolved by being "filled" with a `Value`.

A `Deferred<Value>` represents a `Value`.
If you just want to work with the eventual `Value`, use `upon`.
If you want to produce a `Deferred<OtherValue>` from the `Deferred<Value>`,
check out `map` and `flatMap`/`bind`.

You can wait for an array of values to resolve with `all`,
or just take the first one to resolve with `any`.
(`all` for just two deferreds is so common, there's a `both` to save you
the trouble of putting them in an array.)

### Gotcha: No Double-Stuffed `Deferred`s
It's an error to `fill` an already-`fill`ed `Deferred`.
Use `fillIfUnfulfilled` if you think anyone else might also be considering
filling the `Deferred`, for example, to default it to a value when
an action is cancelled.

In a future version, `fill` might always be `fillIfUnfulfilled`,
at which point, this gotcha will disappear.

## Why Deferred?
If you're a computer, people are really slow.
And networks are REALLY slow.

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
let friends = SynchronousFriends(forUser: jimbob)
let names = friends.map { $0.name }
dataSource.array = names
tableView.reloadData()
```

Deferred enables this comfortable linear flow for async programming:

```swift
let friends = AsynchronousFriends(forUser: jimbob)
friends.upon { friends in
    let names = friends.map { $0.name }
    dataSource.array = names
    tableView.reloadData()
}
```

A `Deferred<Value>` is a `Value` whose value is unknown till some future time.
The method passed to `upon` gets run once the value becomes known.

### More Than Just a Callback
You might be thinking, "Wait! That's just a callback!"
You got me: `upon` is indeed a callback:
the closure gets the `Value` that the `Deferred` was determined to represent
and can work with it.

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
let friends: Deferred<[Friend]> = AsynchronousFriends(forUser: jimbob)
let names: Deferred<[Name]> = friends.flatMap { friends in
    // fork: get an array of not-yet-determined names
    let names: [Deferred<Name>] = friends.map { AsynchronousCall(.Name, friend: $0) }

    // join: get a not-yet-determined array of now-determined names
    let allNames: Deferred<[Name]> = all(names)
    return allNames
}
names.upon { names: [Name] in
    // names has been determined - use it!
    dataSource.array = names
    tableView.reloadData()
}
```

## Tasks

### Vending a Future

```swift
// Potentially long-running operation.
func performOperation() -> Deferred<Int> {
    // 1. Create deferred.
    let deferred = Deferred<Int>()

    // 2. Kick off asynchronous code that will eventually...
    let queue = ...
    dispatch_async(queue) {
        let result = compute_result()

        // 3. ... fill the deferred in with its value
        deferred.fill(result)
    }

    // 4. Return the (currently still unfilled) deferred
    return deferred
}
```

### <a name="upon"></a>Taking Action when a Future Is Filled

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
    // dispatch_async something to fill deferredResult...
    return deferredResult
}

// Consumer
let deferredInt: Deferred<Int?> = readString().map { Int($0) }
```

`map(upon:_:)` and `flatMap(upon:_:)`, like `upon(_:body:)`, execute on a concurrent background thread by default (once the instance has been filled). The `upon` peramater is if you want to specify the GCD queue as the consumer.

### Combining Deferreds

There are three functions available for combining multiple `Deferred` instances:

```swift
// `both` creates a new Deferred that is filled once both inputs are available
let d1: Deferred<Int> = ...
let d2: Deferred<String> = ...
let dBoth : Deferred<(Int, String)> = d1.and(d2)

// `all` creates a new Deferred that is filled once all inputs are available.
// All of the input Deferreds must contain the same type.
var deferreds: [Deferred<Int>] = []
for i in 0 ..< 10 {
    deferreds.append(...)
}
let allDeferreds: Future<[Int]> = deferreds.joinedValues
// Once all 10 input deferreds are filled, allDeferreds.value[i] will contain the result
// of deferreds[i].value.

// `earliestFilled` creates a new Deferred that is filled once any one of its inputs is available.
// If multiple inputs become available simultaneously, no guarantee is made about which
// will be selected.
var anyDeferred: Deferred<Int> = deferreds.earliestFilled
// Once any one of the 10 inputs is filled, anyDeferred will be filled with that value.
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

Let's look at cancelling our `AsynchronousFriends` request:

```swift
/* * * CLIENT * * */
func refreshFriends() {
    let friends = AsynchronousFriends(forUser: jimbob)
    friends.upon { friends in
        let names = friends.map { $0.name }
        dataSource.array = names
        tableView.reloadData()
    }

    /* Stash the `Deferred<Value>` for defaulting later. */
    self.friends = friends
}

func cancelFriends() {
    self.friends.fillIfUnfulfilled([])
}

/* * * PRODUCER * * */
func AsynchronousFriends(forUser: jimbob) -> Deferred<[Friend]> {
    let deferredFriends: Deferred<Friend> = Deferred()
    let request: NSURLRequest = /* … */
    let task = self.session.dataTaskWithRequest(request) {
        data, response, error in
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

### Further Information

For further info, please refer to comments in the generated headers.

If you have a question not answered by this README or the comments,
please open an issue!
