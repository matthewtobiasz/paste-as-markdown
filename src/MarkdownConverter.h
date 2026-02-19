#import <Foundation/Foundation.h>

@interface MarkdownConverter : NSObject

- (nullable instancetype)init;
- (nullable instancetype)initWithJSBundlePath:(nonnull NSString *)path;
- (nullable NSString *)convertHTMLToMarkdown:(nullable NSString *)html;

@end
