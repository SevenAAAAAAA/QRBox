# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'QRBox' do
  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
  pod 'YYKit' 
  pod 'Masonry'
  pod 'SVProgressHUD', '~> 2.3.1'
  pod 'AFNetworking', :git => 'https://github.com/crasowas/AFNetworking.git'
  pod 'Toast', '~> 4.1.1'
  pod 'SDWebImage'
  pod 'SGQRCode'
  pod 'CocoaAsyncSocket'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      config.build_settings['ARCHS'] = ['$(ARCHS_STANDARD)']
    end
  end
end
