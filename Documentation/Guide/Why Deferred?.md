## Why Deferred?

If you're a computer, people are really slow. And networks are REALLY slow.

### Async Programming with Callbacks Is Bad News

The standard solution to this in Cocoaland is writing async methods with
a callback, either to a delegate or a completion block.

Async programming with callbacks rapidly descends into callback hell:
you're transforming your program into what amounts to a series of
gotos. This is hard to understand, hard to reason about, and hard to
debug.

### How Deferred is Different

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
friends.upon(.main) { friends in
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
let friends: Deferred<[Friend]> = fetchFriends(for: jimbob)
let names: Future<[Name]> = friends.andThen(upon: .global()) { (friends: [Friend]) -> Future<[Name]> in
    // fork: get an array of not-yet-determined names
    let names: [Deferred<Name>] = friends.map { AsynchronousCall(.Name, friend: $0) }

    // get a not-yet-determined array of now-determined names
    return names.allFilled()
}

names.upon(.main) { (names: [Name]) in
    // names has been determined - use it!
    dataSource.array = names
    tableView.reloadData()
}
```

