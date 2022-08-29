# Cheat Sheet: Migrating to Swift Concurrency

Swift Concurrency debuted in Swift 5.5 and Xcode 13.0 for code targeting macOS 12, iOS 15, tvOS 15, and watchOS 8.
In Swift 5.5.2 and Xcode 13.2, Swift Concurrency became back-deployable to macOS 10.15, iOS 13, tvOS 13, or watchOS 6.
Language-level concurrency is robust, safe, and efficient.
It obviates the need for a separate framework like Deferred.

## Basics

|| Deferred | Swift Concurrency
-|-|-
Deployment Targets | macOS 10.12, iOS 10, tvOS 10, watchOS 3 | macOS 10.15, iOS 13, tvOS 13, or watchOS 6 |
Platforms Supported | macOS, iOS, tvOS, watchOS, Linux | macOS, iOS, tvOS, watchOS, Linux, others
Maintained by | Big Nerd Ranch, open source community | Apple, Swift community

## Core Components

Deferred | Swift Concurrency
-|-
`func someMethod() -> Future<Value>` | `func someMethod() async -> Value`
`func someMethod() -> Task<Value>` | `func someMethod() async throws -> Value`
`func someMethod() -> Deferred<Value>` | `func someMethod() async -> Value`[^1]
`someMethod().upon(_:execute:)` | `try someMethod()`
`someMethod().uponSuccess(on:execute:)` | `try await someMethod()`
`Future<Value>` | `Task<Value, Never>`
`Task<Value>` | `Task<Value, Never>`
`Deferred<Value>` | `CheckedContinuation<Value, Never>`
`Task<Value>.Promise` | `CheckedContinuation<Value, Error>`
`Protected` | `actor` types

### Disambiguating `Task`

As you migrate code to Swift Concurrency, you may have files that use both Swift Concurrency and Deferred at the same time. In those files, the `Task<Value>` type from Deferred may be ambiguous with the `Task<Success, Error>` type from Swift.

Work around this with a `typealias`:

```swift
/// A way to avoid conflicts between `_Concurrency.Task` and `Deferred.Task`.
/// Wherever there is not a conflict,  `Task` should be used instead.
typealias AsyncTask = _Concurrency.Task
```

## Methods

Deferred | Swift Concurrency
-|-
`Task(_:onCancel:)` | `withTaskCancellationHandler(operation:onCancel:)`
`Task.cancel()` | `Task<Value, Error>.cancel()`
`map(upon:transform:)` | Use the result of an `await`
`andThen(upon:start:)` | Use multiple `await` statements
`repeat(upon:count:continuingIf:to:)` | Use `await` in a `for` loop
`recover(upon:substituting:)` | Use `catch` in an `async` method
`fallback(upon:to:)` | Use `catch` in an `async` method
`someMethod().ignored()` | `_ = await someMethod()`
`Sequence.firstFilled()` | `withTaskGroup(of:returning:body:)`[^2]
`Collection.allFilled()` | `withTaskGroup(of:returning:body:)`[^3]
`Collection.allSucceeded()` | `withThrowingTaskGroup(of:returning:body:)`[^4]

## Additional Conveniences

Deferred | Swift Concurrency
-|-
`someMethod().upon(.main)` | `@MainActor` | Annotate a closure, method, class, struct, enum, or protocol with `@MainActor`.
`DispatchQueue.any()` | `Task { }`
`Future.async(upon:flags:execute:)` | `Task(priority: ...) { }`

[^1]: Depends on usage. If a caller needs to fulfill the value separately, use a signature like `func someMethod() async -> (Value) -> Void`.
[^2]:  `await group.next()`
[^3]: `for await in group`
[^4]: `for try await in group`
