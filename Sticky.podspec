#
# Be sure to run `pod lib lint Sticky.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Sticky'
  s.version          = '0.1.0'
  s.summary          = 'Use Sticky to quickly persist common Swift objects using the Swift 4 Codable type and local file storage.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Sticky allows developers to quickly and easily persist common Swift objects
without the overhead of a full persistence layer. Sticky leverages JSON
and the "Document" directory, along with the Codable protocol, for easy 
storage and access. Sticky is not intended for extremely large or highly 
transactional data sets, however, it does leverage caching to help with performance.
Sticky includes powerful features like built in notification center integration
for transaction events. It also includes a simple schema change management solution
as app data structure changes over the life of the app.
                       DESC

  s.homepage         = 'https://github.com/langdon78/sticky'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'James Langdon' => 'corporatelangdon@gmail.com' }
  s.source           = { :git => 'https://github.com/langdon78/sticky.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.swift_version = '4.0'

  s.source_files = 'sticky/**/*'
  
  # s.resource_bundles = {
  #   'Sticky' => ['Sticky/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
