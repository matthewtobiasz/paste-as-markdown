#import <Cocoa/Cocoa.h>
#import "MarkdownConverter.h"
#import "ClipboardHelper.h"

static int testsPassed = 0;
static int testsFailed = 0;

#define ASSERT_EQUAL(actual, expected, msg) do { \
    NSString *_a = (actual); \
    NSString *_e = (expected); \
    if ([_a isEqualToString:_e]) { \
        testsPassed++; \
    } else { \
        testsFailed++; \
        NSLog(@"FAIL: %s - expected: [%@] got: [%@]", msg, _e, _a); \
    } \
} while (0)

#define ASSERT_NIL(actual, msg) do { \
    if ((actual) == nil) { \
        testsPassed++; \
    } else { \
        testsFailed++; \
        NSLog(@"FAIL: %s - expected nil, got: [%@]", msg, (actual)); \
    } \
} while (0)

#define ASSERT_NOT_NIL(actual, msg) do { \
    if ((actual) != nil) { \
        testsPassed++; \
    } else { \
        testsFailed++; \
        NSLog(@"FAIL: %s - expected non-nil", msg); \
    } \
} while (0)

#define ASSERT_CONTAINS(haystack, needle, msg) do { \
    NSString *_h = (haystack); \
    NSString *_n = (needle); \
    if (_h && [_h containsString:_n]) { \
        testsPassed++; \
    } else { \
        testsFailed++; \
        NSLog(@"FAIL: %s - [%@] does not contain [%@]", msg, _h, _n); \
    } \
} while (0)

#define ASSERT_NOT_CONTAINS(haystack, needle, msg) do { \
    NSString *_h = (haystack); \
    NSString *_n = (needle); \
    if (!_h || ![_h containsString:_n]) { \
        testsPassed++; \
    } else { \
        testsFailed++; \
        NSLog(@"FAIL: %s - [%@] should not contain [%@]", msg, _h, _n); \
    } \
} while (0)

#pragma mark - MarkdownConverter Tests

static void testBasicConversions(MarkdownConverter *converter) {
    // Headings (atx style)
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<h1>Title</h1>"], @"# Title", "h1 heading");
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<h2>Subtitle</h2>"], @"## Subtitle", "h2 heading");
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<h3>Section</h3>"], @"### Section", "h3 heading");

    // Paragraph
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<p>Hello world</p>"], @"Hello world", "paragraph");

    // Bold
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<strong>bold text</strong>"], @"**bold text**", "bold");

    // Italic
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<em>italic text</em>"], @"*italic text*", "italic");

    // Link
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<a href=\"https://example.com\">click</a>"],
                 @"[click](https://example.com)", "link");

    // Inline code
    ASSERT_EQUAL([converter convertHTMLToMarkdown:@"<code>var x = 1;</code>"], @"`var x = 1;`", "inline code");
}

static void testLists(MarkdownConverter *converter) {
    NSString *ul = [converter convertHTMLToMarkdown:@"<ul><li>one</li><li>two</li><li>three</li></ul>"];
    ASSERT_CONTAINS(ul, @"-   one", "ul item 1");
    ASSERT_CONTAINS(ul, @"-   two", "ul item 2");
    ASSERT_CONTAINS(ul, @"-   three", "ul item 3");

    NSString *ol = [converter convertHTMLToMarkdown:@"<ol><li>first</li><li>second</li></ol>"];
    ASSERT_CONTAINS(ol, @"1.", "ol numbering");
    ASSERT_CONTAINS(ol, @"first", "ol item 1");
    ASSERT_CONTAINS(ol, @"second", "ol item 2");
}

static void testCodeBlock(MarkdownConverter *converter) {
    NSString *pre = [converter convertHTMLToMarkdown:@"<pre><code>function hello() {\n  return 1;\n}</code></pre>"];
    ASSERT_CONTAINS(pre, @"```", "fenced code block");
    ASSERT_CONTAINS(pre, @"function hello()", "code block content");
}

static void testNestedHTML(MarkdownConverter *converter) {
    NSString *html = @"<h1>Title</h1>"
                     @"<p>A paragraph with <strong>bold</strong> and <a href=\"https://x.com\">a link</a>.</p>"
                     @"<ul><li>item one</li><li>item two</li></ul>";
    NSString *result = [converter convertHTMLToMarkdown:html];
    ASSERT_CONTAINS(result, @"# Title", "nested: heading");
    ASSERT_CONTAINS(result, @"**bold**", "nested: bold");
    ASSERT_CONTAINS(result, @"[a link](https://x.com)", "nested: link");
    ASSERT_CONTAINS(result, @"-   item one", "nested: list item");
}

static void testEmptyInput(MarkdownConverter *converter) {
    ASSERT_NIL([converter convertHTMLToMarkdown:@""], "empty string returns nil");
    ASSERT_NIL([converter convertHTMLToMarkdown:nil], "nil returns nil");
}

static void testMalformedHTML(MarkdownConverter *converter) {
    NSString *result = [converter convertHTMLToMarkdown:@"<p>unclosed <b>bold <i>italic</p>"];
    ASSERT_NOT_NIL(result, "malformed HTML does not crash");
}

static void testHorizontalRule(MarkdownConverter *converter) {
    NSString *result = [converter convertHTMLToMarkdown:@"<p>above</p><hr><p>below</p>"];
    ASSERT_CONTAINS(result, @"---", "horizontal rule");
    ASSERT_CONTAINS(result, @"above", "hr: text above");
    ASSERT_CONTAINS(result, @"below", "hr: text below");
}

static void testBlockquote(MarkdownConverter *converter) {
    NSString *result = [converter convertHTMLToMarkdown:@"<blockquote><p>quoted text</p></blockquote>"];
    ASSERT_CONTAINS(result, @"> quoted text", "blockquote");
}

static void testImage(MarkdownConverter *converter) {
    NSString *result = [converter convertHTMLToMarkdown:@"<img src=\"pic.png\" alt=\"photo\">"];
    ASSERT_CONTAINS(result, @"![photo](pic.png)", "image");
}

#pragma mark - Our Configuration Tests

static void testScriptStyleStripping(MarkdownConverter *converter) {
    // We configured remove(['script', 'style', 'noscript']) — verify it works
    NSString *script = [converter convertHTMLToMarkdown:
        @"<p>before</p><script>alert('xss')</script><p>after</p>"];
    ASSERT_CONTAINS(script, @"before", "script: keeps text before");
    ASSERT_CONTAINS(script, @"after", "script: keeps text after");
    ASSERT_NOT_CONTAINS(script, @"alert", "script: strips script content");

    NSString *style = [converter convertHTMLToMarkdown:
        @"<style>.red { color: red; }</style><p>styled</p>"];
    ASSERT_EQUAL(style, @"styled", "style: strips style tag entirely");

    NSString *noscript = [converter convertHTMLToMarkdown:
        @"<p>content</p><noscript>Enable JS</noscript>"];
    ASSERT_NOT_CONTAINS(noscript, @"Enable JS", "noscript: strips noscript content");
}

static void testGFMTablePlugin(MarkdownConverter *converter) {
    // We wired up turndownGfmPlugin — verify tables render as GFM markdown
    NSString *result = [converter convertHTMLToMarkdown:
        @"<table><thead><tr><th>Name</th><th>Age</th></tr></thead>"
         "<tbody><tr><td>Alice</td><td>30</td></tr></tbody></table>"];
    ASSERT_CONTAINS(result, @"| Name | Age |", "gfm table: header row");
    ASSERT_CONTAINS(result, @"| --- | --- |", "gfm table: separator row");
    ASSERT_CONTAINS(result, @"| Alice | 30 |", "gfm table: data row");
}

#pragma mark - JSContext Stability Tests

static void testRepeatedConversions(MarkdownConverter *converter) {
    // Verify the cached JSContext and function reference stay stable
    for (int i = 0; i < 50; i++) {
        NSString *html = [NSString stringWithFormat:@"<p>iteration %d</p>", i];
        NSString *expected = [NSString stringWithFormat:@"iteration %d", i];
        NSString *result = [converter convertHTMLToMarkdown:html];
        if (![result isEqualToString:expected]) {
            testsFailed++;
            NSLog(@"FAIL: repeated conversion failed at iteration %d - expected [%@] got [%@]",
                  i, expected, result);
            return;
        }
    }
    testsPassed++;
}

#pragma mark - ClipboardHelper Edge Case Tests

static void testClipboardHTMLPreferredOverPlainText(void) {
    // When clipboard has both HTML and plain text, readHTML should return the HTML
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    // Write both types — apps like browsers typically put both on the clipboard
    [pb setString:@"<p>rich</p>" forType:NSPasteboardTypeHTML];
    [pb setString:@"plain fallback" forType:NSPasteboardTypeString];

    NSString *html = [helper readHTML];
    ASSERT_EQUAL(html, @"<p>rich</p>", "clipboard prefers HTML over plain text");
}

static void testClipboardRTFFallback(void) {
    // When clipboard has RTF but no HTML, readHTML should convert RTF to HTML
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    // Create RTF data for "Hello" in bold
    NSAttributedString *attr = [[NSAttributedString alloc]
        initWithString:@"Hello"
            attributes:@{NSFontAttributeName:
                [NSFont boldSystemFontOfSize:12.0]}];
    NSData *rtfData = [attr RTFFromRange:NSMakeRange(0, attr.length)
                      documentAttributes:@{}];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setData:rtfData forType:NSPasteboardTypeRTF];

    NSString *html = [helper readHTML];
    ASSERT_NOT_NIL(html, "RTF fallback: returns non-nil HTML");
    ASSERT_CONTAINS(html, @"Hello", "RTF fallback: contains text content");
}

static void testClipboardFullRoundTrip(MarkdownConverter *converter) {
    // Integration test: put HTML on clipboard → read → convert → write → verify markdown
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:@"<h1>Title</h1><p>A <strong>bold</strong> paragraph.</p>"
          forType:NSPasteboardTypeHTML];

    NSString *html = [helper readHTML];
    ASSERT_NOT_NIL(html, "round trip: read HTML");

    NSString *markdown = [converter convertHTMLToMarkdown:html];
    ASSERT_NOT_NIL(markdown, "round trip: conversion succeeded");

    [helper writeMarkdown:markdown];

    NSString *result = [pb stringForType:NSPasteboardTypeString];
    ASSERT_CONTAINS(result, @"# Title", "round trip: has heading");
    ASSERT_CONTAINS(result, @"**bold**", "round trip: has bold");
}

#pragma mark - ClipboardHelper Tests

static void testClipboardWriteRead(void) {
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];
    [helper writeMarkdown:@"# Hello\n\nWorld"];
    NSString *text = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    ASSERT_EQUAL(text, @"# Hello\n\nWorld", "clipboard write/read plain text");
}

static void testClipboardHTMLRead(void) {
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:@"<h1>Test</h1>" forType:NSPasteboardTypeHTML];

    NSString *html = [helper readHTML];
    ASSERT_EQUAL(html, @"<h1>Test</h1>", "clipboard read HTML");
}

static void testClipboardEmptyRead(void) {
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:@"plain text only" forType:NSPasteboardTypeString];

    NSString *html = [helper readHTML];
    ASSERT_NIL(html, "clipboard returns nil when no HTML/RTF");
}

#pragma mark - Main

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];

        NSLog(@"=== Paste as Markdown Tests ===");

        // Find the JS bundle relative to the test binary
        NSString *execPath = [[NSProcessInfo processInfo] arguments][0];
        NSString *execDir = [execPath stringByDeletingLastPathComponent];
        NSString *jsPath = [execDir stringByAppendingPathComponent:@"turndown-bundle.js"];

        if (![[NSFileManager defaultManager] fileExistsAtPath:jsPath]) {
            NSLog(@"FATAL: turndown-bundle.js not found at %@", jsPath);
            return 1;
        }

        MarkdownConverter *converter = [[MarkdownConverter alloc] initWithJSBundlePath:jsPath];
        if (!converter) {
            NSLog(@"FATAL: Failed to initialize MarkdownConverter");
            return 1;
        }

        NSLog(@"--- MarkdownConverter Tests ---");
        testBasicConversions(converter);
        testLists(converter);
        testCodeBlock(converter);
        testNestedHTML(converter);
        testEmptyInput(converter);
        testMalformedHTML(converter);
        testHorizontalRule(converter);
        testBlockquote(converter);
        testImage(converter);

        NSLog(@"--- Our Configuration Tests ---");
        testScriptStyleStripping(converter);
        testGFMTablePlugin(converter);

        NSLog(@"--- JSContext Stability Tests ---");
        testRepeatedConversions(converter);

        NSLog(@"--- ClipboardHelper Tests ---");
        testClipboardWriteRead();
        testClipboardHTMLRead();
        testClipboardEmptyRead();

        NSLog(@"--- ClipboardHelper Edge Case Tests ---");
        testClipboardHTMLPreferredOverPlainText();
        testClipboardRTFFallback();
        testClipboardFullRoundTrip(converter);

        NSLog(@"=== Results: %d passed, %d failed ===", testsPassed, testsFailed);

        return testsFailed > 0 ? 1 : 0;
    }
}
