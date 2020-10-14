# Getting Started

Deferred is designed to be used as a framework on Apple platforms, which requires a minimum deployment target of iOS 10, macOS 10.12, watchOS 3.0, or tvOS 10.0.

Linux is also supported.

There are a few different options to install Deferred.

## Swift Packages in Xcode

Use Xcode 11 or higher for Swift Packages support. See [Xcode Help: “Link a target to a package product”](https://help.apple.com/xcode/mac/11.4/index.html?localePath=en.lproj#/devb83d64851) or [WWDC 2019: “Adopting Swift Packages in Xcode”](https://developer.apple.com/videos/play/wwdc2019/408/) for details. At the “Choose Package Repository” window, enter the repository URL `https://github.com/bignerdranch/Deferred.git`.

### Troubleshooting Swift Packages (Xcode 11)

If you incorporate Deferred into your project using Swift Packages in Xcode feature, you may find that your project's unit and/or UI testing targets fail to build with the following error:

```swift
import Deferred // ERROR: missing required module 'Atomics'
```

This can happen either in Xcode builds or command line builds. This is a known Xcode bug that has received [repeated attention from Apple](https://github.com/apple/swift-nio/issues/1128), but is still [reproducible](https://github.com/apple/swift-nio/issues/1128#issuecomment-588483372), at least as of Xcode 11.3.1.

If this happens to you, here are workarounds we have found that may help:

1. In your unit or UI test target, add the Deferred library to the linked libraries build phase, even if that test target doesn't use it directly.

2. *Sometimes Required in Addition to Remedy 1:* If you are also using an Xcode scheme that is pointed at a unit or UI test target, you must also make sure that the "Build" section of the scheme editor includes your application target in that list. By default, if you add a new Xcode scheme for, e.g., a UI test target, the application won't be included in that list.

Both of these workarounds somehow manage to coax Xcode into including the necessary `-fmodule-map-file` compiler flag for application source files that contain `import Deferred` statements.

## Swift Package Manager

Use Swift 5.1 or greater for [Swift Package Manager](https://swift.org/package-manager/) support.

Add us to your `Package.swift`:

```swift
// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "My Extremely Nerdy App",
    dependencies: [
        .package(url: "https://github.com/bignerdranch/Deferred.git", from: "4.1.0"),
    ]
)
```

## CocoaPods

[CocoaPods](https://cocoapods.org) is a popular, Ruby-inspired Cocoa package manager.

Add the following to your [Podfile](http://guides.cocoapods.org/using/the-podfile.html):

```ruby
pod 'BNRDeferred', '~> 4.0'
```

You will also need to make sure you're opting into using frameworks:

```ruby
use_frameworks!
```

Then run `pod install`.

## Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized, hands-off package manager built in Swift.

Add the following to your Cartfile:

```cartfile
github "bignerdranch/Deferred" ~> 4.0
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][https://github.com/Carthage/Carthage/blob/master/README.md] for up-to-date installation instructions.
