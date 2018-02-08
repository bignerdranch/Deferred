fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew cask install fastlane`

# Available Actions
### bump_version
```
fastlane bump_version
```
Increment (with 'bump' option) or set (with 'pre' option) the framework version
### pod_lint
```
fastlane pod_lint
```
Run CocoaPods linter
### build_docs
```
fastlane build_docs
```
Output documentation using Jazzy into docs/
### publish_docs
```
fastlane publish_docs
```
Build and publish documentation from docs/ into gh-pages

----

## Mac
### mac test
```
fastlane mac test
```
Test using Swift Package Manager for macOS and Linux
### mac ci
```
fastlane mac ci
```
Execute tests, perform CocoaPods linting, publish documentation

----

## iOS
### ios test
```
fastlane ios test
```
Test using Xcode for iOS
### ios ci
```
fastlane ios ci
```
Execute tests and ensure that auxiliary platforms build

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
