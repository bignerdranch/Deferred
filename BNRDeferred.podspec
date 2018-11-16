Pod::Spec.new do |s|
  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.name         = "BNRDeferred"
  s.version      = "4.0.0-beta.3"
  s.summary      = "Work with values that haven't been determined yet."

  s.description  = <<-DESC
  Deferred is an asynchronous promise-style API that can be used as an
  alternative to the "block callback" pattern. It lets you work with values that
  haven't been determined yet, like an array that's coming later (one day!) from
  a web service call. It was originally inspired by OCaml's Deferred library.
                   DESC

  s.homepage     = "https://github.com/bignerdranch/Deferred"
  s.documentation_url = "https://bignerdranch.github.io/Deferred/"

  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.license = { :type => 'MIT', :file => 'LICENSE' }

  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.authors          = {"Zachary Waldowski" => "zachary@bignerdranch.com",
                        "Big Nerd Ranch" => nil}
  s.social_media_url = "https://twitter.com/bignerdranch"

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.swift_version             = "4.1"
  s.cocoapods_version         = ">=1.1.0"
  s.ios.deployment_target     = "8.0"
  s.osx.deployment_target     = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target    = "9.0"

  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.source       = { :git => "https://github.com/bignerdranch/Deferred.git", :tag => "#{s.version}" }

  # ――― Source Settings ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.source_files  = "Sources/**/*.swift"
  s.preserve_path = "Sources/Atomics"
  s.module_name   = "Deferred"

  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.pod_target_xcconfig = { "SWIFT_INCLUDE_PATHS": "$(PODS_TARGET_SRCROOT)/Sources/Atomics/include" }

end
