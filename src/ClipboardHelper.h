#import <Cocoa/Cocoa.h>

@interface ClipboardHelper : NSObject

- (nullable NSString *)readHTML;
- (nullable NSString *)readPlainText;
/// Writes the given string to the pasteboard as plain text.
/// Snapshots the existing pasteboard contents before clearing (required by NSPasteboard)
/// and restores them if the write fails, so the original clipboard is not lost.
/// Returns YES on success.
- (BOOL)replaceClipboardWithMarkdown:(nonnull NSString *)markdown;

@end
