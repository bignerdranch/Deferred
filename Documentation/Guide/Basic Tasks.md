## Basic Tasks

### Vending a Future Value

```swift
// Potentially long-running operation.
func performOperation() -> Deferred<Int> {
    // 1. Create deferred.
    let deferred = Deferred<Int>()

    // 2. Kick off asynchronous code that will eventually…
    let queue: DispatchQueue = /* … */
    queue.async {
        let result = computeResult()

        // 3. … fill the deferred in with its value
        deferred.fill(with: result)
    }

    // 4. Return the (currently still unfilled) deferred
    return deferred
}
```

### Taking Action when a Future Is Filled

<a name="upon"></a>

You can use the `upon(_:execute:)` method to run a function once the `Deferred` has been filled. `upon(_:execute:)` can be called multiple times, and the closures will be called in the order they were supplied to `upon(_:execute:)`.

By default, `upon(_:)` will run the closures on a background concurrent GCD queue. You can change this by passing a different queue when using the full `upon(_:execute:)` method to specify a queue for the closure.

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

Use the `wait(until:)` method to wait for a `Deferred` to be filled, and return the value.

```swift
// warning: Blocks the calling thread!
let result: Int = performOperation().wait(until: .distantFuture)!
```

### Sequencing Deferreds

Monadic `map(upon:transform:)` and `andThen(upon:start:)` are available to chain `Deferred` results. For example, suppose you have a method that asynchronously reads a string, and you want to call `Int.init(_:)` on that string:

```swift
// Producer
func readString() -> Deferred<String> {
    let deferredResult = Deferred<String>()
    // call something async to fill deferredResult…
    return deferredResult
}

// Consumer
let deferredInt: Future<Int?> = readString().map(upon: .any()) { Int($0) }
```

### Combining Deferreds

There are three functions available for combining multiple `Deferred` instances:

```swift
// MARK: and

// `and` creates a new future that is filled once both inputs are available:
let d1: Deferred<Int> = /* … */
let d2: Deferred<String> = /* … */
let dBoth: Future<(Int, String)> = d1.and(d2)

// MARK: allFilled

// `allFilled` creates a new future that is filled once all inputs are available.
// All of the input Deferreds must contain the same type.
var deferreds: [Deferred<Int>] = []
for i in 0 ..< 10 {
    deferreds.append(/* … */)
}

// Once all 10 input deferreds are filled, the item at index `i` in the array passed to `upon` will contain the result of `deferreds[i]`.
let allDeferreds: Future<[Int]> = deferreds.allFilled

// MARK: firstFilled

// `firstFilled ` creates a new future that is filled once any one of its inputs is available.
// If multiple inputs become available simultaneously, no guarantee is made about which will be selected.
// Once any one of the 10 inputs is filled, `anyDeferred` will be filled with that value.
let anyDeferred: Future<Int> = deferreds. firstFilled()
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

Let's look at cancelling our `fetchFriends(for:)` request:

```swift
// MARK: - Client

extension FriendsViewController {

    private var friends: Deferred<Value>?

    func refreshFriends() {
        let friends = fetchFriends(for: jimbob)
        friends.upon(.main) { friends in
            let names = friends.map { $0.name }
            dataSource.array = names
            tableView.reloadData()
        }

        // Stash the `Deferred<Value>` for defaulting later.
        self.friends = friends
    }

    func cancelFriends() {
        friends?.fill(with: [])
    }

}

// MARK: - Producer

func fetchFriends(for user: User) -> Deferred<[Friend]> {
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
