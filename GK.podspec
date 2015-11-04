Pod::Spec.new do |s|
    s.name = 'GK'
    s.version = '3.26.4'
    s.license = { :type => 'AGPL-3.0', :file => 'LICENSE' }
    s.summary = 'A powerful data-driven framework in Swift.'
    s.homepage = 'http://www.graphkit.io/'
    s.social_media_url = 'https://www.facebook.com/graphkit'
    s.authors = { 'GraphKit Inc.' => 'support@graphkit.io' }
    s.source = { :git => 'https://github.com/GraphKit/GraphKit.git', :tag => s.version }
    s.ios.deployment_target = '8.0'
    s.osx.deployment_target = '10.10'
    s.source_files = 'Source/*.swift'
    s.requires_arc = true
end
