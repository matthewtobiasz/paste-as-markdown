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
    ASSERT_NOT_CONTAINS(result, @"<table", "gfm table: no HTML table tag");
    ASSERT_NOT_CONTAINS(result, @"<tr", "gfm table: no HTML tr tag");
    ASSERT_NOT_CONTAINS(result, @"<td", "gfm table: no HTML td tag");
    ASSERT_NOT_CONTAINS(result, @"<th", "gfm table: no HTML th tag");
}

static void testTableMultipleRows(MarkdownConverter *converter) {
    NSString *result = [converter convertHTMLToMarkdown:
        @"<table><thead><tr><th>Col1</th><th>Col2</th><th>Col3</th></tr></thead>"
         "<tbody>"
         "<tr><td>A</td><td>B</td><td>C</td></tr>"
         "<tr><td>D</td><td>E</td><td>F</td></tr>"
         "</tbody></table>"];
    ASSERT_CONTAINS(result, @"| Col1 | Col2 | Col3 |", "table multi-row: header row");
    ASSERT_CONTAINS(result, @"| --- | --- | --- |", "table multi-row: separator row");
    ASSERT_CONTAINS(result, @"| A | B | C |", "table multi-row: first data row");
    ASSERT_CONTAINS(result, @"| D | E | F |", "table multi-row: second data row");
    ASSERT_NOT_CONTAINS(result, @"<table", "table multi-row: no HTML table tag");
    ASSERT_NOT_CONTAINS(result, @"<td", "table multi-row: no HTML td tag");
}

static void testTableNoThead(MarkdownConverter *converter) {
    // Tables without explicit thead — GFM plugin should still produce markdown
    NSString *result = [converter convertHTMLToMarkdown:
        @"<table>"
         "<tr><th>Product</th><th>Price</th></tr>"
         "<tr><td>Apple</td><td>1.00</td></tr>"
         "</table>"];
    ASSERT_NOT_CONTAINS(result, @"<table", "table no-thead: no HTML table tag");
    ASSERT_NOT_CONTAINS(result, @"<td", "table no-thead: no HTML td tag");
    ASSERT_CONTAINS(result, @"|", "table no-thead: uses pipe delimiters");
}

static void testTableWithInlineFormatting(MarkdownConverter *converter) {
    // Cell content with bold/links should be converted, not left as HTML
    NSString *result = [converter convertHTMLToMarkdown:
        @"<table><thead><tr><th>Name</th><th>Note</th></tr></thead>"
         "<tbody><tr><td><strong>Bob</strong></td><td><em>important</em></td></tr></tbody></table>"];
    ASSERT_CONTAINS(result, @"| Name | Note |", "table inline: header row");
    ASSERT_CONTAINS(result, @"**Bob**", "table inline: bold converted");
    ASSERT_CONTAINS(result, @"*important*", "table inline: italic converted");
    ASSERT_NOT_CONTAINS(result, @"<strong>", "table inline: no HTML strong tag");
    ASSERT_NOT_CONTAINS(result, @"<em>", "table inline: no HTML em tag");
    ASSERT_NOT_CONTAINS(result, @"<td", "table inline: no HTML td tag");
}

static void testTableWithLink(MarkdownConverter *converter) {
    NSString *result = [converter convertHTMLToMarkdown:
        @"<table><thead><tr><th>Site</th><th>URL</th></tr></thead>"
         "<tbody><tr><td>Example</td><td><a href=\"https://example.com\">link</a></td></tr></tbody></table>"];
    ASSERT_CONTAINS(result, @"| Site | URL |", "table link: header row");
    ASSERT_CONTAINS(result, @"[link](https://example.com)", "table link: link converted");
    ASSERT_NOT_CONTAINS(result, @"<a href", "table link: no HTML anchor tag");
    ASSERT_NOT_CONTAINS(result, @"<td", "table link: no HTML td tag");
}

static void testTableEmptyCells(MarkdownConverter *converter) {
    NSString *result = [converter convertHTMLToMarkdown:
        @"<table><thead><tr><th>A</th><th>B</th></tr></thead>"
         "<tbody><tr><td></td><td>value</td></tr></tbody></table>"];
    ASSERT_CONTAINS(result, @"| A | B |", "table empty cell: header row");
    ASSERT_CONTAINS(result, @"|", "table empty cell: uses pipe delimiters");
    ASSERT_NOT_CONTAINS(result, @"<td", "table empty cell: no HTML td tag");
}

static void testImgDataURIStripped(MarkdownConverter *converter) {
    // Base64 data URIs should be stripped before conversion to avoid multi-MB markdown output.
    NSString *result = [converter convertHTMLToMarkdown:
        @"<p>Hello</p>"
         "<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA\" alt=\"screenshot\">"
         "<p>World</p>"];
    ASSERT_NOT_CONTAINS(result, @"data:image", "data URI: base64 blob stripped from output");
    ASSERT_CONTAINS(result, @"Hello", "data URI: surrounding text preserved");
    ASSERT_CONTAINS(result, @"World", "data URI: surrounding text preserved");
}

static void testConfluenceTableNoThead(MarkdownConverter *converter) {
    // Confluence copies tables with <td> everywhere — no <thead> or <th>.
    // The GFM plugin must still produce markdown, not pass through raw HTML.
    NSString *result = [converter convertHTMLToMarkdown:
        @"<div class=\"tableView-content-wrap\"><div class=\"pm-table-wrapper\">"
         "<table><tbody>"
         "<tr><td><p><strong>Lorem</strong></p></td><td><p><strong>Ipsum</strong></p></td><td><p><strong>Dolor</strong></p></td></tr>"
         "<tr><td><ol start=\"1\"><li><p><strong>Sit Amet</strong></p></li></ol></td>"
              "<td><p>Lorem ipsum dolor sit amet</p></td>"
              "<td><p><a href=\"https://example.com\"><strong>Consectetur Adipiscing</strong></a></p></td></tr>"
         "</tbody></table>"
         "</div></div>"];
    ASSERT_NOT_CONTAINS(result, @"<table", "confluence table: no HTML table tag");
    ASSERT_NOT_CONTAINS(result, @"<td",    "confluence table: no HTML td tag");
    ASSERT_NOT_CONTAINS(result, @"<tr",    "confluence table: no HTML tr tag");
    ASSERT_CONTAINS(result, @"|",          "confluence table: uses pipe delimiters");
    ASSERT_CONTAINS(result, @"Lorem",      "confluence table: header cell text present");
    ASSERT_CONTAINS(result, @"Sit Amet",   "confluence table: data cell text present");
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

    [helper replaceClipboardWithMarkdown:markdown];

    NSString *result = [pb stringForType:NSPasteboardTypeString];
    ASSERT_CONTAINS(result, @"# Title", "round trip: has heading");
    ASSERT_CONTAINS(result, @"**bold**", "round trip: has bold");
}

#pragma mark - ClipboardHelper Tests

static void testClipboardWriteRead(void) {
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];
    [helper replaceClipboardWithMarkdown:@"# Hello\n\nWorld"];
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

#pragma mark - Plain Text Fallback Tests

static void testReadPlainText(void) {
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:@"just some text" forType:NSPasteboardTypeString];

    NSString *text = [helper readPlainText];
    ASSERT_EQUAL(text, @"just some text", "readPlainText returns plain text");
}

static void testReadPlainTextReturnsNilWhenEmpty(void) {
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];

    NSString *text = [helper readPlainText];
    ASSERT_NIL(text, "readPlainText returns nil on empty clipboard");
}

static void testPlainTextPassthroughRoundTrip(void) {
    ClipboardHelper *helper = [[ClipboardHelper alloc] init];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:@"already markdown **bold**" forType:NSPasteboardTypeString];

    // readHTML should return nil (no HTML/RTF)
    NSString *html = [helper readHTML];
    ASSERT_NIL(html, "plain text passthrough: readHTML returns nil");

    // readPlainText should return the text
    NSString *plain = [helper readPlainText];
    ASSERT_NOT_NIL(plain, "plain text passthrough: readPlainText returns text");

    // Write it back and verify
    [helper replaceClipboardWithMarkdown:plain];
    NSString *result = [pb stringForType:NSPasteboardTypeString];
    ASSERT_EQUAL(result, @"already markdown **bold**", "plain text passthrough: text unchanged");
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
        testTableMultipleRows(converter);
        testTableNoThead(converter);
        testTableWithInlineFormatting(converter);
        testTableWithLink(converter);
        testTableEmptyCells(converter);
        testConfluenceTableNoThead(converter);
        testImgDataURIStripped(converter);

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

        NSLog(@"--- Plain Text Fallback Tests ---");
        testReadPlainText();
        testReadPlainTextReturnsNilWhenEmpty();
        testPlainTextPassthroughRoundTrip();

        NSLog(@"=== Results: %d passed, %d failed ===", testsPassed, testsFailed);

        return testsFailed > 0 ? 1 : 0;
    }
}
