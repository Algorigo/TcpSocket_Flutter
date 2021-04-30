#import "TcpsocketPlugin.h"
#if __has_include(<tcpsocket_plugin/tcpsocket_plugin-Swift.h>)
#import <tcpsocket_plugin/tcpsocket_plugin-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "tcpsocket_plugin-Swift.h"
#endif

@implementation TcpsocketPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftTcpsocketPlugin registerWithRegistrar:registrar];
}
@end
