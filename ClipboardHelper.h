#import <Cocoa/Cocoa.h>

@interface ClipboardHelper : NSObject

- (nullable NSString *)readHTML;
- (void)writeMarkdown:(nonnull NSString *)markdown;

@end
