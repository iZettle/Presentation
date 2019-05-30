Pod::Spec.new do |s|
  s.name         = "PresentationFramework"
  s.version      = "1.6.0"
  s.module_name  = "Presentation"
  s.summary      = "Driving presentations from model to result"
  s.description  = <<-DESC
                   Presentation is an iOS Swift library for working with UI presentations in a more formalized way.
                   DESC
  s.homepage     = "https://github.com/iZettle/Presentation"
  s.license      = { :type => "MIT", :file => "LICENSE.md" }
  s.author       = { 'iZettle AB' => 'hello@izettle.com' }

  s.ios.deployment_target = "9.0"
  s.dependency 'FlowFramework', '>= 1.3'

  s.source       = { :git => "https://github.com/iZettle/Presentation.git", :tag => "#{s.version}" }
  s.source_files = "Presentation/*.{swift}"
  s.swift_version = '5.0'
end
