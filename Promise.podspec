Pod::Spec.new do |s|
    s.name = "Promise"
    s.version = "0.1"
    s.summary = "Promise.swift - A Promise implementation written in Swift"

    s.description = <<-DESC
        Promise.swift - A Promise implementation written in Swift
    DESC

    s.authors = { "yashigani" => "tai.fukui@gmail.com" }
    s.homepage = "https://github.com/yashigani/Promise"
    s.license = { :type => "MIT", :file => "LICENSE" }

    s.ios.deployment_target = "8.0"
    s.source = { :git => "https://github.com/yashigani/Promise.git", :tag => "#{s.version}" }

    s.source_files = "Promise/*.{swift,h}"
end

