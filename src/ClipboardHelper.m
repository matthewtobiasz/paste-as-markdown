#import "ClipboardHelper.h"

@implementation ClipboardHelper

- (nullable NSString *)readHTML {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];

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
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *text = [pb stringForType:NSPasteboardTypeString];
    if (text && text.length > 0) {
        return text;
    }
    return nil;
}

- (BOOL)replaceClipboardWithMarkdown:(NSString *)markdown {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];

    // Snapshot the current pasteboard contents before clearing so we can restore
    // them if the write fails (NSPasteboard requires clearContents before writing).
    NSMutableArray<NSPasteboardItem *> *snapshot = [NSMutableArray array];
    for (NSPasteboardItem *item in pb.pasteboardItems) {
        NSPasteboardItem *copy = [[NSPasteboardItem alloc] init];
        for (NSString *type in item.types) {
            NSData *data = [item dataForType:type];
            if (data) {
                [copy setData:data forType:type];
            }
        }
        [snapshot addObject:copy];
    }

    [pb clearContents];
    BOOL success = [pb setString:markdown forType:NSPasteboardTypeString];
    if (!success) {
        NSLog(@"[Paste as Markdown] Failed to write markdown to clipboard; restoring original contents");
        [pb clearContents];
        [pb writeObjects:snapshot];
    }
    return success;
}

@end
