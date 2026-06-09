#import <Cocoa/Cocoa.h>

@interface ClipboardHelper : NSObject

/// Uses the general pasteboard.
- (nonnull instancetype)init;
/// Uses the given pasteboard — lets tests run against a private pasteboard
/// (e.g. +[NSPasteboard pasteboardWithUniqueName]) instead of clobbering the
/// user's real clipboard.
- (nonnull instancetype)initWithPasteboard:(nonnull NSPasteboard *)pasteboard NS_DESIGNATED_INITIALIZER;

- (nullable NSString *)readHTML;
- (nullable NSString *)readPlainText;
/// Writes the given string to the pasteboard as plain text.
/// Snapshots the text-bearing flavors (plain text, HTML, RTF) before clearing
/// (required by NSPasteboard) and restores them if the write fails, so the
/// convertible content is not lost. Returns YES on success.
- (BOOL)replaceClipboardWithMarkdown:(nonnull NSString *)markdown;

@end
