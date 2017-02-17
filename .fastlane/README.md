fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

## Choose your installation method:

<table width="100%" >
<tr>
<th width="33%"><a href="http://brew.sh">Homebrew</a></td>
<th width="33%">Installer Script</td>
<th width="33%">Rubygems</td>
</tr>
<tr>
<td width="33%" align="center">macOS</td>
<td width="33%" align="center">macOS</td>
<td width="33%" align="center">macOS or Linux with Ruby 2.0.0 or above</td>
</tr>
<tr>
<td width="33%"><code>brew cask install fastlane</code></td>
<td width="33%"><a href="https://download.fastlane.tools/fastlane.zip">Download the zip file</a>. Then double click on the <code>install</code> script (or run it in a terminal window).</td>
<td width="33%"><code>sudo gem install fastlane -NV</code></td>
</tr>
</table>
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
