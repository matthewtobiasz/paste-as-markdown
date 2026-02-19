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

- (void)writeMarkdown:(NSString *)markdown {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:markdown forType:NSPasteboardTypeString];
}

@end
