## Mastering The Future Type

Deferred is designed to scale with the fundamentals you see above. Large applications can be built using just `Deferred` and its `upon` and `fill` methods.

### Read-Only Views

It sometimes just doesn't make *sense* to be able to `fill` something; if you have a `Deferred` wrapping `UIApplication`'s push notification token, what does it mean if someone in your codebase calls `fill` on it?

You may have noticed that anybody can call `upon` on a `Deferred` type; this is fundamental. But the same is true of `fill`, and this may be a liability as different pieces of code interact with each other. How can we make it **read-only**?

For this reason, Deferred is split into `FutureProtocol` and `PromiseProtocol`, both protocols the `Deferred` type conforms to. You can think of these as the "reading" and "writing" sides of a deferred value; a future can only be `upon`ed, and a promise can only be `fill`ed.

Deferred also provides the `Future` type, a wrapper for anything that's a `PromiseProtocol` much like the Swift `Any` types. You can use it protectively to make a `Deferred` read-only. Reconsider the example from above:

```swift
extension FriendsViewController {

    // `FriendsViewController` is the only of the `Deferred` in its
    // `Promise` role, and can use it as it pleases.
    private var friends: Deferred<Value>?

    // Now this method can vend a `Future` and not worry about the
    // rules of accessing its private `Deferred`.
    func refreshFriends() -> Future<[Friend]> {
        let friends = fetchFriends(for: jimbob)
        friends.upon(.main) { friends in
            let names = friends.map { $0.name }
            dataSource.array = names
            tableView.reloadData()
        }

        /* Stash the `Deferred<Value>` for defaulting later. */
        self.friends = friends

        return Future(friends)
    }

    func cancelFriends() {
        friends?.fill(with: [])
    }

}
```

Use of the `Future` type isn't only defensive, it encapsulates and hides implementation details.

```swift
extension FriendsStore {

    // dependency, injected later on
    var context: NSManagedObjectContext?

    func getLocalFriends(for user: User) -> Future<[Friend]> {
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

Deferred's abstractions can be extended using protocols. [`FutureProtocol`](http://bignerdranch.github.io/Deferred/Protocols/FutureProtocol.html) gives you all the power of the `Deferred` type on anything you build.

An example algorithm, included in Deferred, is the `IgnoringFuture`. Simply call `ignored()` to create a future that gets "filled" with `Void`:

```swift
func whenFriendsAreLoaded() -> IgnoringFuture<Void> {
    return self.deferredFriends.ignored()
}
```

This method erases the `Value` of the `Deferred` without the boilerplate of creating a new `Deferred<Void>` and having to wait on an `upon`.

The [`Executor`](http://bignerdranch.github.io/Deferred/Protocols/Executor.html) protocol allows changing the behavior of an `upon` call, and any derived algorithm such as `map` or `andThen`. If your app isn't using a `DispatchQueue` directly, this allows you to adapt other asynchronous mechanisms like `NSManagedObjectContext.performBlock(_:)` for Deferred.
