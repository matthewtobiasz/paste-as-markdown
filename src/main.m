#import <Cocoa/Cocoa.h>
#import "MarkdownConverter.h"
#import "ClipboardHelper.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    NSImage *_defaultIcon;
    MarkdownConverter *_converter;
    ClipboardHelper *_clipboardHelper;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _converter = [[MarkdownConverter alloc] init];
    if (!_converter) {
        NSLog(@"[Paste as Markdown] Failed to initialize MarkdownConverter");
    }
    _clipboardHelper = [[ClipboardHelper alloc] init];

    // Create menu bar item
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    _defaultIcon = [NSImage imageWithSystemSymbolName:@"doc.on.clipboard"
                             accessibilityDescription:@"Paste as Markdown"];
    [_defaultIcon setTemplate:YES];
    _statusItem.button.image = _defaultIcon;

    // Build menu
    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *convertItem = [[NSMenuItem alloc] initWithTitle:@"Convert Clipboard to Markdown"
                                                        action:@selector(convertClipboard:)
                                                 keyEquivalent:@""];
    [convertItem setTarget:self];
    [menu addItem:convertItem];

    [menu addItem:[NSMenuItem separatorItem]];

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

    _statusItem.menu = menu;
}

- (void)convertClipboard:(id)sender {
    if (!_converter) {
        [self flashStatusIcon:@"exclamationmark.triangle"];
        return;
    }

    NSString *html = [_clipboardHelper readHTML];
    if (!html) {
        // No HTML/RTF — pass plain text through unchanged
        NSString *plain = [_clipboardHelper readPlainText];
        if (!plain) {
            [self flashStatusIcon:@"exclamationmark.triangle"];
            return;
        }
        BOOL ok = [_clipboardHelper replaceClipboardWithMarkdown:plain];
        [self flashStatusIcon:ok ? @"minus" : @"xmark"];
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
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;

        [app run];
    }
    return 0;
}
