# Deferred
## Vital Statistics
- What: Lets you work with values that haven't been determined yet,
        like an array that's coming (one day!) from a web service call.
- Who: John Gallagher <jgallagher@bignerdranch.com> wrote this.
- Swift: v2.1 for now. :warning: **NOTE:** Not 2.0!
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
For further info, please refer to [the documentation](docs.md)
as well as comments in the generated headers.

If you have a question not answered by either,
please open an issue!
