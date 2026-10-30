#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint tapjoy_offerwall.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tapjoy_offerwall'
  s.version          = '14.6.0'
  s.summary          = 'Flutter Plugin for Tapjoy SDK.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://dev.tapjoy.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tapjoy' => 'grow_tapjoy_sdk@unity3d.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Tapjoy
  s.dependency 'TapjoySDK', '14.6.0'
  s.static_framework = true

end
