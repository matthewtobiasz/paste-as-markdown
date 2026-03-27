#import "MarkdownConverter.h"
#import <JavaScriptCore/JavaScriptCore.h>

@implementation MarkdownConverter {
    JSContext *_context;
    JSValue *_convertFunction;
    dispatch_queue_t _jsQueue;
}

- (nullable instancetype)init {
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"turndown-bundle" ofType:@"js"];
    if (!jsPath) {
        NSLog(@"[Paste as Markdown] turndown-bundle.js not found in app resources");
        return nil;
    }
    return [self initWithJSBundlePath:jsPath];
}

- (nullable instancetype)initWithJSBundlePath:(NSString *)path {
    self = [super init];
    if (!self) return nil;

    _jsQueue = dispatch_queue_create("com.pasteAsMarkdown.jsContext", DISPATCH_QUEUE_SERIAL);
    _context = [[JSContext alloc] init];
    _context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
        // Log the exception type only — not the message or stack, which may
        // contain clipboard content passed as input to the converter.
        NSString *exceptionType = [exception[@"name"] toString] ?: @"unknown";
        NSLog(@"[Paste as Markdown] JS exception (%@) during conversion", exceptionType);
    };

    NSError *error = nil;
    NSString *jsCode = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    if (!jsCode) {
        NSLog(@"[Paste as Markdown] Failed to read turndown-bundle.js: %@", error);
        return nil;
    }

    [_context evaluateScript:jsCode withSourceURL:[NSURL fileURLWithPath:path]];
    if (_context.exception) {
        // Safe to log the bundle evaluation error — it's from our own resource, not clipboard input.
        NSLog(@"[Paste as Markdown] Failed to evaluate turndown bundle: %@", _context.exception);
        _context.exception = nil;
        return nil;
    }

    // The bundle exports a global convert(html) function
    _convertFunction = _context[@"convert"];
    if (!_convertFunction || [_convertFunction isUndefined]) {
        NSLog(@"[Paste as Markdown] Failed to find convert function in bundle");
        return nil;
    }

    return self;
}

- (nullable NSString *)convertHTMLToMarkdown:(NSString *)html {
    if (!html || html.length == 0) return nil;

    // Guard against extremely large clipboard content that could exhaust memory
    // or cause the JS engine to hang. 5 MB covers any realistic rich-text copy.
    const NSUInteger kMaxInputBytes = 5 * 1024 * 1024;
    if ([html lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > kMaxInputBytes) {
        NSLog(@"[Paste as Markdown] Input too large (%lu bytes), skipping conversion",
              (unsigned long)[html lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        return nil;
    }

    // Strip base64 data URIs from img src attributes — they can be several MB each
    // and would produce unreadable markdown output. Replace with empty src.
    NSRegularExpression *dataURIRegex =
        [NSRegularExpression regularExpressionWithPattern:@"src=[\"']data:[^\"']*[\"']"
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSUInteger stripped = [dataURIRegex numberOfMatchesInString:html
                                                        options:0
                                                          range:NSMakeRange(0, html.length)];
    if (stripped > 0) {
        html = [dataURIRegex stringByReplacingMatchesInString:html
                                                      options:0
                                                        range:NSMakeRange(0, html.length)
                                                 withTemplate:@"src=\"\""];
        NSLog(@"[Paste as Markdown] Stripped %lu base64 data URI(s) from img tags", (unsigned long)stripped);
    }

    // Run the conversion on the dedicated JS serial queue so we can enforce a
    // timeout while keeping JSContext access single-threaded (it is not thread-safe).
    __block JSValue *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    dispatch_async(_jsQueue, ^{
        result = [self->_convertFunction callWithArguments:@[html]];
        dispatch_semaphore_signal(sem);
    });

    const int64_t kTimeoutSeconds = 10;
    if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, kTimeoutSeconds * NSEC_PER_SEC)) != 0) {
        NSLog(@"[Paste as Markdown] Conversion timed out after %llds", kTimeoutSeconds);
        return nil;
    }

    if (_context.exception) {
        // Do not log the exception message — it may contain clipboard content.
        NSLog(@"[Paste as Markdown] Conversion failed with a JS exception");
        _context.exception = nil;
        return nil;
    }

    if ([result isUndefined] || [result isNull]) {
        return nil;
    }

    return [result toString];
}

@end
