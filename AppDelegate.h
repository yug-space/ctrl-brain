#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) NSStatusItem *statusItem;

- (void)triggerCapture;

@end
