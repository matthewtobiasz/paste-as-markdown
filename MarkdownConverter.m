#import "MarkdownConverter.h"
#import <JavaScriptCore/JavaScriptCore.h>

@implementation MarkdownConverter {
    JSContext *_context;
    JSValue *_convertFunction;
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

    _context = [[JSContext alloc] init];
    _context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
        NSLog(@"[Paste as Markdown] JS Error: %@", exception);
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
        NSLog(@"[Paste as Markdown] Failed to evaluate turndown bundle: %@", _context.exception);
        _context.exception = nil;
        return nil;
    }

    // Create a configured TurndownService instance
    NSString *setupScript =
        @"var __turndownService = new TurndownService({"
         "  headingStyle: 'atx',"
         "  hr: '---',"
         "  bulletListMarker: '-',"
         "  codeBlockStyle: 'fenced',"
         "  fence: '```',"
         "  emDelimiter: '*',"
         "  strongDelimiter: '**',"
         "  linkStyle: 'inlined'"
         "});";
    [_context evaluateScript:setupScript];
    if (_context.exception) {
        NSLog(@"[Paste as Markdown] Failed to create TurndownService: %@", _context.exception);
        _context.exception = nil;
        return nil;
    }

    // Cache a function reference for efficient repeated calls
    _convertFunction = [_context evaluateScript:
        @"(function(html) { return __turndownService.turndown(html); })"];
    if (!_convertFunction || [_convertFunction isUndefined]) {
        NSLog(@"[Paste as Markdown] Failed to create convert function");
        return nil;
    }

    return self;
}

- (nullable NSString *)convertHTMLToMarkdown:(NSString *)html {
    if (!html || html.length == 0) return nil;

    JSValue *result = [_convertFunction callWithArguments:@[html]];

    if (_context.exception) {
        NSLog(@"[Paste as Markdown] Conversion error: %@", _context.exception);
        _context.exception = nil;
        return nil;
    }

    if ([result isUndefined] || [result isNull]) {
        return nil;
    }

    return [result toString];
}

@end
