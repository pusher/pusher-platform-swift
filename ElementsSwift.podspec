Pod::Spec.new do |s|
  s.name             = 'ElementsSwift'
  s.version          = '0.1.0'
  s.summary          = 'An Elements client library in Swift'
  s.homepage         = 'https://github.com/pusher/elements-client-swift'
  s.license          = 'MIT'
  s.author           = { "Hamilton Chapman" => "hamchapman@gmail.com" }
  s.source           = { git: "https://github.com/pusher/elements-client-swift.git", tag: s.version.to_s }
  s.social_media_url = 'https://twitter.com/pusher'

  s.requires_arc = true
  s.source_files = 'Source/*.swift'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'
end
