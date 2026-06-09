#import <Foundation/Foundation.h>

@interface MarkdownConverter : NSObject

- (nullable instancetype)init;
- (nullable instancetype)initWithJSBundlePath:(nonnull NSString *)path;
/// Designated initializer. `seconds` is the JSC execution watchdog limit —
/// configurable so tests can exercise watchdog behavior without waiting the
/// full production limit.
- (nullable instancetype)initWithJSBundlePath:(nonnull NSString *)path
                           executionTimeLimit:(double)seconds;
- (nullable NSString *)convertHTMLToMarkdown:(nullable NSString *)html;

@end
