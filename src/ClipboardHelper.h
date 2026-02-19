#import <Cocoa/Cocoa.h>

@interface ClipboardHelper : NSObject

- (nullable NSString *)readHTML;
- (nullable NSString *)readPlainText;
/// Atomically clears the pasteboard and writes the given string.
/// Returns YES on success. The pasteboard is only cleared if the write succeeds.
- (BOOL)replaceClipboardWithMarkdown:(nonnull NSString *)markdown;

@end
