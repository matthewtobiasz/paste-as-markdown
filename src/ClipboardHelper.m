#import "ClipboardHelper.h"

@implementation ClipboardHelper {
    NSPasteboard *_pasteboard;
}

- (instancetype)init {
    return [self initWithPasteboard:[NSPasteboard generalPasteboard]];
}

- (instancetype)initWithPasteboard:(NSPasteboard *)pasteboard {
    self = [super init];
    if (self) {
        _pasteboard = pasteboard;
    }
    return self;
}

- (nullable NSString *)readHTML {
    NSPasteboard *pb = _pasteboard;

    // Try HTML first
    NSString *html = [pb stringForType:NSPasteboardTypeHTML];
    if (html && html.length > 0) {
        return html;
    }

    // Fallback: try RTF and convert to HTML via NSAttributedString
    NSData *rtfData = [pb dataForType:NSPasteboardTypeRTF];
    if (rtfData && rtfData.length > 0) {
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithRTF:rtfData
                                                              documentAttributes:nil];
        if (attrString) {
            NSError *error = nil;
            NSData *htmlData = [attrString dataFromRange:NSMakeRange(0, attrString.length)
                                      documentAttributes:@{
                                          NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType
                                      }
                                                   error:&error];
            if (htmlData) {
                return [[NSString alloc] initWithData:htmlData encoding:NSUTF8StringEncoding];
            }
            if (error) {
                NSLog(@"[Paste as Markdown] RTF to HTML conversion error: %@", error);
            }
        }
    }

    return nil;
}

- (nullable NSString *)readPlainText {
    NSString *text = [_pasteboard stringForType:NSPasteboardTypeString];
    if (text && text.length > 0) {
        return text;
    }
    return nil;
}

- (BOOL)replaceClipboardWithMarkdown:(NSString *)markdown {
    NSPasteboard *pb = _pasteboard;

    // Snapshot only the text-bearing flavors we could re-convert from. We
    // deliberately do NOT snapshot every type on the pasteboard: requesting
    // data for arbitrary flavors forces resolution of lazy/promised data
    // (file promises, large TIFF renderings), which can be slow and
    // memory-heavy — a real cost paid on every conversion to protect a
    // write-failure path that essentially never occurs.
    NSArray<NSPasteboardType> *typesToSnapshot =
        @[NSPasteboardTypeString, NSPasteboardTypeHTML, NSPasteboardTypeRTF];

    NSMutableArray<NSPasteboardItem *> *snapshot = [NSMutableArray array];
    for (NSPasteboardItem *item in pb.pasteboardItems) {
        NSPasteboardItem *copy = [[NSPasteboardItem alloc] init];
        BOOL copiedAnything = NO;
        for (NSPasteboardType type in typesToSnapshot) {
            if (![item.types containsObject:type]) continue;
            NSData *data = [item dataForType:type];
            if (data) {
                [copy setData:data forType:type];
                copiedAnything = YES;
            }
        }
        if (copiedAnything) {
            [snapshot addObject:copy];
        }
    }

    [pb clearContents];
    BOOL success = [pb setString:markdown forType:NSPasteboardTypeString];
    if (!success) {
        NSLog(@"[Paste as Markdown] Failed to write markdown to clipboard; restoring text flavors");
        [pb clearContents];
        if (snapshot.count > 0) {
            [pb writeObjects:snapshot];
        }
    }
    return success;
}

@end
