// Entry point for tool/ffigen.dart: every iOS API the app reads.
//
// ffigen parses this against the iOS SDK; only the declarations listed in
// tool/ffigen.dart end up in lib/ffi/ios_bindings.g.dart.

#import <CoreFoundation/CFBase.h>
#import <Foundation/NSProcessInfo.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <UIKit/UIDevice.h>
#import <os/proc.h>
#import <sys/sysctl.h>
