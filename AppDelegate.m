#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <Vision/Vision.h>
#import <fcntl.h>

static NSString *const kSourceLineAttr = @"CBSourceLine";

static NSString *CBTrimWhitespace(NSString *s) {
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

// Returns the value for `wantKey` from a KEY=VALUE .env file, or nil.
// Supports `export KEY=...`, # comments, and single/double quoted values.
static NSString *CBValueFromDotEnvFile(NSString *path, NSString *wantKey) {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!contents.length) return nil;

    for (NSString *raw in [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *line = CBTrimWhitespace(raw);
        if (!line.length || [line hasPrefix:@"#"]) continue;
        if ([line hasPrefix:@"export "]) line = CBTrimWhitespace([line substringFromIndex:7]);

        NSRange eq = [line rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;

        NSString *k = CBTrimWhitespace([line substringToIndex:eq.location]);
        if (![k isEqualToString:wantKey]) continue;

        NSString *v = CBTrimWhitespace([line substringFromIndex:eq.location + 1]);
        if (v.length >= 2) {
            unichar f = [v characterAtIndex:0];
            unichar l = [v characterAtIndex:v.length - 1];
            if ((f == '"' && l == '"') || (f == '\'' && l == '\'')) {
                v = [v substringWithRange:NSMakeRange(1, v.length - 2)];
            }
        }
        if (v.length) return v;
    }
    return nil;
}

// Searches the usual locations so the key resolves whether launched from a
// shell (cwd) or as a GUI .app (bundle Resources / bundle's parent dir).
static NSString *CBDotEnvValue(NSString *key) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];

    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    if (cwd.length) [paths addObject:[cwd stringByAppendingPathComponent:@".env"]];

    NSString *resources = [[NSBundle mainBundle] resourcePath];
    if (resources.length) [paths addObject:[resources stringByAppendingPathComponent:@".env"]];

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    if (bundlePath.length) {
        [paths addObject:[[bundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@".env"]];
    }

    NSString *home = NSHomeDirectory();
    [paths addObject:[home stringByAppendingPathComponent:@"SecondBrain/.env"]];
    [paths addObject:[home stringByAppendingPathComponent:@".config/ctrlbrain/.env"]];

    for (NSString *p in paths) {
        NSString *v = CBValueFromDotEnvFile(p, key);
        if (v.length) return v;
    }
    return nil;
}

static NSString *const kApiKeyDefaultsKey = @"CBApiKey";
static NSString *const kOnboardedDefaultsKey = @"CBOnboarded";

static NSString *SupermemoryAPIKey(void) {
    NSString *key = NSProcessInfo.processInfo.environment[@"SUPERMEMORY_API_KEY"];
    if (key.length) return key;
    key = [[[NSUserDefaults standardUserDefaults] stringForKey:kApiKeyDefaultsKey]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (key.length) return key;
    return CBDotEnvValue(@"SUPERMEMORY_API_KEY") ?: @"";
}

static NSString *CBApiKey(void) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:kApiKeyDefaultsKey]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

static void CBSetApiKey(NSString *k) {
    k = [k stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [[NSUserDefaults standardUserDefaults] setObject:(k ?: @"") forKey:kApiKeyDefaultsKey];
}

static NSString *const kContainerTagDefaultsKey = @"CBContainerTag";
static NSString *const kDefaultContainerTag = @"my-second-brain";
static NSString *const kHotKeyCodeDefaultsKey = @"CBHotKeyCode";
static NSString *const kHotKeyModsDefaultsKey = @"CBHotKeyMods";   // Carbon modifier mask
static NSString *const kHotKeyLabelDefaultsKey = @"CBHotKeyLabel"; // display label, e.g. "2"
static NSString *const kCaptureDir = @"SecondBrain/captures";
static NSString *const kBrainFile = @"SecondBrain.mdx";
static NSString *const kDefaultDescribeBackend = @"claude";

static NSString *CBDescribeBackend(void) {
    NSString *backend = NSProcessInfo.processInfo.environment[@"CTRL_BRAIN_DESCRIBE_BACKEND"];
    if (!backend.length) backend = CBDotEnvValue(@"CTRL_BRAIN_DESCRIBE_BACKEND");
    backend = [[backend stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    return [backend isEqualToString:@"codex"] ? @"codex" : kDefaultDescribeBackend;
}

static void CBAddPathComponent(NSMutableArray<NSString *> *paths, NSMutableSet<NSString *> *seen, NSString *path) {
    if (!path.length || [seen containsObject:path]) return;
    [paths addObject:path];
    [seen addObject:path];
}

static NSString *CBToolSearchPath(void) {
    NSString *home = NSHomeDirectory();
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    NSArray<NSString *> *base = @[
        @"/opt/homebrew/bin",
        @"/usr/local/bin",
        @"/usr/bin",
        @"/bin",
        @"/usr/sbin",
        @"/sbin",
        [home stringByAppendingPathComponent:@".local/bin"],
        [home stringByAppendingPathComponent:@".claude/local"],
        [home stringByAppendingPathComponent:@".bun/bin"],
        [home stringByAppendingPathComponent:@".npm-global/bin"],
        [home stringByAppendingPathComponent:@".cargo/bin"],
        [home stringByAppendingPathComponent:@".nodenv/shims"],
        [home stringByAppendingPathComponent:@".asdf/shims"]
    ];
    for (NSString *path in base) CBAddPathComponent(paths, seen, path);

    NSString *nvmDir = [home stringByAppendingPathComponent:@".nvm/versions/node"];
    NSArray<NSString *> *versions = [NSFileManager.defaultManager contentsOfDirectoryAtPath:nvmDir error:nil];
    for (NSString *version in versions) {
        CBAddPathComponent(paths, seen, [[nvmDir stringByAppendingPathComponent:version] stringByAppendingPathComponent:@"bin"]);
    }

    for (NSString *path in [NSProcessInfo.processInfo.environment[@"PATH"] componentsSeparatedByString:@":"]) {
        CBAddPathComponent(paths, seen, path);
    }
    return [paths componentsJoinedByString:@":"];
}

static EventHotKeyRef gHotKeyRef;
static __weak AppDelegate *gDelegate;

static NSColor *CBColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [NSColor colorWithCalibratedRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static OSStatus HotKeyHandler(EventHandlerCallRef next, EventRef evt, void *ud) {
    (void)next;
    (void)evt;
    (void)ud;
    dispatch_async(dispatch_get_main_queue(), ^{
        [gDelegate triggerCapture];
    });
    return noErr;
}

// The single source of truth for the Supermemory container tag. Used by every
// upload and written into the document's frontmatter.
static NSString *CBContainerTag(void) {
    NSString *tag = [[[NSUserDefaults standardUserDefaults] stringForKey:kContainerTagDefaultsKey]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return tag.length ? tag : kDefaultContainerTag;
}

static void CBSetContainerTag(NSString *tag) {
    tag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [[NSUserDefaults standardUserDefaults] setObject:(tag.length ? tag : kDefaultContainerTag)
                                              forKey:kContainerTagDefaultsKey];
}

// Capture hotkey — stored as a virtual key code + Carbon modifier mask, with a
// display label. Defaults to Control+Shift+2.
static UInt32 CBHotKeyCode(void) {
    NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:kHotKeyCodeDefaultsKey];
    return n ? (UInt32)n.integerValue : (UInt32)kVK_ANSI_2;
}

static UInt32 CBHotKeyModifiers(void) {
    NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:kHotKeyModsDefaultsKey];
    return n ? (UInt32)n.integerValue : (UInt32)(controlKey | shiftKey);
}

static NSString *CBHotKeyLabel(void) {
    NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:kHotKeyLabelDefaultsKey];
    return s.length ? s : @"2";
}

static void CBSetHotKey(UInt32 code, UInt32 mods, NSString *label) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:(NSInteger)code forKey:kHotKeyCodeDefaultsKey];
    [d setInteger:(NSInteger)mods forKey:kHotKeyModsDefaultsKey];
    [d setObject:(label ?: @"") forKey:kHotKeyLabelDefaultsKey];
}

static NSString *CBHotKeyDisplay(UInt32 mods, NSString *label) {
    NSMutableString *s = [NSMutableString string];
    if (mods & controlKey) [s appendString:@"⌃"];
    if (mods & optionKey)  [s appendString:@"⌥"];
    if (mods & shiftKey)   [s appendString:@"⇧"];
    if (mods & cmdKey)     [s appendString:@"⌘"];
    [s appendString:(label.length ? label.uppercaseString : @"?")];
    return s;
}

// A readable label for a virtual key code (handles common non-printing keys).
static NSString *CBKeyLabelForKeyCode(UInt16 kc, NSString *chars) {
    switch (kc) {
        case 49:  return @"Space";
        case 36:  case 76: return @"↩";
        case 48:  return @"⇥";
        case 51:  return @"⌫";
        case 117: return @"⌦";
        case 123: return @"←";
        case 124: return @"→";
        case 125: return @"↓";
        case 126: return @"↑";
        case 116: return @"⇞";
        case 121: return @"⇟";
        case 115: return @"↖";
        case 119: return @"↘";
        default: break;
    }
    NSString *u = chars.uppercaseString;
    if (u.length && [u characterAtIndex:0] >= 0x20) return u;
    return [NSString stringWithFormat:@"#%d", (int)kc];
}

// True for an entry's metadata line, e.g. "Jun 1, 2026 at 9:42 AM  ·  https://…".
static BOOL CBIsMetaLine(NSString *t) {
    if (t.length < 16) return NO;
    NSArray *months = @[@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
                        @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"];
    if (![months containsObject:[t substringToIndex:3]]) return NO;
    if ([t characterAtIndex:3] != ' ') return NO;
    if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[t characterAtIndex:4]]) return NO;
    return [t containsString:@", "] && [t containsString:@" at "];
}

@interface AppDelegate () <NSWindowDelegate, NSTextViewDelegate>
@property (strong) NSWindow *viewerWindow;
@property (strong) NSTextView *brainTextView;
@property (copy) NSString *brainFrontmatter;
@property (strong) dispatch_source_t brainWatch;
@property (assign) BOOL brainDirty;
@property (assign) NSTimeInterval lastTriggerTime;
@property (assign) NSTimeInterval lastSelfWrite;
@property (strong) NSWindow *settingsWindow;
@property (strong) NSTextField *containerTagField;
@property (strong) NSSecureTextField *apiKeyField;
@property (strong) NSWindow *onboardingWindow;
@property (strong) NSTextField *onboardKeyField;
@property (strong) NSTextField *onboardContainerField;
@property (strong) NSButton *shortcutButton;
@property (strong) id shortcutMonitor;
@property (assign) BOOL recordingShortcut;
@property (assign) NSInteger pendingHotCode;
@property (assign) NSInteger pendingHotMods;
@property (copy) NSString *pendingHotLabel;
@property (weak) NSMenuItem *captureMenuItem;
@property (assign) BOOL usesLogoImage;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;
    gDelegate = self;
    [self registerBundledFonts];
    [self installLoginAgentIfNeeded];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSString *logoPath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"logo.svg"];
    NSImage *logo = [[NSImage alloc] initWithContentsOfFile:logoPath];
    if (logo && logo.isValid && logo.size.width > 0) {
        logo.size = NSMakeSize(20, 20);
        self.statusItem.button.image = logo;
        self.statusItem.button.imagePosition = NSImageOnly;
        self.usesLogoImage = YES;
    } else {
        self.statusItem.button.title = @"Ctrl+Brain";
    }

    NSMenu *menu = [[NSMenu alloc] init];
    self.captureMenuItem = [menu addItemWithTitle:[self captureMenuTitle]
                                           action:@selector(triggerCapture) keyEquivalent:@""];
    [menu addItemWithTitle:@"Open" action:@selector(showViewer:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];
    [menu addItemWithTitle:@"Reveal Captures Folder" action:@selector(revealCapturesFolder:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    self.statusItem.menu = menu;

    // Hidden main menu with a standard Edit submenu. Accessory (menu-bar) apps
    // have no menu bar, so ⌘V/⌘C/⌘X/⌘A would otherwise never reach the focused
    // text field. Installing this routes the standard editing key-equivalents.
    [self installEditMenu];

    [self ensureAccessibilityPrompt];
    [self registerHotKey];
    [self ensureCaptureDir];
    [self notify:@"Ctrl+Brain ready"];

    if ([NSProcessInfo.processInfo.arguments containsObject:@"--show-viewer"]) {
        [self showViewer:nil];
    }

    if (![NSUserDefaults.standardUserDefaults boolForKey:kOnboardedDefaultsKey]) {
        [self showOnboarding];
    }
}

- (void)registerBundledFonts {
    NSString *dir = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"fonts"];
    NSArray<NSString *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *fn in files) {
        if (![fn.pathExtension.lowercaseString isEqualToString:@"ttf"]) continue;
        NSURL *url = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:fn]];
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
    }
}

- (void)installLoginAgentIfNeeded {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    if (!bundlePath.length || ![bundlePath.pathExtension.lowercaseString isEqualToString:@"app"]) return;

    NSString *label = NSBundle.mainBundle.bundleIdentifier ?: @"local.ctrlbrain.CtrlBrain";
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *libraryURL = [fm URLForDirectory:NSLibraryDirectory
                                   inDomain:NSUserDomainMask
                          appropriateForURL:nil
                                     create:YES
                                      error:nil];
    NSURL *agentsURL = [libraryURL URLByAppendingPathComponent:@"LaunchAgents" isDirectory:YES];
    if (![fm createDirectoryAtURL:agentsURL withIntermediateDirectories:YES attributes:nil error:nil]) return;

    NSDictionary *plist = @{
        @"Label": label,
        @"ProgramArguments": @[@"/usr/bin/open", @"-gj", bundlePath],
        @"RunAtLoad": @YES
    };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:nil];
    if (!data.length) return;

    NSURL *plistURL = [agentsURL URLByAppendingPathComponent:[label stringByAppendingString:@".plist"]];
    NSData *existing = [NSData dataWithContentsOfURL:plistURL];
    if (![existing isEqualToData:data]) {
        [data writeToURL:plistURL options:NSDataWritingAtomic error:nil];
    }
}

// Space Grotesk (site sans) by PostScript name, with a system fallback.
- (NSFont *)sg:(CGFloat)size weight:(NSFontWeight)w {
    NSString *name = @"SpaceGrotesk-Regular";
    if (w >= NSFontWeightBold)          name = @"SpaceGrotesk-Bold";
    else if (w >= NSFontWeightSemibold) name = @"SpaceGrotesk-SemiBold";
    else if (w >= NSFontWeightMedium)   name = @"SpaceGrotesk-Medium";
    NSFont *f = [NSFont fontWithName:name size:size];
    return f ?: [NSFont systemFontOfSize:size weight:w];
}

// Instrument Serif (site serif), regular or italic, with a New York / Georgia fallback.
- (NSFont *)is:(CGFloat)size italic:(BOOL)italic {
    NSFont *f = [NSFont fontWithName:(italic ? @"InstrumentSerif-Italic" : @"InstrumentSerif-Regular") size:size];
    if (f) return f;
    NSFont *base = [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
    if (@available(macOS 11.0, *)) {
        NSFontDescriptor *d = [base.fontDescriptor fontDescriptorWithDesign:NSFontDescriptorSystemDesignSerif];
        if (italic) d = [d fontDescriptorWithSymbolicTraits:(d.symbolicTraits | NSFontDescriptorTraitItalic)];
        NSFont *s = [NSFont fontWithDescriptor:d size:size];
        if (s) return s;
    }
    return [NSFont fontWithName:(italic ? @"Georgia-Italic" : @"Georgia") size:size] ?: base;
}

// Uppercase, letter-spaced eyebrow label (matches the site's .eyebrow).
- (NSTextField *)eyebrow:(NSString *)s {
    NSAttributedString *a = [[NSAttributedString alloc] initWithString:s.uppercaseString attributes:@{
        NSFontAttributeName: [self sg:10.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: CBColor(113, 113, 122, 1.0),
        NSKernAttributeName: @(1.7) }];
    return [NSTextField labelWithAttributedString:a];
}

// Outline button (transparent, hairline border) — the site's .btn-line.
- (NSButton *)outlineButton:(NSString *)title action:(SEL)sel {
    NSButton *b = [NSButton buttonWithTitle:@"" target:self action:sel];
    b.bordered = NO; b.wantsLayer = YES;
    b.layer.cornerRadius = 10;
    b.layer.borderWidth = 1;
    b.layer.borderColor = CBColor(255, 255, 255, 0.16).CGColor;
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    b.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: CBColor(232, 232, 236, 1.0),
        NSFontAttributeName: [self sg:14 weight:NSFontWeightMedium],
        NSParagraphStyleAttributeName: ps }];
    return b;
}

// Thin divider line.
- (NSView *)divider:(NSRect)f {
    NSView *v = [[NSView alloc] initWithFrame:f];
    v.wantsLayer = YES;
    v.layer.backgroundColor = CBColor(255, 255, 255, 0.10).CGColor;
    return v;
}

- (void)installEditMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;
    NSApp.mainMenu = mainMenu;
}

// Reopening the app (e.g. launching it again from Finder) brings up the window.
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    (void)flag;
    [self showViewer:nil];
    return YES;
}

// Background capture (synthetic Copy + reading the focused selection) requires
// Accessibility. Prompt once so the system dialog guides the user to grant it.
- (void)ensureAccessibilityPrompt {
    NSDictionary *opts = @{ (__bridge id)kAXTrustedCheckOptionPrompt: @YES };
    BOOL trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
    if (!trusted) {
        NSLog(@"Ctrl+Brain: Accessibility not yet granted; hotkey capture is limited until enabled.");
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    if (gHotKeyRef) {
        UnregisterEventHotKey(gHotKeyRef);
        gHotKeyRef = NULL;
    }
}

- (void)registerHotKey {
    // Install the handler exactly once, even when called again to re-bind.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const EventTypeSpec spec = { kEventClassKeyboard, kEventHotKeyPressed };
        OSStatus h = InstallApplicationEventHandler(&HotKeyHandler, 1, &spec, NULL, NULL);
        if (h != noErr) NSLog(@"Ctrl+Brain: InstallApplicationEventHandler failed (%d)", (int)h);
    });

    // Re-register cleanly (also covers a previous instance holding the hotkey).
    if (gHotKeyRef) {
        UnregisterEventHotKey(gHotKeyRef);
        gHotKeyRef = NULL;
    }
    EventHotKeyID hkid = { 'cbn1', 1 };
    OSStatus status = RegisterEventHotKey(CBHotKeyCode(), CBHotKeyModifiers(), hkid,
                                          GetApplicationEventTarget(), 0, &gHotKeyRef);
    if (status != noErr) {
        NSLog(@"Ctrl+Brain: RegisterEventHotKey failed (%d) - is %@ taken?",
              (int)status, CBHotKeyDisplay(CBHotKeyModifiers(), CBHotKeyLabel()));
        [self notify:@"Shortcut unavailable"];
    }
}

#pragma mark - Capture

- (void)triggerCapture {
    // Debounce: key-repeat or rapid presses must not create duplicate captures.
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - self.lastTriggerTime < 1.0) return;
    self.lastTriggerTime = now;

    NSString *axText = [self selectedTextFromAccessibility];
    if (axText.length) {
        [self processTextSelection:axText];
        return;
    }

    NSArray<NSPasteboardItem *> *previousItems = [self pasteboardSnapshot];
    [[NSPasteboard generalPasteboard] clearContents];
    [self sendCommandC];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if ([self handleSelectionFromPasteboard:[NSPasteboard generalPasteboard]]) {
            return;
        }

        [self restorePasteboardSnapshot:previousItems];
        [self runScreenshotPicker];
    });
}

- (NSArray<NSPasteboardItem *> *)pasteboardSnapshot {
    NSMutableArray<NSPasteboardItem *> *snapshot = [NSMutableArray array];
    for (NSPasteboardItem *item in [NSPasteboard generalPasteboard].pasteboardItems ?: @[]) {
        NSPasteboardItem *copy = [[NSPasteboardItem alloc] init];
        for (NSPasteboardType type in item.types) {
            NSData *data = [item dataForType:type];
            if (data) [copy setData:data forType:type];
        }
        if (copy.types.count) [snapshot addObject:copy];
    }
    return snapshot;
}

- (void)restorePasteboardSnapshot:(NSArray<NSPasteboardItem *> *)items {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    if (items.count) [pb writeObjects:items];
}

- (void)sendCommandC {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef down = CGEventCreateKeyboardEvent(src, (CGKeyCode)8, true);
    CGEventRef up = CGEventCreateKeyboardEvent(src, (CGKeyCode)8, false);
    CGEventSetFlags(down, kCGEventFlagMaskCommand);
    CGEventSetFlags(up, kCGEventFlagMaskCommand);
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    if (down) CFRelease(down);
    if (up) CFRelease(up);
    if (src) CFRelease(src);
}

- (BOOL)handleSelectionFromPasteboard:(NSPasteboard *)pb {
    NSString *text = [[pb stringForType:NSPasteboardTypeString]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length) {
        [self processTextSelection:text];
        return YES;
    }

    NSData *png = [pb dataForType:NSPasteboardTypePNG];
    if (!png) {
        NSData *tiff = [pb dataForType:NSPasteboardTypeTIFF];
        if (tiff) {
            NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff];
            png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        }
    }
    if (png) {
        NSString *path = [self saveImageData:png];
        [self processImageFile:path note:@"Captured image"];
        return YES;
    }

    return NO;
}

- (void)runScreenshotPicker {
    NSString *path = [self newCapturePathWithExtension:@"png"];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/screencapture";
    task.arguments = @[@"-i", path];
    task.terminationHandler = ^(NSTask *t) {
        (void)t;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
                [self processImageFile:path note:@"Screenshot"];
            } else {
                [self notify:@"Capture cancelled"];
            }
        });
    };

    @try {
        [task launch];
    } @catch (NSException *e) {
        NSLog(@"screencapture failed: %@", e);
        [self notify:@"screencapture failed"];
    }
}

- (void)processTextSelection:(NSString *)text {
    NSString *src = [self frontmostSourceURL];
    [self appendEntryWithSource:src body:text];
    [self notify:@"Saved to brain"];
    [self externalChangeReload];
    [self uploadText:text source:src.length ? src : @"manual"];
}

- (void)processImageFile:(NSString *)path note:(NSString *)note {
    [self notify:@"Reading image"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *ocr = [self ocrTextForImageAtPath:path];
        [self describeImageAtPath:path completion:^(NSString *desc) {
            NSMutableString *body = [NSMutableString string];
            [body appendFormat:@"![%@](%@)\n\n", note, path];
            if (desc.length) [body appendFormat:@"%@\n\n", desc];
            if (ocr.length) {
                NSString *quoted = [ocr stringByReplacingOccurrencesOfString:@"\n" withString:@"\n> "];
                [body appendFormat:@"> %@\n", quoted];
            }
            [self appendEntryWithSource:@"" body:body];

            NSMutableString *content = [NSMutableString string];
            [content appendFormat:@"%@\n\n", note];
            if (desc.length) [content appendFormat:@"Description:\n%@\n\n", desc];
            if (ocr.length) [content appendFormat:@"OCR text:\n%@\n\n", ocr];
            [content appendFormat:@"File: %@", path];

            [self uploadText:content source:[@"file://" stringByAppendingString:path]];
            [self uploadFile:path note:note];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self notify:@"Saved to brain"];
                [self externalChangeReload];
            });
        }];
    });
}

- (NSString *)ocrTextForImageAtPath:(NSString *)path {
    NSImage *img = [[NSImage alloc] initWithContentsOfFile:path];
    CGImageRef cg = [img CGImageForProposedRect:NULL context:nil hints:nil];
    if (!cg) return @"";

    __block NSMutableArray<NSString *> *lines = [NSMutableArray array];
    VNRecognizeTextRequest *req = [[VNRecognizeTextRequest alloc]
        initWithCompletionHandler:^(VNRequest *request, NSError *error) {
            (void)error;
            for (VNRecognizedTextObservation *obs in request.results) {
                VNRecognizedText *top = [[obs topCandidates:1] firstObject];
                if (top.string.length) [lines addObject:top.string];
            }
        }];
    req.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
    req.usesLanguageCorrection = YES;

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cg options:@{}];
    NSError *error = nil;
    [handler performRequests:@[req] error:&error];
    if (error) NSLog(@"Vision OCR failed: %@", error);
    return [lines componentsJoinedByString:@"\n"];
}

- (void)describeImageAtPath:(NSString *)path completion:(void (^)(NSString *))completion {
    NSString *prompt = [NSString stringWithFormat:
        @"Look at the image file at %@ and describe it in 2-3 sentences: "
        @"the app or website shown, the main UI, and the key content. "
        @"Output only the description, no preamble.", path];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/env";
    if ([CBDescribeBackend() isEqualToString:@"codex"]) {
        task.arguments = @[@"codex", @"exec", prompt];
    } else {
        task.arguments = @[@"claude", @"-p", prompt, @"--allowedTools", @"Read"];
    }

    NSMutableDictionary *env = [NSProcessInfo.processInfo.environment mutableCopy];
    env[@"PATH"] = CBToolSearchPath();
    task.environment = env;

    NSPipe *out = [NSPipe pipe];
    NSPipe *err = [NSPipe pipe];
    task.standardOutput = out;
    task.standardError = err;
    task.terminationHandler = ^(NSTask *t) {
        NSData *data = [out.fileHandleForReading readDataToEndOfFile];
        NSData *errData = [err.fileHandleForReading readDataToEndOfFile];
        NSString *desc = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        desc = [desc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (t.terminationStatus != 0 || !desc.length) {
            NSString *errText = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
            if (errText.length) NSLog(@"describe CLI failed: %@", errText);
        }
        completion(desc ?: @"");
    };

    @try {
        [task launch];
    } @catch (NSException *e) {
        NSLog(@"describe CLI failed to launch: %@", e);
        completion(@"");
    }
}

- (NSString *)selectedTextFromAccessibility {
    AXUIElementRef system = AXUIElementCreateSystemWide();
    if (!system) return @"";

    AXUIElementRef focused = NULL;
    AXError focusedErr = AXUIElementCopyAttributeValue(system,
                                                       kAXFocusedUIElementAttribute,
                                                       (CFTypeRef *)&focused);
    CFRelease(system);
    if (focusedErr != kAXErrorSuccess || !focused) return @"";

    CFTypeRef selected = NULL;
    AXError selectedErr = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute, &selected);
    CFRelease(focused);
    if (selectedErr != kAXErrorSuccess || !selected) return @"";

    NSString *text = @"";
    if (CFGetTypeID(selected) == CFStringGetTypeID()) {
        text = [(__bridge NSString *)selected copy];
    }
    CFRelease(selected);
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)frontmostSourceURL {
    NSString *app = NSWorkspace.sharedWorkspace.frontmostApplication.localizedName ?: @"";
    NSString *script = nil;

    if ([app isEqualToString:@"Safari"]) {
        script = @"tell application \"Safari\" to return URL of front document";
    } else if ([app rangeOfString:@"Chrome"].location != NSNotFound ||
               [app isEqualToString:@"Arc"]) {
        script = [NSString stringWithFormat:
                  @"tell application \"%@\" to return URL of active tab of front window", app];
    }

    if (script) {
        NSAppleScript *s = [[NSAppleScript alloc] initWithSource:script];
        NSDictionary *err = nil;
        NSAppleEventDescriptor *r = [s executeAndReturnError:&err];
        if (!err && r.stringValue.length) return r.stringValue;
    }
    return app;
}

#pragma mark - Storage (single rolling document)

- (NSString *)captureDirPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:kCaptureDir];
}

- (NSString *)brainFilePath {
    return [[self captureDirPath] stringByAppendingPathComponent:kBrainFile];
}

- (void)ensureCaptureDir {
    NSError *error = nil;
    [NSFileManager.defaultManager createDirectoryAtPath:[self captureDirPath]
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&error];
    if (error) NSLog(@"create capture dir failed: %@", error);
}

- (NSString *)newCapturePathWithExtension:(NSString *)ext {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd_HH-mm-ss-SSS";
    NSString *name = [NSString stringWithFormat:@"%@.%@", [df stringFromDate:[NSDate date]], ext];
    return [[self captureDirPath] stringByAppendingPathComponent:name];
}

- (NSString *)saveImageData:(NSData *)png {
    NSString *path = [self newCapturePathWithExtension:@"png"];
    [png writeToFile:path atomically:YES];
    return path;
}

- (NSString *)entryDateString {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MMM d, yyyy 'at' h:mm a";
    });
    return [formatter stringFromDate:[NSDate date]];
}

// Everything captured lands in one rolling Markdown document. Each capture is a
// section appended to the end, newest last.
- (void)appendEntryWithSource:(NSString *)source body:(NSString *)body {
    NSString *path = [self brainFilePath];

    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        [[self brainHeader] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    NSMutableString *section = [NSMutableString string];
    [section appendString:@"\n---\n\n"];
    [section appendString:[self entryDateString]];
    if (source.length) [section appendFormat:@"  ·  %@", source];
    [section appendString:@"\n\n"];
    [section appendString:body ?: @""];
    if (![section hasSuffix:@"\n"]) [section appendString:@"\n"];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fh) {
        @try {
            [fh seekToEndOfFile];
            [fh writeData:[section dataUsingEncoding:NSUTF8StringEncoding]];
        } @finally {
            [fh closeFile];
        }
    }
}

- (NSString *)firstLine:(NSString *)text {
    for (NSString *raw in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (t.length) return t.length > 80 ? [[t substringToIndex:80] stringByAppendingString:@"…"] : t;
    }
    return @"Note";
}

#pragma mark - Upload

- (void)uploadText:(NSString *)text source:(NSString *)source {
    NSString *key = SupermemoryAPIKey();
    if (!key.length) {
        [self notify:@"No API key set"];
        return;
    }

    NSString *content = [NSString stringWithFormat:@"%@\n\nSource: %@", text, source ?: @""];
    NSDictionary *body = @{
        @"content": content,
        @"containerTag": CBContainerTag(),
        @"metadata": @{ @"source": source ?: @"manual" }
    };

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:@"https://api.supermemory.ai/v3/documents"]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSInteger code = [(NSHTTPURLResponse *)r statusCode];
        if (e || code >= 300) {
            NSString *bodyText = d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"";
            NSLog(@"Supermemory text upload failed (%ld): %@ %@", (long)code, e, bodyText);
        }
    }] resume];
}

- (void)uploadFile:(NSString *)path note:(NSString *)note {
    NSString *key = SupermemoryAPIKey();
    if (!key.length) return;

    NSData *fileData = [NSData dataWithContentsOfFile:path];
    if (!fileData) return;

    NSString *boundary = [@"sbc-" stringByAppendingString:NSUUID.UUID.UUIDString];
    NSMutableData *form = [NSMutableData data];
    void (^field)(NSString *, NSString *) = ^(NSString *name, NSString *val) {
        [form appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [form appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", name, val] dataUsingEncoding:NSUTF8StringEncoding]];
    };
    field(@"containerTag", CBContainerTag());
    field(@"metadata", note);

    [form appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [form appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", path.lastPathComponent] dataUsingEncoding:NSUTF8StringEncoding]];
    [form appendData:[@"Content-Type: image/png\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [form appendData:fileData];
    [form appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:@"https://api.supermemory.ai/v3/documents/file"]];
    req.HTTPMethod = @"POST";
    [req setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    [req setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary]
       forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = form;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSInteger code = [(NSHTTPURLResponse *)r statusCode];
        if (e || code >= 300) {
            NSString *bodyText = d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"";
            NSLog(@"Supermemory file upload failed (%ld): %@ %@", (long)code, e, bodyText);
        }
    }] resume];
}

#pragma mark - Viewer (single document, no chrome)

- (void)showViewer:(id)sender {
    (void)sender;
    [self ensureCaptureDir];
    [self ensureBrainFile];
    [self migrateBrainFileFormat];
    if (!self.viewerWindow) [self buildViewerWindow];
    [self refreshViewer];
    [self startWatchingBrainFile];
    [NSApp activateIgnoringOtherApps:YES];
    [self.viewerWindow makeKeyAndOrderFront:nil];
}

- (void)buildViewerWindow {
    NSRect frame = NSMakeRect(0, 0, 820, 720);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable |
                              NSWindowStyleMaskFullSizeContentView;
    self.viewerWindow = [[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:style
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    self.viewerWindow.title = @"Ctrl+Brain";
    self.viewerWindow.minSize = NSMakeSize(520, 420);
    self.viewerWindow.backgroundColor = CBColor(12, 12, 14, 1.0);
    self.viewerWindow.titlebarAppearsTransparent = YES;
    self.viewerWindow.titleVisibility = NSWindowTitleHidden;
    self.viewerWindow.delegate = self;
    self.viewerWindow.releasedWhenClosed = NO;
    [self.viewerWindow center];

    NSView *container = [[NSView alloc] initWithFrame:frame];
    self.viewerWindow.contentView = container;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:container.bounds];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.borderType = NSNoBorder;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = CBColor(12, 12, 14, 1.0);
    scroll.hasVerticalScroller = YES;
    [container addSubview:scroll];

    // Settings gear (top-right) — edit the Supermemory key / container tag.
    NSButton *gear = [NSButton buttonWithTitle:@"" target:self action:@selector(showSettings:)];
    gear.bordered = NO;
    gear.wantsLayer = YES;
    gear.frame = NSMakeRect(frame.size.width - 46, frame.size.height - 38, 30, 30);
    gear.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    gear.layer.cornerRadius = 15;
    gear.layer.backgroundColor = CBColor(255, 255, 255, 0.06).CGColor;
    gear.layer.borderWidth = 1;
    gear.layer.borderColor = CBColor(255, 255, 255, 0.08).CGColor;
    gear.toolTip = @"Settings";
    if (@available(macOS 11.0, *)) {
        NSImage *g = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"];
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightRegular];
        gear.image = [g imageWithSymbolConfiguration:cfg];
        gear.contentTintColor = CBColor(154, 156, 166, 1.0);
        gear.imagePosition = NSImageOnly;
    } else {
        gear.title = @"⚙";
    }
    [container addSubview:gear];

    NSTextView *tv = [[NSTextView alloc] initWithFrame:scroll.bounds];
    tv.autoresizingMask = NSViewWidthSizable;
    tv.editable = YES;
    tv.selectable = YES;
    tv.richText = YES;
    tv.allowsUndo = YES;
    tv.drawsBackground = YES;
    tv.backgroundColor = CBColor(12, 12, 14, 1.0);
    tv.insertionPointColor = CBColor(252, 124, 54, 1.0);
    tv.textColor = CBColor(228, 228, 233, 1.0);
    tv.font = [NSFont systemFontOfSize:15 weight:NSFontWeightRegular];
    tv.textContainerInset = NSMakeSize(46, 34);
    tv.textContainer.widthTracksTextView = YES;
    tv.typingAttributes = @{ NSFontAttributeName: [NSFont systemFontOfSize:15],
                             NSForegroundColorAttributeName: CBColor(228, 228, 233, 1.0) };
    tv.delegate = self;
    self.brainTextView = tv;
    scroll.documentView = tv;
}

- (NSString *)brainHeader {
    return [NSString stringWithFormat:
            @"---\ntitle: \"Second Brain\"\ncontainerTag: \"%@\"\n---\n\n# Second Brain\n",
            CBContainerTag()];
}

- (void)ensureBrainFile {
    NSString *path = [self brainFilePath];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        [[self brainHeader] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

// One-time cleanup of older entries: drop the redundant "## <title>" heading
// (which duplicated the first body line) and strip backticks from date lines.
- (void)migrateBrainFileFormat {
    NSString *path = [self brainFilePath];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content.length) return;

    NSString *frontmatter = @"";
    NSString *body = content;
    if ([content hasPrefix:@"---\n"]) {
        NSRange close = [content rangeOfString:@"\n---\n" options:0 range:NSMakeRange(3, content.length - 3)];
        if (close.location != NSNotFound) {
            NSUInteger end = close.location + close.length;
            frontmatter = [content substringToIndex:end];
            body = [content substringFromIndex:end];
        }
    }

    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    BOOL changed = NO;
    for (NSString *line in [body componentsSeparatedByString:@"\n"]) {
        NSString *t = CBTrimWhitespace(line);
        if ([t hasPrefix:@"## "]) { changed = YES; continue; }   // drop redundant per-entry heading
        if ([t hasPrefix:@"`"]) {                                // strip backticks from old date lines
            NSString *stripped = [line stringByReplacingOccurrencesOfString:@"`" withString:@""];
            if (![stripped isEqualToString:line]) changed = YES;
            [kept addObject:stripped];
            continue;
        }
        [kept addObject:line];
    }
    if (!changed) return;

    NSString *newBody = [kept componentsJoinedByString:@"\n"];
    while ([newBody containsString:@"\n\n\n"]) {
        newBody = [newBody stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    }

    NSData *data = [[frontmatter stringByAppendingString:newBody] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fh) {
        @try { [fh truncateFileAtOffset:0]; [fh writeData:data]; } @finally { [fh closeFile]; }
    } else {
        [data writeToFile:path atomically:YES];
    }
}

// Loads the document from disk into the editable view: frontmatter is split off
// and remembered (re-attached on save), the body is rendered with inline images.
- (void)refreshViewer {
    if (!self.brainTextView) return;

    NSString *content = [NSString stringWithContentsOfFile:[self brainFilePath]
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil] ?: @"";
    NSString *frontmatter = @"";
    NSString *body = content;
    if ([content hasPrefix:@"---\n"]) {
        NSRange close = [content rangeOfString:@"\n---\n" options:0 range:NSMakeRange(3, content.length - 3)];
        if (close.location != NSNotFound) {
            NSUInteger end = close.location + close.length;
            frontmatter = [content substringToIndex:end];
            body = [content substringFromIndex:end];
        }
    }
    self.brainFrontmatter = frontmatter;

    NSAttributedString *doc = [self attributedBodyFromMarkdown:body];
    // Set programmatically without firing the change/autosave path.
    self.brainTextView.delegate = nil;
    [self.brainTextView.textStorage setAttributedString:doc];
    self.brainTextView.delegate = self;
    self.brainDirty = NO;
    [self.brainTextView scrollRangeToVisible:NSMakeRange(self.brainTextView.string.length, 0)];
}

// Body Markdown -> styled attributed string. Non-image lines keep their exact
// characters (so editing round-trips losslessly); image lines become inline
// image attachments tagged with their original Markdown so they serialize back.
- (NSAttributedString *)attributedBodyFromMarkdown:(NSString *)body {
    NSColor *fg = CBColor(228, 228, 233, 1.0);
    NSColor *muted = CBColor(140, 140, 152, 1.0);

    CGFloat maxW = self.brainTextView.frame.size.width - 92.0;
    if (maxW < 200.0) maxW = 640.0;

    // Syntax characters stay in the file (so editing round-trips) but render
    // invisibly — this is what "parses" the Markdown for display.
    NSDictionary *hidden = @{ NSFontAttributeName: [NSFont systemFontOfSize:0.01],
                              NSForegroundColorAttributeName: [NSColor clearColor] };
    NSDictionary *plain = @{ NSFontAttributeName: [NSFont systemFontOfSize:15],
                             NSForegroundColorAttributeName: fg };

    NSMutableParagraphStyle *entryStyle = [[NSMutableParagraphStyle alloc] init];
    entryStyle.paragraphSpacingBefore = 18.0;
    NSMutableParagraphStyle *bodyStyle = [[NSMutableParagraphStyle alloc] init];
    bodyStyle.lineSpacing = 3.0;

    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] init];
    void (^append)(NSString *, NSDictionary *) = ^(NSString *str, NSDictionary *a) {
        if (str.length) [out appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:a]];
    };

    NSArray<NSString *> *lines = [body componentsSeparatedByString:@"\n"];
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *line = lines[i];
        NSString *trimmed = CBTrimWhitespace(line);
        NSString *sep = (i == lines.count - 1) ? @"" : @"\n";

        // Inline image:  ![alt](/path/to/file.png)
        if ([trimmed hasPrefix:@"!["] && [trimmed hasSuffix:@")"]) {
            NSRange open = [line rangeOfString:@"]("];
            NSRange close = [line rangeOfString:@")" options:NSBackwardsSearch];
            if (open.location != NSNotFound && close.location > open.location + 2) {
                NSUInteger s = open.location + 2;
                NSString *imgPath = [line substringWithRange:NSMakeRange(s, close.location - s)];
                NSImage *img = [[NSImage alloc] initWithContentsOfFile:imgPath];
                if (img && img.size.width > 0) {
                    CGFloat scale = img.size.width > maxW ? maxW / img.size.width : 1.0;
                    NSTextAttachment *att = [[NSTextAttachment alloc] init];
                    att.image = img;
                    att.bounds = NSMakeRect(0, 0, img.size.width * scale, img.size.height * scale);
                    NSMutableAttributedString *imgStr =
                        [[NSAttributedString attributedStringWithAttachment:att] mutableCopy];
                    [imgStr addAttribute:kSourceLineAttr value:line range:NSMakeRange(0, imgStr.length)];
                    [out appendAttributedString:imgStr];
                    append(sep, plain);
                    continue;
                }
            }
        }

        // Entry divider — keep "---" for round-trip, render invisibly.
        if ([trimmed isEqualToString:@"---"] || [trimmed isEqualToString:@"***"]) {
            append([line stringByAppendingString:sep], hidden);
            continue;
        }

        // Headings — hide the leading marker, style the text.
        NSString *marker = nil; CGFloat hsize = 0;
        if ([trimmed hasPrefix:@"### "]) { marker = @"### "; hsize = 16; }
        else if ([trimmed hasPrefix:@"## "]) { marker = @"## "; hsize = 20; }
        else if ([trimmed hasPrefix:@"# "]) { marker = @"# "; hsize = 27; }
        if (marker && line.length >= marker.length) {
            NSDictionary *hAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:hsize weight:NSFontWeightSemibold],
                                      NSForegroundColorAttributeName: fg,
                                      NSParagraphStyleAttributeName: entryStyle };
            append([line substringToIndex:marker.length], hidden);
            append([line substringFromIndex:marker.length], hAttrs);
            append(sep, hAttrs);
            continue;
        }

        // Metadata line (date · source) — muted, spaced above as a new entry.
        if (CBIsMetaLine(trimmed)) {
            NSDictionary *mAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightMedium],
                                      NSForegroundColorAttributeName: muted,
                                      NSParagraphStyleAttributeName: entryStyle };
            append([line stringByAppendingString:sep], mAttrs);
            continue;
        }

        // Blockquote (OCR) — hide "> ", render muted.
        NSRange quote = [line rangeOfString:@"> "];
        if ([trimmed hasPrefix:@"> "] && quote.location != NSNotFound) {
            NSDictionary *qAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:13],
                                      NSForegroundColorAttributeName: muted,
                                      NSParagraphStyleAttributeName: bodyStyle };
            append([line substringToIndex:quote.location + 2], hidden);
            append([line substringFromIndex:quote.location + 2], qAttrs);
            append(sep, qAttrs);
            continue;
        }

        // Body text.
        NSDictionary *bAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:15],
                                  NSForegroundColorAttributeName: fg,
                                  NSParagraphStyleAttributeName: bodyStyle };
        append([line stringByAppendingString:sep], bAttrs);
    }
    return out;
}

// Attributed body -> Markdown, restoring image attachments to their source line.
- (NSString *)serializeBody {
    NSTextStorage *ts = self.brainTextView.textStorage;
    NSMutableString *md = [NSMutableString string];
    [ts enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, ts.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
        (void)stop;
        if (value) {
            NSString *src = [ts attribute:kSourceLineAttr atIndex:range.location effectiveRange:NULL];
            [md appendString:src ?: @""];
        } else {
            [md appendString:[ts.string substringWithRange:range]];
        }
    }];
    return md;
}

#pragma mark - Editing (realtime autosave)

- (void)textDidChange:(NSNotification *)notification {
    if (notification.object != self.brainTextView) return;
    self.brainDirty = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveBrain) object:nil];
    [self performSelector:@selector(saveBrain) withObject:nil afterDelay:0.4];
}

- (void)saveBrain {
    // Only ever write when there are real edits, so a save-on-blur can't
    // overwrite a capture that arrived on disk while we were just viewing.
    if (!self.brainTextView || !self.brainDirty) return;
    self.brainDirty = NO;
    self.lastSelfWrite = [NSDate timeIntervalSinceReferenceDate];
    NSString *full = [(self.brainFrontmatter ?: @"") stringByAppendingString:[self serializeBody]];
    NSString *path = [self brainFilePath];

    // Write in place (truncate + write) so the file-watch descriptor survives.
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    NSData *data = [full dataUsingEncoding:NSUTF8StringEncoding];
    if (fh) {
        @try {
            [fh truncateFileAtOffset:0];
            [fh writeData:data];
        } @finally {
            [fh closeFile];
        }
    } else {
        [data writeToFile:path atomically:YES];
    }
}

#pragma mark - Realtime reload (file watch)

- (void)startWatchingBrainFile {
    [self stopWatchingBrainFile];

    int fd = open([[self brainFilePath] fileSystemRepresentation], O_EVTONLY);
    if (fd < 0) return;

    dispatch_source_t src = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_VNODE, fd,
        DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME,
        dispatch_get_main_queue());

    __weak AppDelegate *weakSelf = self;
    dispatch_source_set_event_handler(src, ^{
        AppDelegate *s = weakSelf;
        if (!s) return;
        unsigned long flags = dispatch_source_get_data(src);
        if (flags & (DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME)) {
            [s startWatchingBrainFile]; // file replaced — re-arm on the new inode
        }
        [s externalChangeReload];
    });
    dispatch_source_set_cancel_handler(src, ^{ close(fd); });
    self.brainWatch = src;
    dispatch_resume(src);
}

- (void)stopWatchingBrainFile {
    if (self.brainWatch) {
        dispatch_source_cancel(self.brainWatch);
        self.brainWatch = nil;
    }
}

// Reload from disk, but never clobber an edit in progress.
- (void)externalChangeReload {
    if (!self.brainTextView) return;
    // Ignore the file event our own autosave just produced.
    if ([NSDate timeIntervalSinceReferenceDate] - self.lastSelfWrite < 0.8) return;
    // Never reload out from under an active edit (would jump the cursor).
    if (self.viewerWindow.isKeyWindow && self.viewerWindow.firstResponder == self.brainTextView) return;
    [self refreshViewer];
}

// Free the window and the in-memory document when closed, so the always-running
// menu-bar process idles at a minimal footprint. Rebuilt on next open.
- (void)windowDidResignKey:(NSNotification *)notification {
    if (notification.object == self.viewerWindow) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveBrain) object:nil];
        [self saveBrain];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.settingsWindow) {
        [self endRecordingShortcut];
        return;
    }
    if (notification.object == self.onboardingWindow) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:kOnboardedDefaultsKey];
        return;
    }
    if (notification.object == self.viewerWindow) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveBrain) object:nil];
        [self saveBrain];
        [self stopWatchingBrainFile];
        self.brainTextView.delegate = nil;
        self.viewerWindow.delegate = nil;
        self.brainTextView = nil;
        self.viewerWindow = nil;
        self.brainFrontmatter = nil;
    }
}

#pragma mark - Settings

- (NSString *)captureMenuTitle {
    return [NSString stringWithFormat:@"Capture  (%@)",
            CBHotKeyDisplay(CBHotKeyModifiers(), CBHotKeyLabel())];
}

- (void)showSettings:(id)sender {
    (void)sender;
    // Stage the current shortcut as the pending (editable) value.
    self.pendingHotCode = (NSInteger)CBHotKeyCode();
    self.pendingHotMods = (NSInteger)CBHotKeyModifiers();
    self.pendingHotLabel = CBHotKeyLabel();

    if (!self.settingsWindow) [self buildSettingsWindow];
    self.containerTagField.stringValue = CBContainerTag();
    self.apiKeyField.stringValue = CBApiKey();
    self.shortcutButton.title = CBHotKeyDisplay((UInt32)self.pendingHotMods, self.pendingHotLabel);

    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindow center];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)toggleRecordShortcut:(id)sender {
    (void)sender;
    if (self.recordingShortcut) { [self endRecordingShortcut]; return; }

    self.recordingShortcut = YES;
    self.shortcutButton.title = @"Press keys…  (Esc cancels)";

    __weak AppDelegate *weakSelf = self;
    self.shortcutMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                                handler:^NSEvent *(NSEvent *e) {
        AppDelegate *s = weakSelf;
        if (!s || !s.recordingShortcut) return e;

        if (e.keyCode == 53) { [s endRecordingShortcut]; return nil; } // Esc cancels

        NSEventModifierFlags f = e.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
        UInt32 mods = 0;
        if (f & NSEventModifierFlagControl) mods |= controlKey;
        if (f & NSEventModifierFlagOption)  mods |= optionKey;
        if (f & NSEventModifierFlagShift)   mods |= shiftKey;
        if (f & NSEventModifierFlagCommand) mods |= cmdKey;
        if (mods == 0) { NSBeep(); return nil; } // require at least one modifier

        s.pendingHotCode = (NSInteger)e.keyCode;
        s.pendingHotMods = (NSInteger)mods;
        s.pendingHotLabel = CBKeyLabelForKeyCode(e.keyCode, e.charactersIgnoringModifiers);
        [s endRecordingShortcut];
        return nil;
    }];
}

- (void)endRecordingShortcut {
    self.recordingShortcut = NO;
    if (self.shortcutMonitor) {
        [NSEvent removeMonitor:self.shortcutMonitor];
        self.shortcutMonitor = nil;
    }
    self.shortcutButton.title = CBHotKeyDisplay((UInt32)self.pendingHotMods, self.pendingHotLabel);
}

- (NSTextField *)settingsLabel:(NSString *)string font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:string ?: @""];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 3;
    return label;
}

// A flat, dark, borderless input container (no chunky bezel / blue focus ring).
- (NSView *)flatFieldBox:(NSTextField *)field frame:(NSRect)f {
    NSView *box = [[NSView alloc] initWithFrame:f];
    box.wantsLayer = YES;
    box.layer.backgroundColor = CBColor(22, 22, 25, 1.0).CGColor;
    box.layer.cornerRadius = 10;
    box.layer.borderWidth = 1;
    box.layer.borderColor = CBColor(255, 255, 255, 0.10).CGColor;
    field.frame = NSMakeRect(15, (f.size.height - 22) / 2, f.size.width - 30, 22);
    field.bezeled = NO;
    field.drawsBackground = NO;
    field.focusRingType = NSFocusRingTypeNone;
    field.font = [self sg:14.5 weight:NSFontWeightRegular];
    field.textColor = CBColor(250, 250, 250, 1.0);
    [box addSubview:field];
    return box;
}

- (void)buildSettingsWindow {
    CGFloat W = 500, H = 490, ix = 32, iw = W - 64;
    self.settingsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, W, H)
                                                      styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskFullSizeContentView)
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
    self.settingsWindow.title = @"";
    self.settingsWindow.titlebarAppearsTransparent = YES;
    self.settingsWindow.titleVisibility = NSWindowTitleHidden;
    self.settingsWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.settingsWindow.backgroundColor = CBColor(13, 13, 16, 1.0);
    self.settingsWindow.delegate = self;
    [self.settingsWindow setReleasedWhenClosed:NO];

    NSView *root = self.settingsWindow.contentView;
    NSColor *labelCol = CBColor(236, 236, 240, 1.0);
    NSColor *hintCol = CBColor(113, 113, 122, 1.0);
    NSFont *labelF = [self sg:13 weight:NSFontWeightSemibold];
    NSFont *hintF = [self sg:11.5 weight:NSFontWeightRegular];

    NSTextField *title = [self settingsLabel:@"Settings" font:[self is:34 italic:NO] color:CBColor(250, 250, 250, 1.0)];
    title.frame = NSMakeRect(ix, 414, iw, 44); [root addSubview:title];

    // --- API key ---
    NSTextField *akLabel = [self settingsLabel:@"Supermemory API key" font:labelF color:labelCol];
    akLabel.frame = NSMakeRect(ix, 380, iw, 18); [root addSubview:akLabel];
    self.apiKeyField = [[NSSecureTextField alloc] init];
    self.apiKeyField.stringValue = CBApiKey();
    self.apiKeyField.placeholderString = @"sm_…";
    [root addSubview:[self flatFieldBox:self.apiKeyField frame:NSMakeRect(ix, 332, iw, 44)]];
    NSTextField *akHint = [self settingsLabel:@"Synced captures use this. Get one at supermemory.ai." font:hintF color:hintCol];
    akHint.frame = NSMakeRect(ix, 310, iw, 16); [root addSubview:akHint];

    // --- Container tag ---
    NSTextField *ctLabel = [self settingsLabel:@"Container tag" font:labelF color:labelCol];
    ctLabel.frame = NSMakeRect(ix, 272, iw, 18); [root addSubview:ctLabel];
    self.containerTagField = [[NSTextField alloc] init];
    self.containerTagField.stringValue = CBContainerTag();
    self.containerTagField.placeholderString = kDefaultContainerTag;
    [root addSubview:[self flatFieldBox:self.containerTagField frame:NSMakeRect(ix, 224, iw, 44)]];
    NSTextField *ctHint = [self settingsLabel:@"Groups captures in Supermemory and the document frontmatter." font:hintF color:hintCol];
    ctHint.frame = NSMakeRect(ix, 202, iw, 16); [root addSubview:ctHint];

    // --- Capture shortcut ---
    NSTextField *scLabel = [self settingsLabel:@"Capture shortcut" font:labelF color:labelCol];
    scLabel.frame = NSMakeRect(ix, 164, iw, 18); [root addSubview:scLabel];
    self.shortcutButton = [NSButton buttonWithTitle:CBHotKeyDisplay((UInt32)self.pendingHotMods, self.pendingHotLabel)
                                             target:self action:@selector(toggleRecordShortcut:)];
    self.shortcutButton.bordered = NO;
    self.shortcutButton.wantsLayer = YES;
    self.shortcutButton.frame = NSMakeRect(ix, 116, 168, 42);
    self.shortcutButton.layer.backgroundColor = CBColor(22, 22, 25, 1.0).CGColor;
    self.shortcutButton.layer.cornerRadius = 10;
    self.shortcutButton.layer.borderWidth = 1;
    self.shortcutButton.layer.borderColor = CBColor(255, 255, 255, 0.10).CGColor;
    self.shortcutButton.font = [self sg:15 weight:NSFontWeightSemibold];
    self.shortcutButton.contentTintColor = CBColor(250, 250, 250, 1.0);
    [root addSubview:self.shortcutButton];
    NSTextField *scHint = [self settingsLabel:@"Click, then press a combo (⌃ ⌥ ⇧ ⌘)." font:hintF color:hintCol];
    scHint.frame = NSMakeRect(214, 128, iw - 182, 28); [root addSubview:scHint];

    NSButton *save = [self filledButton:@"Save" action:@selector(saveSettings:)
                                     bg:CBColor(250, 250, 250, 1.0) fg:CBColor(10, 10, 10, 1.0)];
    save.frame = NSMakeRect(W - ix - 104, 30, 104, 40); save.keyEquivalent = @"\r"; [root addSubview:save];
    NSButton *cancel = [self outlineButton:@"Cancel" action:@selector(cancelSettings:)];
    cancel.frame = NSMakeRect(W - ix - 104 - 12 - 104, 30, 104, 40);
    cancel.keyEquivalent = @"\033";
    [root addSubview:cancel];
}

- (void)saveSettings:(id)sender {
    (void)sender;
    CBSetContainerTag(self.containerTagField.stringValue);
    CBSetApiKey(self.apiKeyField.stringValue);
    CBSetHotKey((UInt32)self.pendingHotCode, (UInt32)self.pendingHotMods, self.pendingHotLabel);

    [self applyContainerTagToBrainFile];
    [self registerHotKey];
    self.captureMenuItem.title = [self captureMenuTitle];
    if (self.brainTextView) [self refreshViewer];

    [self.settingsWindow close];
    [self notify:[NSString stringWithFormat:@"Saved · %@ · %@",
                  CBContainerTag(), CBHotKeyDisplay(CBHotKeyModifiers(), CBHotKeyLabel())]];
}

- (void)cancelSettings:(id)sender {
    (void)sender;
    [self.settingsWindow close];
}

#pragma mark - Onboarding

- (NSButton *)amberButton:(NSString *)title action:(SEL)sel {
    NSButton *b = [NSButton buttonWithTitle:title target:self action:sel];
    b.bezelStyle = NSBezelStyleRounded;
    if (@available(macOS 10.12.2, *)) b.bezelColor = CBColor(230, 169, 60, 1.0);
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    b.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: CBColor(36, 26, 5, 1.0),
        NSFontAttributeName: [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold],
        NSParagraphStyleAttributeName: ps }];
    return b;
}

- (NSButton *)linkButton:(NSString *)title action:(SEL)sel color:(NSColor *)col {
    NSButton *b = [NSButton buttonWithTitle:title target:self action:sel];
    b.bordered = NO;
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    b.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: col,
        NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightMedium],
        NSParagraphStyleAttributeName: ps }];
    return b;
}

// Elegant serif (New York), matching the editorial headings in the brand. Falls back to Georgia.
- (NSFont *)serifFont:(CGFloat)size weight:(NSFontWeight)w {
    NSFont *base = [NSFont systemFontOfSize:size weight:w];
    if (@available(macOS 11.0, *)) {
        NSFontDescriptor *d = [base.fontDescriptor fontDescriptorWithDesign:NSFontDescriptorSystemDesignSerif];
        if (d) { NSFont *f = [NSFont fontWithDescriptor:d size:size]; if (f) return f; }
    }
    NSFont *g = [NSFont fontWithName:@"Georgia" size:size];
    return g ?: base;
}

// A solid, layer-backed rounded button (no chunky system bezel).
- (NSButton *)filledButton:(NSString *)title action:(SEL)sel bg:(NSColor *)bg fg:(NSColor *)fg {
    NSButton *b = [NSButton buttonWithTitle:@"" target:self action:sel];
    b.bordered = NO;
    b.wantsLayer = YES;
    b.layer.backgroundColor = bg.CGColor;
    b.layer.cornerRadius = 12;
    b.layer.masksToBounds = YES;
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    b.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: fg,
        NSFontAttributeName: [self sg:15 weight:NSFontWeightSemibold],
        NSParagraphStyleAttributeName: ps }];
    return b;
}

// A feature row: line-icon + label. Highlighted row gets the iridescent sweep.
- (NSView *)onboardRow:(NSString *)title symbol:(NSString *)sym highlight:(BOOL)hl frame:(NSRect)f {
    NSView *row = [[NSView alloc] initWithFrame:f];
    row.wantsLayer = YES;
    row.layer.cornerRadius = 13;
    row.layer.masksToBounds = YES;
    NSColor *txt, *icn;
    if (hl) {
        CAGradientLayer *g = [CAGradientLayer layer];
        g.frame = row.bounds;
        g.startPoint = CGPointMake(0, 0.5);
        g.endPoint = CGPointMake(1, 0.5);
        g.colors = @[(id)CBColor(246, 212, 233, 1).CGColor,
                     (id)CBColor(223, 216, 244, 1).CGColor,
                     (id)CBColor(207, 232, 244, 1).CGColor,
                     (id)CBColor(211, 242, 226, 1).CGColor,
                     (id)CBColor(243, 238, 203, 1).CGColor,
                     (id)CBColor(248, 220, 207, 1).CGColor];
        [row.layer addSublayer:g];
        txt = CBColor(21, 17, 10, 1); icn = CBColor(21, 17, 10, 1);
    } else {
        row.layer.backgroundColor = CBColor(22, 23, 28, 1).CGColor;
        row.layer.borderWidth = 1;
        row.layer.borderColor = CBColor(255, 255, 255, 0.07).CGColor;
        txt = CBColor(214, 215, 221, 1); icn = CBColor(140, 142, 152, 1);
    }
    NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(16, (f.size.height - 24) / 2, 24, 24)];
    if (@available(macOS 11.0, *)) {
        NSImage *img = [NSImage imageWithSystemSymbolName:sym accessibilityDescription:nil];
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightRegular];
        iv.image = [img imageWithSymbolConfiguration:cfg];
        iv.contentTintColor = icn;
    }
    [row addSubview:iv];
    NSTextField *lab = [self settingsLabel:title
                                      font:[NSFont systemFontOfSize:14.5 weight:NSFontWeightMedium]
                                     color:txt];
    lab.maximumNumberOfLines = 1;
    lab.frame = NSMakeRect(52, (f.size.height - 20) / 2, f.size.width - 68, 20);
    [row addSubview:lab];
    return row;
}

- (void)showOnboarding {
    if (!self.onboardingWindow) [self buildOnboardingWindow];
    self.onboardKeyField.stringValue = CBApiKey();
    self.onboardContainerField.stringValue = CBContainerTag();
    [NSApp activateIgnoringOtherApps:YES];
    [self.onboardingWindow center];
    [self.onboardingWindow makeKeyAndOrderFront:nil];
}

- (void)buildOnboardingWindow {
    CGFloat W = 760, H = 540;
    NSRect frame = NSMakeRect(0, 0, W, H);
    self.onboardingWindow = [[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskFullSizeContentView)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO];
    self.onboardingWindow.titlebarAppearsTransparent = YES;
    self.onboardingWindow.titleVisibility = NSWindowTitleHidden;
    self.onboardingWindow.movableByWindowBackground = YES;
    self.onboardingWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.onboardingWindow.backgroundColor = CBColor(13, 13, 16, 1.0);
    self.onboardingWindow.delegate = self;
    [self.onboardingWindow setReleasedWhenClosed:NO];

    NSView *root = self.onboardingWindow.contentView;
    NSColor *white = CBColor(250, 250, 250, 1.0);
    NSColor *amber = CBColor(224, 169, 75, 1.0);
    NSColor *muted = CBColor(161, 161, 170, 1.0);
    NSColor *labelCol = CBColor(236, 236, 240, 1.0);

    CGFloat leftX = 44;
    CGFloat leftW = 304;
    CGFloat panelX = 380;
    CGFloat panelY = 44;
    CGFloat panelW = W - panelX - 44;
    CGFloat panelH = H - (panelY * 2);

    // Brand row.
    CGFloat lz = 42;
    NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(leftX, 446, lz, lz)];
    NSString *logoPath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"logo.svg"];
    NSImage *logo = [[NSImage alloc] initWithContentsOfFile:logoPath];
    if (logo) { logo.size = NSMakeSize(lz, lz); iv.image = logo; }
    [root addSubview:iv];

    NSMutableParagraphStyle *wmStyle = [[NSMutableParagraphStyle alloc] init];
    wmStyle.alignment = NSTextAlignmentLeft;
    NSDictionary *wmA = @{
        NSFontAttributeName: [self sg:20 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: white,
        NSParagraphStyleAttributeName: wmStyle
    };
    NSMutableAttributedString *wm = [[NSMutableAttributedString alloc] init];
    [wm appendAttributedString:[[NSAttributedString alloc] initWithString:@"ctrl" attributes:wmA]];
    [wm appendAttributedString:[[NSAttributedString alloc] initWithString:@"+" attributes:@{
        NSFontAttributeName: [self sg:20 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: amber,
        NSParagraphStyleAttributeName: wmStyle
    }]];
    [wm appendAttributedString:[[NSAttributedString alloc] initWithString:@"brain" attributes:wmA]];
    NSTextField *wmField = [NSTextField labelWithAttributedString:wm];
    wmField.frame = NSMakeRect(leftX + lz + 12, 454, leftW - lz - 12, 26);
    [root addSubview:wmField];

    // Serif headline (Instrument Serif), amber italic accent — like the hero.
    // Two single-line labels (multi-line NSTextField clips the second line).
    NSTextField *title1 = [self settingsLabel:@"Set up your" font:[self is:39 italic:NO] color:white];
    title1.frame = NSMakeRect(leftX, 360, leftW, 46);
    [root addSubview:title1];
    NSTextField *title2 = [self settingsLabel:@"second brain." font:[self is:39 italic:YES] color:amber];
    title2.frame = NSMakeRect(leftX, 318, leftW, 46);
    [root addSubview:title2];

    NSTextField *sub = [self settingsLabel:@"Add your Supermemory key to sync captures. Everything else stays on your Mac."
                                      font:[self sg:13.5 weight:NSFontWeightRegular]
                                     color:muted];
    sub.maximumNumberOfLines = 3;
    sub.frame = NSMakeRect(leftX, 258, leftW - 10, 52);
    [root addSubview:sub];

    [root addSubview:[self onboardRow:@"Capture from anywhere"
                                symbol:@"scope"
                             highlight:NO
                                 frame:NSMakeRect(leftX, 178, leftW, 46)]];
    [root addSubview:[self onboardRow:@"Saved locally first"
                                symbol:@"lock"
                             highlight:NO
                                 frame:NSMakeRect(leftX, 120, leftW, 46)]];
    [root addSubview:[self onboardRow:@"Synced when ready"
                                symbol:@"arrow.triangle.2.circlepath"
                             highlight:NO
                                 frame:NSMakeRect(leftX, 62, leftW, 46)]];

    NSView *panel = [[NSView alloc] initWithFrame:NSMakeRect(panelX, panelY, panelW, panelH)];
    panel.wantsLayer = YES;
    panel.layer.backgroundColor = CBColor(18, 18, 22, 1.0).CGColor;
    panel.layer.cornerRadius = 16;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = CBColor(255, 255, 255, 0.10).CGColor;
    [root addSubview:panel];

    CGFloat px = 26;
    CGFloat pw = panelW - (px * 2);

    // Setup panel.
    NSTextField *sec = [self eyebrow:@"Setup"];
    sec.frame = NSMakeRect(px, panelH - 48, pw, 13);
    [panel addSubview:sec];
    [panel addSubview:[self divider:NSMakeRect(px, panelH - 70, pw, 1)]];

    NSTextField *panelTitle = [self settingsLabel:@"Connect Supermemory"
                                            font:[self sg:21 weight:NSFontWeightSemibold]
                                           color:white];
    panelTitle.maximumNumberOfLines = 1;
    panelTitle.frame = NSMakeRect(px, panelH - 112, pw, 28);
    [panel addSubview:panelTitle];

    NSTextField *panelSub = [self settingsLabel:@"Paste your key and choose a tag for synced captures."
                                          font:[self sg:12.5 weight:NSFontWeightRegular]
                                         color:muted];
    panelSub.maximumNumberOfLines = 2;
    panelSub.frame = NSMakeRect(px, panelH - 146, pw, 32);
    [panel addSubview:panelSub];

    // API key.
    NSTextField *akLabel = [self settingsLabel:@"Supermemory API key"
                                          font:[self sg:13 weight:NSFontWeightSemibold]
                                         color:labelCol];
    akLabel.frame = NSMakeRect(px, 267, pw, 18);
    [panel addSubview:akLabel];

    self.onboardKeyField = [[NSSecureTextField alloc] init];
    self.onboardKeyField.placeholderString = @"sm_…";
    [panel addSubview:[self flatFieldBox:self.onboardKeyField frame:NSMakeRect(px, 218, pw, 44)]];

    // Container tag.
    NSTextField *ctLabel = [self settingsLabel:@"Container tag"
                                          font:[self sg:13 weight:NSFontWeightSemibold]
                                         color:labelCol];
    ctLabel.frame = NSMakeRect(px, 171, pw, 18);
    [panel addSubview:ctLabel];

    self.onboardContainerField = [[NSTextField alloc] init];
    self.onboardContainerField.placeholderString = @"my-second-brain";
    [panel addSubview:[self flatFieldBox:self.onboardContainerField frame:NSMakeRect(px, 122, pw, 44)]];

    // Primary action — white, like the site's hero button.
    NSButton *start = [self filledButton:@"Start capturing  →" action:@selector(finishOnboarding:)
                                      bg:CBColor(250, 250, 250, 1.0) fg:CBColor(10, 10, 10, 1.0)];
    start.frame = NSMakeRect(px, 54, pw, 48);
    start.keyEquivalent = @"\r";
    [panel addSubview:start];

    NSButton *getKey = [self linkButton:@"Get a free key at supermemory.ai  ↗"
                                 action:@selector(openSupermemorySite:)
                                  color:muted];
    getKey.frame = NSMakeRect(px, 24, pw, 18);
    [panel addSubview:getKey];
}

- (void)openSupermemorySite:(id)sender {
    (void)sender;
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://supermemory.ai"]];
}

- (void)finishOnboarding:(id)sender {
    (void)sender;
    NSString *k = [self.onboardKeyField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (k.length) CBSetApiKey(k);
    NSString *tag = [self.onboardContainerField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (tag.length) { CBSetContainerTag(tag); [self applyContainerTagToBrainFile]; }
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kOnboardedDefaultsKey];
    [self.onboardingWindow close];
    [self notify:@"Ready — press your shortcut"];
}

- (void)skipOnboarding:(id)sender {
    (void)sender;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kOnboardedDefaultsKey];
    [self.onboardingWindow close];
}

// Keep the existing document's frontmatter in sync with the chosen tag.
- (void)applyContainerTagToBrainFile {
    NSString *path = [self brainFilePath];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content.length) return;

    NSMutableArray<NSString *> *lines = [[content componentsSeparatedByString:@"\n"] mutableCopy];
    BOOL inFrontmatter = NO, replaced = NO;
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *t = CBTrimWhitespace(lines[i]);
        if (i == 0 && [t isEqualToString:@"---"]) { inFrontmatter = YES; continue; }
        if (inFrontmatter && [t isEqualToString:@"---"]) break;
        if (inFrontmatter && [t hasPrefix:@"containerTag:"]) {
            lines[i] = [NSString stringWithFormat:@"containerTag: \"%@\"", CBContainerTag()];
            replaced = YES;
            break;
        }
    }
    if (!replaced) return;

    NSData *data = [[lines componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fh) {
        @try { [fh truncateFileAtOffset:0]; [fh writeData:data]; } @finally { [fh closeFile]; }
    } else {
        [data writeToFile:path atomically:YES];
    }
}

- (void)revealCapturesFolder:(id)sender {
    (void)sender;
    [self ensureCaptureDir];
    [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:[self captureDirPath] isDirectory:YES]];
}

- (void)notify:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusItem.button.toolTip = msg;
        if (self.usesLogoImage) self.statusItem.button.imagePosition = NSImageLeft;
        self.statusItem.button.title = @" Saving";
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (self.usesLogoImage) {
                self.statusItem.button.title = @"";
                self.statusItem.button.imagePosition = NSImageOnly;
            } else {
                self.statusItem.button.title = @"Ctrl+Brain";
            }
        });
    });
}

@end
