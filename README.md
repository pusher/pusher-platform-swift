# ElementsSwift (elements-client-swift) (also works with Objective-C!)

![Languages](https://img.shields.io/badge/languages-swift%20%7C%20objc-orange.svg)
[![Twitter](https://img.shields.io/badge/twitter-@Pusher-blue.svg?style=flat)](http://twitter.com/Pusher)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/pusher/pusher-websocket-swift/master/LICENSE.md)


## I just want to copy and paste some code to get me started

What else would you want? Head over to the example app [ViewController.swift](https://github.com/pusher/elements-client-swift/blob/master/Elements%20macOS%20Example/Elements%20macOS%20Example/ViewController.swift) to get some code you can drop in to get started.


## Table of Contents

* [Installation](#installation)
* [Configuration](#configuration)
* [Connection](#connection)
* [Testing](#testing)
* [Communication](#communication)
* [Credits](#credits)
* [License](#license)


## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects and is our recommended method of installing ElementsSwift and its dependencies.

If you don't already have the Cocoapods gem installed, run the following command:

```bash
$ gem install cocoapods
```

To integrate ElementsSwift into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

pod 'ElementsSwift'
```

Then, run the following command:

```bash
$ pod install
```

If you find that you're not having the most recent version installed when you run `pod install` then try running:

```bash
$ pod cache clean --all
$ pod repo update ElementsSwift
$ pod install
```

Also you'll need to make sure that you've not got the version of ElementsSwift locked to an old version in your `Podfile.lock` file.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate ElementsSwift into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "pusher/elements-client-swift"
```


## Configuration

There are a number of configuration parameters which can be set for the Elements client. For Swift usage they are:

#### Required

- `token (String)` - the token that the client will use to make requests
- `namespace (String)` - the namespace of the resources the client will be making requests to

#### Optional

- `host (String)` - the host you'd like to connect to
- `port (Int)` - the port that you'd like to connect to

The `namespace` parameter must be of the type `ElementsNamespace`. This is an enum defined as:

```swift
public enum ElementsNamespace {
    case appId(String)
    case raw(String)
}
```

You can use it like this:

```swift
let namespace = ElementsNamespace.appId("123")
// => "/apps/123"

let namespace = ElementsNamespace.raw("/some/other/namespace/123")
// => "/some/other/namespace/123"
```

All of these configuration options need to be passed to a `ElementsClientConfig` object, which in turn needs to be passed to the Elements object when instantiating it, for example:

#### Swift
```swift
let config = ElementsClientConfig(
    token: "my.client.token.",
    namespace: .appId("123")
)

let elements = Elements(config: config)
```

## Connection

The library uses HTTP/2 to connect to the Elements servers. The functionality for this is provided as part of `URLSession`.


## Testing

There are a set of tests for the library that can be run using the standard method (Command-U in Xcode).

The tests also get run on [Travis-CI](https://travis-ci.org/pusher/elements-client-swift). See [.travis.yml](https://github.com/pusher/elements-client-swift/blob/master/.travis.yml) for details on how the Travis tests are run.


## Communication

- Found a bug? Please open an issue.
- Have a feature request. Please open an issue.
- If you want to contribute, please submit a pull request (preferrably with some tests 🙂 ).


## Credits

ElementsSwift is owned and maintained by [Pusher](https://pusher.com). It was originally created by [Hamilton Chapman](https://github.com/hamchapman).


## License

ElementsSwift is released under the MIT license. See [LICENSE](https://github.com/pusher/elements-client-swift/blob/master/LICENSE.md) for details.
