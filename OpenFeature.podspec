Pod::Spec.new do |s|
  s.name             = 'OpenFeature'
  s.version          = '0.3.0' # x-release-please-version
  s.summary          = 'OpenFeature iOS SDK'
  s.description      = <<-DESC
OpenFeature is an open specification that provides a vendor-agnostic, community-driven API for feature flagging that works with your favorite feature flag management tool or in-house solution. This Swift SDK supports iOS, macOS, watchOS, and tvOS.
                       DESC
  s.homepage         = 'https://github.com/open-feature/swift-sdk'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'OpenFeature' => 'https://github.com/open-feature' }
  s.source           = { :git => 'https://github.com/open-feature/swift-sdk.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '11.0'
  s.watchos.deployment_target = '7.0'
  s.tvos.deployment_target = '14.0'
  s.swift_version = '5.5'
  
  s.source_files = 'Sources/OpenFeature/**/*'
  
  s.frameworks = 'Foundation'
end 