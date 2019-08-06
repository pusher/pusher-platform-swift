Pod::Spec.new do |s|
  s.name             = 'PusherPlatform'
  s.version          = '0.7.1'
  s.summary          = 'Pusher Platform SDK in Swift'
  s.homepage         = 'https://github.com/pusher/pusher-platform-swift'
  s.license          = 'MIT'
  s.author           = { "Hamilton Chapman" => "hamchapman@gmail.com" }
  s.source           = { git: "https://github.com/pusher/pusher-platform-swift.git", tag: s.version.to_s }
  s.social_media_url = 'https://twitter.com/pusher'

  s.requires_arc = true
  s.source_files = 'Sources/*.swift'

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '3.0'
end
