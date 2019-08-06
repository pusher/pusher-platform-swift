# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased](https://github.com/pusher/pusher-platform-swift/compare/0.7.2...HEAD)

## [0.7.2](https://github.com/pusher/pusher-platform-swift/compare/0.7.1...0.7.2) - 2019-08-06

### Fixed

- Fix race condition related to the usage of `state` property of `PPRepeater`.

## [0.7.1](https://github.com/pusher/pusher-platform-swift/compare/0.7.0...0.7.1) - 2019-03-05

### Fixed

- PPBaseURLSessionDelegate uses a serial queue instead of a concurrent queue. Previously
  the concurrent queue was not appropriately guarded so we could get outdated values.

## [0.7.0](https://github.com/pusher/pusher-platform-swift/compare/0.6.4...0.7.0) - 2019-01-31

### Changed

- Requests that receive a 4XX response status code will now not retry, by default

### Added

- `BaseClient` supports `enableTracing` flag so that all requests will have a client-specified request ID added to force tracing

### Fixed

- `requests` object belonging to `PPBaseURLSessionDelegate` now uses a `DispatchQueue` for proper synchronised access

## [0.6.4](https://github.com/pusher/pusher-platform-swift/compare/0.6.3...0.6.4) - 2019-01-22

### Fixed

- Request paths are assumed to have already been appropriately percent encoded and so that is now preserved

## [0.6.3](https://github.com/pusher/pusher-platform-swift/compare/0.6.2...0.6.3) - 2019-01-14

### Fixed

- Fixed some reference cycles

## [0.6.2](https://github.com/pusher/pusher-platform-swift/compare/0.6.1...0.6.2) - 2018-09-10

### Fixed

- When a token provider `fetchToken` request completes as part of a subscription being started the subscription object provided is now ensured to not be nil

## [0.6.1](https://github.com/pusher/pusher-platform-swift/compare/0.6.0...0.6.1) - 2018-08-20

### Changed

- `PPRepeater` functionality to replace `NSTimer` usage

## [0.6.0](https://github.com/pusher/pusher-platform-swift/compare/0.5.0...0.6.0) - 2018-08-08

### Changed

- `Instance` now requires either a `PPSDKInfo` or  a`BaseClient`, not both

### Fixed

- Fixed some reference cycles

## [0.5.0](https://github.com/pusher/pusher-platform-swift/compare/0.4.2...0.5.0) - 2018-04-19

### Fixed

- Extra `?` character being added to requests with no query items has been fixed

### Changed

- Remove refresh token usage from `PPHTTPEndpointTokenProvider`

## [0.4.2](https://github.com/pusher/pusher-platform-swift/compare/0.4.1...0.4.2) - 2018-03-20

### Changed

- Extra logging of token provider endpoint's `absoluteString`
- Only set `queryItems` on token provider request if any are present

## [0.4.1](https://github.com/pusher/pusher-platform-swift/compare/0.4.0...0.4.1) - 2018-02-28

### Fixed

- SDK info headers are now set properly

### Changed

- `PPMessageParser` now parses messages as soon as possible as opposed to always waiting for a complete set of fully-formed messages

## [0.4.0](https://github.com/pusher/pusher-platform-swift/compare/0.3.1...0.4.0) - 2018-02-26

### Changed

- `Instance` has a new required parameter, `sdkInfo`, of type `PPSDKInfo`, which contains information about the SDK being used to make requests to the Pusher servers. It adds the following headers to requests: `X-SDK-Product`, `X-SDK-Version`, `X-SDK-Language`, and `X-SDK-Platform`

## [0.3.1](https://github.com/pusher/pusher-platform-swift/compare/0.3.0...0.3.1) - 2018-02-16

### Changed

- Moved PusherPlatform.xcodeproj to the root of the repo

## [0.3.0](https://github.com/pusher/pusher-platform-swift/compare/0.2.1...0.3.0) - 2018-01-16

### Added

- Support for non-namespaced requests using `.absolute(...)` `destination` in `PPRequestOptions`
- Support for requests where no token will attempt to be fetched even if a `TokenProvider` is present on the `Instance`. This is done by setting `shouldFetchToken` to `false` in a `PPRequestOptions` object
- Support for background session uploads and downloads

## [0.2.1](https://github.com/pusher/pusher-platform-swift/compare/0.2.0...0.2.1) - 2017-11-01

### Changed

- Updated for usage with Xcode 9.1

## [0.2.0](https://github.com/pusher/pusher-platform-swift/compare/0.1.32...0.2.0) - 2017-10-27

### Changed

- `instanceId` property in `Instance` renamed to `locator`

## [0.1.32](https://github.com/pusher/pusher-platform-swift/compare/0.1.31...0.1.32) - 2017-10-25

### Fixed

- Query parameters set in the `requestInjector` part of a `PPHTTPEndpointTokenProvider`, when there are no query params set through the string version of the URL, are now included in requests

## [0.1.31](https://github.com/pusher/pusher-platform-swift/compare/0.1.30...0.1.31) - 2017-09-21

### Added

- Swift 4 support

## [0.1.30](https://github.com/pusher/pusher-platform-swift/compare/0.1.29...0.1.30) - 2017-09-19

### Added

- `PPHTTPEndpointTokenProviderError` error description

### Removed

- ClientVersion.swift class

### Changed

- Append URL components in `PPHTTPEndpointTokenProvider`

## [0.1.29](https://github.com/pusher/pusher-platform-swift/compare/0.1.28...0.1.29) - 2017-07-03

### Fixed

- Namespace logic

## [0.1.28](https://github.com/pusher/pusher-platform-swift/compare/0.1.27...0.1.28) - 2017-07-28

### Fixed

- Issue related with instance id

## [0.1.27](https://github.com/pusher/pusher-platform-swift/compare/0.1.26...0.1.27) - 2017-07-25

### Removed

- `host` from the `Instance` initializer

## [0.1.26](https://github.com/pusher/pusher-platform-swift/compare/0.1.25...0.1.26) - 2017-07-24

### Changed

- Rename `App` to `Instance`
- `Instance` and `PPBaseClient` constructor

## [0.1.25](https://github.com/pusher/pusher-platform-swift/compare/0.1.24...0.1.25) - 2017-07-19

### Changed

- Rename path

## [0.1.24](https://github.com/pusher/pusher-platform-swift/compare/0.1.23...0.1.24) - 2017-07-17

### Changed

- Rename default cluster

## [0.1.23](https://github.com/pusher/pusher-platform-swift/compare/0.1.22...0.1.23) - 2017-06-20
