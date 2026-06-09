#import "MarkdownConverter.h"
#import <JavaScriptCore/JavaScriptCore.h>

// JSContextGroupSetExecutionTimeLimit is declared in JavaScriptCore's
// JSContextRefPrivate.h, which is not shipped in the public SDK headers, but
// the symbol is exported from the system framework and has been stable for
// over a decade (it's what Safari-adjacent tooling uses for script watchdogs).
// We declare the prototype ourselves. This is the only way to actually
// interrupt runaway JS in JSC — a dispatch timeout can only abandon the
// result while the script keeps burning the serial queue forever.
// Note: private API — fine for direct distribution, not App Store.
typedef bool (*JSShouldTerminateCallback)(JSContextRef ctx, void *context);
extern void JSContextGroupSetExecutionTimeLimit(JSContextGroupRef group,
                                                double limit,
                                                JSShouldTerminateCallback callback,
                                                void *context);

static const double kJSExecutionTimeLimitSeconds = 10.0;

// Reject anything absurdly large before we do any work at all (even the
// data-URI stripping regex costs something on a string this big).
static const NSUInteger kMaxRawInputBytes = 50 * 1024 * 1024;

// Cap applied after data URIs are stripped. 5 MB covers any realistic
// rich-text copy once inline images are removed.
static const NSUInteger kMaxStrippedInputBytes = 5 * 1024 * 1024;

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

    // Install JSC's execution watchdog. If a conversion runs past the limit
    // (e.g. catastrophic regex backtracking inside turndown on pathological
    // input), JSC interrupts it and raises a termination exception. The call
    // on _jsQueue then returns normally, so the queue never wedges and the
    // context stays usable for subsequent conversions. A NULL callback means
    // "terminate unconditionally when the limit is hit". The limit applies
    // per entry into JS, not cumulatively.
    JSContextGroupRef group = JSContextGetGroup([_context JSGlobalContextRef]);
    JSContextGroupSetExecutionTimeLimit(group, kJSExecutionTimeLimitSeconds, NULL, NULL);

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

// Strip base64 data URIs from img src attributes — they can be several MB
// each and would produce unreadable markdown output. Handles double-quoted,
// single-quoted, and unquoted src values. Replaces with an empty src.
- (NSString *)stripDataURIs:(NSString *)html {
    static NSRegularExpression *dataURIRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dataURIRegex = [NSRegularExpression
            regularExpressionWithPattern:@"src\\s*=\\s*(\"data:[^\"]*\"|'data:[^']*'|data:[^\\s>]*)"
                                 options:NSRegularExpressionCaseInsensitive
                                   error:nil];
    });

    NSUInteger stripped = [dataURIRegex numberOfMatchesInString:html
                                                        options:0
                                                          range:NSMakeRange(0, html.length)];
    if (stripped == 0) {
        return html;
    }
    NSLog(@"[Paste as Markdown] Stripping %lu base64 data URI(s) from img tags", (unsigned long)stripped);
    return [dataURIRegex stringByReplacingMatchesInString:html
                                                  options:0
                                                    range:NSMakeRange(0, html.length)
                                             withTemplate:@"src=\"\""];
}

- (nullable NSString *)convertHTMLToMarkdown:(NSString *)html {
    if (!html || html.length == 0) return nil;

    NSUInteger rawBytes = [html lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (rawBytes > kMaxRawInputBytes) {
        NSLog(@"[Paste as Markdown] Input too large (%lu bytes), skipping conversion",
              (unsigned long)rawBytes);
        return nil;
    }

    // Strip inline base64 images BEFORE applying the size cap. Embedded
    // images are the single most common reason a rich-text clipboard blows
    // past the cap; a page with one 6 MB screenshot and two paragraphs of
    // text should convert fine once the image payload is gone.
    html = [self stripDataURIs:html];

    NSUInteger strippedBytes = [html lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (strippedBytes > kMaxStrippedInputBytes) {
        NSLog(@"[Paste as Markdown] Input still too large after stripping images (%lu bytes), skipping conversion",
              (unsigned long)strippedBytes);
        return nil;
    }

    // Run the conversion on the dedicated serial queue — JSContext is not
    // thread-safe. Runaway scripts are bounded by the JSC execution time
    // limit installed at init, so this call always returns; no semaphore
    // timeout is needed (a dispatch-level timeout couldn't stop the script
    // anyway, it would just abandon a permanently wedged queue).
    __block JSValue *result = nil;
    dispatch_sync(_jsQueue, ^{
        result = [self->_convertFunction callWithArguments:@[html]];
    });

    if (_context.exception) {
        // Do not log the exception message — it may contain clipboard content.
        NSLog(@"[Paste as Markdown] Conversion failed with a JS exception (possibly the %.0fs watchdog)",
              kJSExecutionTimeLimitSeconds);
        _context.exception = nil;
        return nil;
    }

    if (!result || [result isUndefined] || [result isNull]) {
        return nil;
    }

    return [result toString];
}

@end
