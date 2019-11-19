Pod::Spec.new do |spec|
    spec.name             = 'GTSheet'
    spec.version          = '1.1'
    spec.summary          = 'GTSheet'
  
    spec.homepage         = 'https://github.com/tymphillips/GTSheet'
    spec.license          = { :type => 'MIT', :file => 'LICENSE' }
    spec.source           = { :git => 'https://github.com/tymphillips/GTSheet.git' }
    spec.authors           = {
      'Gametimesf' => 'gametimesf@gmail.com',
      'Tym Phillips' => 'tymphillips@gmail.com'
    }
  
    spec.ios.deployment_target = '10.0'
    spec.source_files = 'GTHalfSheet/GTSheet/**/*'
  end