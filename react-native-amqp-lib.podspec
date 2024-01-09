# react-native-amqp-lib.podspec

require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = package['name']
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = package['description']
  s.homepage     = "https://github.com/github_account/react-native-amqp-lib"
  s.license      = "MIT"
  s.authors      = { "Your Name" => "yourname@email.com" }
  s.platforms    = { :ios => "9.0" }
  s.source       = { :git => "https://github.com/github_account/react-native-amqp-lib.git", :tag => "#{s.version}" }

  s.preserve_paths = 'README.md', 'package.json', 'index.js'
  'iOS/RCTReactNativeRabbitMq/*.{h,m}'
  #s.source_files = "ios/**/*.{h,c,cc,cpp,m,mm,swift}"
  s.source_files   = 'ios/*.{h,c,cc,cpp,m,mm,swift}', 'ios/AMQP/*.{a,h,c,cc,cpp,m,mm,swift}'
  s.requires_arc = true

  s.dependency "React"
  # ...
  # s.dependency "..."
end

