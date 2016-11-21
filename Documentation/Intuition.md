## Intutition

A `Deferred<Value>` is a value that might be unknown now but is expected to resolve to a definite `Value` at some time in the future. It is resolved by being "filled" with a `Value`.

A `Deferred<Value>` represents a `Value`. If you just want to work with the eventual `Value`, use `upon`. If you want to produce an `OtherValue` future from a `Deferred<Value>`, check out `map(upon:transform:)` and `andThen(upon:start:)`.

You can wait for an array of values to resolve with `Collection.allFilled()`, or just take the first one to resolve with `Sequence.firstFilled()`. (`allFilled` for just a handful of futures is so common, there's a few variations of `and` to save you the trouble of putting them in an array.)

#### Gotcha: No Double-Stuffed `Deferred`s

It's a no-op to `fill(with:)` an already-`fill`ed `Deferred`. Use `mustFill(with:)` if you want to treat this state as an error.
