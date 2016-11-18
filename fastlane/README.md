fastlane documentation
================
# Installation
```
sudo gem install fastlane
```
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
More information about fastlane can be found on [https://fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [GitHub](https://github.com/fastlane/fastlane/tree/master/fastlane).
