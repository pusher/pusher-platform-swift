# PusherPlatform (pusher-platform-swift) (also works with Objective-C!)

![Languages](https://img.shields.io/badge/languages-swift%20%7C%20objc-orange.svg)
[![Twitter](https://img.shields.io/badge/twitter-@Pusher-blue.svg?style=flat)](http://twitter.com/Pusher)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/pusher/pusher-websocket-swift/master/LICENSE.md)


## I just want to copy and paste some code to get me started

What else would you want? Head over to the example app [ViewController.swift](https://github.com/pusher/pusher-platform-swift/blob/master/Pusher%20Platform%20macOS%20Example/Pusher%20Platform%20macOS%20Example/ViewController.swift) to get some code you can drop in to get started.


## Table of Contents

* [Installation](#installation)
* [Feeds](#feeds)
* [Authorizers](#authorizers)
* [Testing](#testing)
* [Communication](#communication)
* [Credits](#credits)
* [License](#license)


## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects and is our recommended method of installing PusherPlatform and its dependencies.

If you don't already have the Cocoapods gem installed, run the following command:

```bash
$ gem install cocoapods
```

Then run `pod init` to create your `Podfile` (if you don't already have one).

Next, add the Pusher private pod spec repository: 

```
pod repo install pusher  git@github.com:pusher/PrivatePodSpecs.git
```

Then add the following lines to it:

```ruby
platform :ios, '9.0' # change this if you're not making an iOS app!

target 'your-app-name' do
  pod 'PusherPlatform'
end

# the rest of the file...
```

Then, run the following command:

```bash
$ pod install
```

If you find that you're not having the most recent version installed when you run `pod install` then try running:

```bash
$ pod repo update
$ pod install
```

Also you'll need to make sure that you've not got the version of PusherPlatform locked to an old version in your `Podfile.lock` file.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate PusherPlatform into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "pusher/pusher-platform-swift"
```

### Directly using a framework

```
TODO
```


### Getting started

First we need to have an instance of an `App`. To create an `App` we need to pass in an app's `id`. You can get your app ID from the dashboard.

```swift
let app = try! App(id: "YOUR APP ID")
```

The `App` instance allows you to interact with the service using the Elements protocol. The high level methods it exposes are:

- `request` for standard HTTP requests
- `subscribe` for longer running subscriptions
and 
- `subscribeWithResume` which is a special kind of subscription that you can resume from the last received event ID.

## Testing

There are a set of tests for the library that can be run using the standard method (Command-U in Xcode).

The tests also get run on [Travis-CI](https://travis-ci.org/pusher/pusher-platform-swift). See [.travis.yml](https://github.com/pusher/pusher-platform-swift/blob/master/.travis.yml) for details on how the Travis tests are run.


## Communication

- Found a bug? Please open an issue.
- Have a feature request. Please open an issue.
- If you want to contribute, please submit a pull request (preferrably with some tests 🙂 ).


## Credits

PusherPlatform is owned and maintained by [Pusher](https://pusher.com). It was originally created by [Hamilton Chapman](https://github.com/hamchapman).


## License

PusherPlatform is released under the MIT license. See [LICENSE](https://github.com/pusher/pusher-platform-swift/blob/master/LICENSE.md) for details.
