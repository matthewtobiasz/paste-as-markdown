#import <Cocoa/Cocoa.h>

@interface ClipboardHelper : NSObject

- (nullable NSString *)readHTML;
- (nullable NSString *)readPlainText;
- (void)writeMarkdown:(nonnull NSString *)markdown;

@end
