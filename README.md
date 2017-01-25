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

Then run `pod init` to create your `Podfile`, and add the following lines to it:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
source 'git@github.com:pusher/PrivatePodSpecs.git'
platform :ios, '10.0' # change this if you're not making an iOS app!

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
$ pod cache clean --all
$ pod repo update PusherPlatform
$ pod install
```

Also you'll need to make sure that you've not got the version of PusherPlatform locked to an old version in your `Podfile.lock` file.

### ~~Carthage~~ - For Hackday use CocoaPods

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate PusherPlatform into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "pusher/elements-client-swift"
```

## Feeds

### TL;DR (let me copy paste something)

```swift
let authorizer = SimpleTokenAuthorizer(jwt: "your.token.here")
let app = try! App(id: "yourAppId", authorizer: authorizer)

let myFeed = app.feeds("myFeed")

myFeed.subscribeWithResume(
    onOpen: { Void in print("We're subscribed to myFeed") },
    onAppend: { itemId, headers, item in print("Received new item", item) } ,
    onEnd: { statusCode, headers, info in print("Subscription ended", info) },
    onError: { error in print("Error: ", error) },
    onStateChange: { oldState, newState in print("State of subscription changed from \(oldState) to \(newState)") }
) { result in
    switch result {
    case .failure(let error):
        // handle the error appropriately
    case .success(let sub):
        // you now have access to the subscription if you want to dig into internal-y things
    }
}
```

### Getting started

First we need to have an instance of an `App`. To create an `App` we need to pass in an app's `id` along with an `authorizer`. An `authorizer` is what `App` objects uses to ensure that any requests made will have the appropriate authorization information attached to them. In our example we're going to use a `SimpleTokenAuthorizer`, which, as the name suggests, is an `authorizer` that accepts a token (a JSON web token or JWT to be precise) and uses that for authorization. You can find, or generate, tokens to test things out by visiting [the dashboard](https://elements-dashboard.herokuapp.com).

```swift
let authorizer = SimpleTokenAuthorizer(jwt: "your.token.here")
let app = try! App(id: "YOUR APP ID", authorizer: authorizer)
```

### Setting up a FeedsHelper

When we've got an `App` then we can create a `FeedsHelper` object, which is where we specify the name of our feed:

```swift
let myFeed = app.feeds("myFeed")
```

### Subscribing to receive new items

Now that we've got a `FeedsHelper` we can subscribe to that feed to start receiving new items. When you subscribe to a feed you also receive (up to) the 50 most recently added items in the feed. For each of these items the `onAppend` function that you provide will be called.

```swift
myFeed.subscribeWithResume(
    onOpen: { Void in print("We're subscribed to myFeed") },
    onAppend: { itemId, headers, item in print("Received new item", item) } ,
    onEnd: { statusCode, headers, info in print("Subscription ended", info) },
    onError: { error in print("Error: ", error) },
    onStateChange: { oldState, newState in print("State of subscription changed from \(oldState) to \(newState)") }
) { result in
    switch result {
    case .failure(let error):
        // handle the error appropriately
    case .success(let sub):
        // you now have access to the subscription if you want to dig into internal-y things
    }
}
```

### Fetching older items in a feed

If you need to fetch older items in a feed then you can do so by providing the id of the oldest item that the client is currently aware of. The response will then contain (up to) the next 50 oldest items in the feed. The default number of items that will be returned is (a maximum of) 50, but you can control this limit by providing a value for the `limit` parameter.

```swift
myFeed.fetchOlderItems(limit: 20) { result in
    switch result {
    case .failure(let error):
        // handle the error appropriately
    case .success(let feedItems):
        print(feedItems)
    }
}
```

### Appending to feeds

You can also append items to feeds, provided you have the appropriate permissions.

```swift
myFeed.append(item: ["newValue": 123]) { result in
    switch result {
    case .failure(let error):
        // handle the error appropriately
    case .success(let itemId):
        print(itemId)
    }
}
```

Appending multiple items to a feed in one request is done like this:

```swift
myFeed.append(items: [["newValue": 123], ["someOtherKey": "someString"]]) { result in
    switch result {
    case .failure(let error):
        // handle the error appropriately
    case .success(let itemId):
        // here the itemId returned is the id of the most recently appended item
        // i.e. the last item in the items array passed in as a parameter
        print(itemId)
    }
}
```


## Authorizers

An `authorizer` is what `App` objects uses to ensure that any requests made will have the appropriate authorization information attached to them.

There are two provided `Authorizers` in the library:

- `SimpleTokenAuthorizer`: accepts a token (a JSON web token, or JWT, to be precise) and uses that for authorization
- `EndpointAuthorizer`: makes a request to the provided URL with the expectation that it will receive a response of the form `{ "jwt": "some.relevant.jwt" }`, where the `jwt` value will then be cached by the authorizer and used for authorization purposes

### SimpleTokenAuthorizer

```swift
let authorizer = SimpleTokenAuthorizer(jwt: "YOUR.CLIENT.JWT")
```

### EndpointAuthorizer

```swift
let requestMutator: ((URLRequest) -> (URLRequest))? = { request in
    request.httpMethod = "POST"
    request.httpBody = "some session info".data(using: String.Encoding.utf8)
    return request
}

let authorizer = EndpointAuthorizer(url: "https://my.token.endpoint", requestMutator: requestMutator)
```


## Testing

There are a set of tests for the library that can be run using the standard method (Command-U in Xcode).

The tests also get run on [Travis-CI](https://travis-ci.org/pusher/elements-client-swift). See [.travis.yml](https://github.com/pusher/elements-client-swift/blob/master/.travis.yml) for details on how the Travis tests are run.


## Communication

- Found a bug? Please open an issue.
- Have a feature request. Please open an issue.
- If you want to contribute, please submit a pull request (preferrably with some tests 🙂 ).


## Credits

PusherPlatform is owned and maintained by [Pusher](https://pusher.com). It was originally created by [Hamilton Chapman](https://github.com/hamchapman).


## License

PusherPlatform is released under the MIT license. See [LICENSE](https://github.com/pusher/elements-client-swift/blob/master/LICENSE.md) for details.
