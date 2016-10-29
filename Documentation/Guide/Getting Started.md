## Getting Started

Deferred is designed to be used as an embedded framework, which requires a minimum deployment target of iOS 8 or macOS 10.10. Embedding through any other means may work, but is not officially supported.

Linux is not yet supported.

There are a few different options to install Deferred.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized, hands-off package manager built in Swift.

Add the following to your Cartfile:

```
github "bignerdranch/Deferred" "3.0.0-beta.2"
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][carthage-installation]
for up to date installation instructions.

[carthage-installation]: https://github.com/Carthage/Carthage/blob/master/README.md

### CocoaPods

[CocoaPods](https://cocoapods.org) is a popular, Ruby-inspired Cocoa package manager.

Add the following to your [Podfile](http://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod 'BNRDeferred', '~> 3.0-beta'
```

You will also need to make sure you're opting into using frameworks:

```ruby
use_frameworks!
```

Then run `pod install`.

### Swift Package Manager

We include support for [Swift Package Manager](https://swift.org/package-manager/) on 3.x toolchains.

Add us to your `Package.swift`:

```swift
import PackageDescription

let package = Package(
    name: "My Extremely Nerdy App",
    dependencies: [
        .Package(url: "https://github.com/bignerdranch/Deferred.git", majorVersion: 3),
    ]
)
```
