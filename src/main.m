#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>
#import "MarkdownConverter.h"
#import "ClipboardHelper.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    NSImage *_defaultIcon;
    MarkdownConverter *_converter;
    ClipboardHelper *_clipboardHelper;
    NSMenuItem *_launchAtLoginItem;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"[Paste as Markdown] applicationDidFinishLaunching called");

    _converter = [[MarkdownConverter alloc] init];
    if (!_converter) {
        NSLog(@"[Paste as Markdown] Failed to initialize MarkdownConverter — clipboard conversion will not work");
    } else {
        NSLog(@"[Paste as Markdown] MarkdownConverter initialized successfully");
    }
    _clipboardHelper = [[ClipboardHelper alloc] init];

    // Create menu bar item
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    // Load menu bar icon from bundle Resources (MenuBarIcon.png / @2x)
    NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"MenuBarIcon" ofType:@"png"];
    if (iconPath) {
        _defaultIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    if (!_defaultIcon) {
        // Fallback to SF Symbol if custom icon not found (e.g. in tests)
        _defaultIcon = [NSImage imageWithSystemSymbolName:@"number"
                                 accessibilityDescription:@"Paste as Markdown"];
    }
    [_defaultIcon setTemplate:YES];
    [_defaultIcon setSize:NSMakeSize(18, 18)];
    _statusItem.button.image = _defaultIcon;

    // Build menu
    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *convertItem = [[NSMenuItem alloc] initWithTitle:@"Convert Clipboard to Markdown"
                                                        action:@selector(convertClipboard:)
                                                 keyEquivalent:@""];
    [convertItem setTarget:self];
    [menu addItem:convertItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Launch at Login uses SMAppService, which requires macOS 13. On older
    // systems the item is simply absent (the app itself still supports 11+).
    if (@available(macOS 13.0, *)) {
        _launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login"
                                                        action:@selector(toggleLaunchAtLogin:)
                                                 keyEquivalent:@""];
        [_launchAtLoginItem setTarget:self];
        [menu addItem:_launchAtLoginItem];
        [menu addItem:[NSMenuItem separatorItem]];
    }

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About Paste as Markdown"
                                                      action:@selector(showAbout:)
                                               keyEquivalent:@""];
    [aboutItem setTarget:self];
    [menu addItem:aboutItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                     action:@selector(terminate:)
                                              keyEquivalent:@"q"];
    [menu addItem:quitItem];

    // Refresh the Launch at Login checkmark each time the menu opens — the
    // user can toggle login items behind our back in System Settings.
    menu.delegate = self;
    [self refreshLaunchAtLoginState];

    _statusItem.menu = menu;

    NSLog(@"[Paste as Markdown] Menu bar item created — app is running");
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    NSLog(@"[Paste as Markdown] App is shutting down");
}

- (void)convertClipboard:(id)sender {
    if (!_converter) {
        [self flashStatusIcon:@"exclamationmark.triangle"];
        return;
    }

    NSString *html = [_clipboardHelper readHTML];
    if (!html) {
        // No HTML/RTF on the clipboard. If plain text is present there's
        // nothing to convert — leave the pasteboard completely untouched.
        // Rewriting identical text would destroy every other flavor sitting
        // alongside it (images, file references, custom app data) for zero
        // benefit. Just signal "nothing to do" with the minus flash.
        if ([_clipboardHelper readPlainText]) {
            [self flashStatusIcon:@"minus"];
        } else {
            [self flashStatusIcon:@"exclamationmark.triangle"];
        }
        return;
    }

    NSString *markdown = [_converter convertHTMLToMarkdown:html];
    if (!markdown) {
        [self flashStatusIcon:@"xmark"];
        return;
    }
    // Clipboard is only cleared here, once we have a confirmed result
    BOOL ok = [_clipboardHelper replaceClipboardWithMarkdown:markdown];
    [self flashStatusIcon:ok ? @"checkmark" : @"xmark"];
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self refreshLaunchAtLoginState];
}

- (void)refreshLaunchAtLoginState {
    if (@available(macOS 13.0, *)) {
        if (!_launchAtLoginItem) return;
        _launchAtLoginItem.state =
            (SMAppService.mainAppService.status == SMAppServiceStatusEnabled)
                ? NSControlStateValueOn
                : NSControlStateValueOff;
    }
}

- (void)toggleLaunchAtLogin:(id)sender {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = SMAppService.mainAppService;
        NSError *error = nil;

        if (service.status == SMAppServiceStatusEnabled) {
            if (![service unregisterAndReturnError:&error]) {
                NSLog(@"[Paste as Markdown] Failed to disable launch at login: %@", error);
            }
        } else {
            if (![service registerAndReturnError:&error]) {
                NSLog(@"[Paste as Markdown] Failed to enable launch at login: %@", error);
            }
            // If the user previously denied this app in System Settings,
            // registration lands in "requires approval" — send them to the
            // Login Items pane so they can flip the switch.
            if (service.status == SMAppServiceStatusRequiresApproval) {
                [SMAppService openSystemSettingsLoginItems];
            }
        }
        [self refreshLaunchAtLoginState];
    }
}

- (void)showAbout:(id)sender {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!version) version = @"unknown";
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

    NSString *versionText;
    if (build && ![build isEqualToString:version]) {
        versionText = [NSString stringWithFormat:@"Version %@ (%@)", version, build];
    } else {
        versionText = [NSString stringWithFormat:@"Version %@", version];
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Paste as Markdown";
    alert.informativeText = versionText;
    alert.icon = [NSImage imageNamed:NSImageNameApplicationIcon];
    [alert addButtonWithTitle:@"Open GitHub"];
    [alert addButtonWithTitle:@"OK"];

    // Bring the app to the foreground so the alert is visible
    [NSApp activateIgnoringOtherApps:YES];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:
            [NSURL URLWithString:@"https://github.com/matthewtobiasz/paste-as-markdown"]];
    }
}

- (void)flashStatusIcon:(NSString *)symbolName {
    NSImage *flashImage = [NSImage imageWithSystemSymbolName:symbolName
                                   accessibilityDescription:nil];
    [flashImage setTemplate:YES];
    _statusItem.button.image = flashImage;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self->_statusItem.button.image = self->_defaultIcon;
    });
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSLog(@"[Paste as Markdown] App process started");

        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;

        [app run];
    }
    return 0;
}
