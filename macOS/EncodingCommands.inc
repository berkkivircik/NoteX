// Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
// Explicit lossless encoding selection, added 2026-11-01.
static NSArray *NXLegacyEncodings(void) {
    NSMutableArray *result=[NSMutableArray new];
    for(NSNumber *page in @[@1250,@1251,@1252,@1253,@1254,@1255,@1256,@1257,@1258,@874,@932,@936,@949,@950,@1361,@437,@720,@737,@775,@850,@852,@855,@857,@858,@860,@861,@862,@863,@865,@866,@869,@28591,@28592,@28593,@28594,@28595,@28596,@28597,@28598,@28599,@28603,@28605,@20866,@21866,@51932,@51949]) {
        CFStringEncoding cf=CFStringConvertWindowsCodepageToEncoding(page.unsignedIntValue);if(cf==kCFStringEncodingInvalidId)continue;
        NSStringEncoding encoding=CFStringConvertEncodingToNSStringEncoding(cf);NSString *name=[NSString localizedNameOfStringEncoding:encoding];if(!name.length)continue;
        if(![[NSString alloc]initWithData:[@"test" dataUsingEncoding:encoding allowLossyConversion:NO] encoding:encoding])continue;
        [result addObject:@{@"encoding":@(encoding),@"name":[NSString stringWithFormat:@"%@ (CP%@)",name,page]}];
    }return result;
}
@implementation NXApp (EncodingCommands)
- (void)legacyEncoding:(id)sender {
    NSArray *encodings=NXLegacyEncodings();NSInteger index=NXChoose([sender tag]?@"Convert Document Encoding":@"Open with Encoding",[encodings valueForKey:@"name"],self.window);if(index<0)return;NSStringEncoding encoding=[encodings[index][@"encoding"] unsignedIntegerValue];
    if([sender tag]){NSData *data=[self.current.editor.string dataUsingEncoding:encoding allowLossyConversion:NO];NSString *roundTrip=data?[[NSString alloc]initWithData:data encoding:encoding]:nil;if(![roundTrip isEqual:self.current.editor.string]){Alert(@"This encoding cannot preserve every character. The document was not changed.");return;}self.current.encoding=encoding;self.current.bom=NO;self.current.restoredDirty=YES;[self tick:nil];}
    else {NSOpenPanel *panel=[NSOpenPanel openPanel];panel.allowsMultipleSelection=YES;if([panel runModal]!=NSModalResponseOK)return;self.openingEncoding=encoding;for(NSURL *url in panel.URLs){NSError *error=nil;if(![self openPath:url.path error:&error])Alert(error.localizedDescription);}self.openingEncoding=0;}
}
- (void)buildEncodingMenus {
    NSMenu *encoding=[NSApp.mainMenu itemWithTitle:@"Encoding"].submenu;[self item:encoding title:@"Open with Legacy Encoding…" action:@selector(legacyEncoding:) key:@"" tag:0];[self item:encoding title:@"Convert to Legacy Encoding…" action:@selector(legacyEncoding:) key:@"" tag:1];
}
@end
