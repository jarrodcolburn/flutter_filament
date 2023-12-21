#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_filament.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_filament'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/*', 'src/*', "src/camutils/*", 'src/ios/*', 'include/filament/*', 'include/*', 'include/material/*.c'
  s.public_header_files = 'include/SwiftFlutterFilamentPlugin-Bridging-Header.h',  'include/FlutterFilamentApi.h', 'include/FlutterFilamentFFIApi.h', 'include/ResourceBuffer.hpp', 'include/Log.hpp'
  s.dependency 'Flutter' 
  s.platform = :ios, '13'
  s.static_framework = true
  s.vendored_libraries = "lib/*.a"
  s.user_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '"i386" "arm64', 
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
    'OTHER_CFLAGS' => '"-fvisibility=default" "$(inherited)"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/include" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/include/filament" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/src" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/src/image" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/src/shaders"  "$(inherited)"',
    'ALWAYS_SEARCH_USER_PATHS' => 'YES',
    "OTHER_LDFLAGS" =>  '-lfilament -lbackend -lfilameshio -lfilamat -lgeometry -lutils -lfilabridge -lgltfio_core -lfilament-iblprefilter -limage -limageio -ltinyexr -lgltfio_core -lfilaflat -ldracodec -libl -lktxreader -lpng -lpng16  -lz -lstb -luberzlib -lsmol-v -luberarchive -lzstd -lstdc++',
    'LIBRARY_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/lib" "$(inherited)"',
  }

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '"i386" "arm64', 
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
    'OTHER_CXXFLAGS' => '"--std=c++17" "-fmodules" "-fcxx-modules" "-fvisibility=default" "$(inherited)"',
    'OTHER_CFLAGS' => '"-fvisibility=default" "$(inherited)"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/include" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/include/filament" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/src" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/src/image" "${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/src/shaders"  "$(inherited)"',
    'ALWAYS_SEARCH_USER_PATHS' => 'YES',
    "OTHER_LDFLAGS" =>  '-lfilament -lbackend -lfilameshio -lfilamat -lgeometry -lutils -lfilabridge -lgltfio_core -lfilament-iblprefilter -limage -limageio -ltinyexr -lgltfio_core -lfilaflat -ldracodec -libl -lktxreader -lpng -lpng16   -lz -lstb -luberzlib -lsmol-v -luberarchive -lzstd -lstdc++',
    'LIBRARY_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_filament/ios/lib" "$(inherited)"',
  }

  s.swift_version = '5.0'
end
