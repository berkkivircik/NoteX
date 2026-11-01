// Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
// Native editing operations, added 2026-11-01.
static NSString *NXPrompt(NSString *title, NSString *initial) {
    NSAlert *alert=[NSAlert new];alert.messageText=title;NSTextField *field=[[NSTextField alloc]initWithFrame:NSMakeRect(0,0,360,26)];field.stringValue=initial;alert.accessoryView=field;[alert addButtonWithTitle:@"Apply"];[alert addButtonWithTitle:@"Cancel"];return [alert runModal]==NSAlertFirstButtonReturn?field.stringValue:nil;
}
static void NXReplaceRange(ScintillaView *view, sptr_t start, sptr_t end, NSString *value) {
    if(Send(view,SCI_GETREADONLY))return;NSData *data=[value dataUsingEncoding:NSUTF8StringEncoding];Send(view,SCI_SETTARGETRANGE,start,end);Send(view,SCI_REPLACETARGET,data.length,reinterpret_cast<sptr_t>(data.bytes));
}
static NSString *NXEOL(ScintillaView *view) {auto mode=Send(view,SCI_GETEOLMODE);return mode==SC_EOL_CRLF?@"\r\n":mode==SC_EOL_CR?@"\r":@"\n";}
@implementation NXApp (TextCommands)
- (void)selectionMode:(id)sender {Send(self.current.editor,SCI_SETSELECTIONMODE,[sender tag]);}
- (void)lineOperation:(id)sender {
    ScintillaView *view=self.current.editor;if(Send(view,SCI_GETREADONLY))return;
    auto a=Send(view,SCI_GETSELECTIONSTART),b=Send(view,SCI_GETSELECTIONEND);auto first=Send(view,SCI_LINEFROMPOSITION,a),last=Send(view,SCI_LINEFROMPOSITION,b);
    if(a==b){first=0;last=Send(view,SCI_GETLINECOUNT)-1;}else if(last>first&&b==Send(view,SCI_POSITIONFROMLINE,last))--last;
    a=Send(view,SCI_POSITIONFROMLINE,first);b=Send(view,SCI_GETLINEENDPOSITION,last);
    NSString *text=[[NSString alloc]initWithData:[Text(view) subdataWithRange:NSMakeRange(a,b-a)] encoding:NSUTF8StringEncoding];NSString *eol=NXEOL(view);
    NSMutableArray<NSString *> *lines=[[text componentsSeparatedByString:eol] mutableCopy];NSInteger action=[sender tag];
    if(action>=4&&action<=8){
        if(action==4)lines=[[lines reverseObjectEnumerator].allObjects mutableCopy];
        else [lines sortUsingComparator:^NSComparisonResult(NSString *x,NSString *y){NSComparisonResult result=action==7?[x localizedStandardCompare:y]:[x compare:y options:action==6?NSCaseInsensitiveSearch:0];return action==8?(NSComparisonResult)-result:result;}];
    }else if(action==9) {NSMutableArray *unique=[NSMutableArray new];for(NSString *line in lines)if(![unique.lastObject isEqual:line])[unique addObject:line];lines=unique;}
    else if(action==10){for(NSUInteger i=0;i<lines.count;++i)lines[i]=[lines[i] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];lines=[NSMutableArray arrayWithObject:[lines componentsJoinedByString:@" "]];}
    else {NSMutableArray *changed=[NSMutableArray new];NSInteger tab=MAX(1,Send(view,SCI_GETTABWIDTH));
        for(NSString *line in lines){NSString *value=line;
            if(action==0){NSUInteger i=0;while(i<value.length&&([value characterAtIndex:i]==' '||[value characterAtIndex:i]=='\t'))++i;value=[value substringFromIndex:i];}
            else if(action==1)value=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            else if(action==2&&!value.length)continue;
            else if(action==3&&![value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length)continue;
            else if(action==11){NSMutableString *expanded=[NSMutableString new];NSUInteger column=0;for(NSUInteger i=0;i<value.length;++i){unichar c=[value characterAtIndex:i];if(c=='\t'){NSUInteger n=tab-column%tab;[expanded appendString:[@"" stringByPaddingToLength:n withString:@" " startingAtIndex:0]];column+=n;}else{[expanded appendFormat:@"%C",c];++column;}}value=expanded;}
            else if(action==12){NSUInteger i=0;while(i<value.length&&[value characterAtIndex:i]==' ')++i;value=[NSString stringWithFormat:@"%@%@%@",[@"" stringByPaddingToLength:i/tab withString:@"\t" startingAtIndex:0],[@"" stringByPaddingToLength:i%tab withString:@" " startingAtIndex:0],[value substringFromIndex:i]];}
            [changed addObject:value];}lines=changed;
    }
    Send(view,SCI_BEGINUNDOACTION);NXReplaceRange(view,a,b,[lines componentsJoinedByString:eol]);Send(view,SCI_ENDUNDOACTION);[self tick:nil];
}
- (void)caseOperation:(id)sender {
    ScintillaView *view=self.current.editor;NSString *text=view.selectedString;if(!text.length)return;NSMutableString *result=[NSMutableString new];NSInteger action=[sender tag];
    if(action==0)[result appendString:text.capitalizedString];
    else {__block BOOL sentence=YES;[text enumerateSubstringsInRange:NSMakeRange(0,text.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *part,NSRange range,NSRange enclosing,BOOL *stop){
        if(action==2)[result appendString:[part isEqual:part.uppercaseString]?part.lowercaseString:part.uppercaseString];
        else {BOOL letter=[part rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location!=NSNotFound;[result appendString:sentence?part.uppercaseString:part.lowercaseString];if(letter)sentence=NO;if([@[@".",@"!",@"?",@"\n",@"\r"] containsObject:part])sentence=YES;}
    }];}
    NXReplaceRange(view,Send(view,SCI_GETSELECTIONSTART),Send(view,SCI_GETSELECTIONEND),result);[self tick:nil];
}
- (void)commentOperation:(id)sender {
    NXDocument *doc=self.current;ScintillaView *view=doc.editor;if(Send(view,SCI_GETREADONLY))return;
    NSDictionary *language=[self userLanguage:doc] ?: NXBuiltIn(doc.builtinLanguage);NSString *line=language[@"lineComment"],*open=language[@"blockOpen"],*close=language[@"blockClose"];
    if(!language){if([@[@"python",@"bash",@"ruby",@"perl",@"yaml",@"makefile",@"r"] containsObject:doc.lexer])line=@"#";else if([@[@"sql",@"lua",@"haskell"] containsObject:doc.lexer])line=@"--";else if([@[@"html",@"xml"] containsObject:doc.lexer]){open=@"<!--";close=@"-->";line=@"";}else {line=@"//";open=@"/*";close=@"*/";}}
    if([sender tag]){if(!open.length||!close.length){Alert(@"This language has no block-comment delimiters.");return;}NSString *selected=view.selectedString;BOOL remove=[selected hasPrefix:open]&&[selected hasSuffix:close]&&selected.length>=open.length+close.length;NSString *value=remove?[selected substringWithRange:NSMakeRange(open.length,selected.length-open.length-close.length)]:[NSString stringWithFormat:@"%@%@%@",open,selected,close];NXReplaceRange(view,Send(view,SCI_GETSELECTIONSTART),Send(view,SCI_GETSELECTIONEND),value);}
    else {if(!line.length){Alert(@"This language has no line-comment delimiter.");return;}
        auto a=Send(view,SCI_GETSELECTIONSTART),b=Send(view,SCI_GETSELECTIONEND),first=Send(view,SCI_LINEFROMPOSITION,a),last=Send(view,SCI_LINEFROMPOSITION,b);if(b>a&&last>first&&b==Send(view,SCI_POSITIONFROMLINE,last))--last;
        NSData *prefix=[line dataUsingEncoding:NSUTF8StringEncoding];std::string text(static_cast<const char *>(Text(view).bytes),Text(view).length);bool remove=true;
        for(auto n=first;n<=last;++n){auto p=Send(view,SCI_GETLINEINDENTPOSITION,n);if(text.compare(p,prefix.length,line.UTF8String))remove=false;}
        Send(view,SCI_BEGINUNDOACTION);for(auto n=last;n>=first;--n){auto p=Send(view,SCI_GETLINEINDENTPOSITION,n);NXReplaceRange(view,p,p+(remove?prefix.length:0),remove?@"":line);}Send(view,SCI_ENDUNDOACTION);
    }[self tick:nil];
}
- (void)insertDate:(id)sender {NSString *pattern=[sender tag]?NXPrompt(@"Date Format",@"yyyy-MM-dd HH:mm:ss"):@"yyyy-MM-dd HH:mm:ss";if(!pattern)return;NSDateFormatter *formatter=[NSDateFormatter new];formatter.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];formatter.dateFormat=pattern;NXReplaceRange(self.current.editor,Send(self.current.editor,SCI_GETSELECTIONSTART),Send(self.current.editor,SCI_GETSELECTIONEND),[formatter stringFromDate:NSDate.date]);}
- (void)columnEditor:(id)sender {
    NSString *value=NXPrompt(@"Insert Text at Each Selected Line's Column",@"");if(!value)return;ScintillaView *view=self.current.editor;
    auto start=Send(view,SCI_GETSELECTIONSTART),end=Send(view,SCI_GETSELECTIONEND),column=Send(view,SCI_GETCOLUMN,start);auto first=Send(view,SCI_LINEFROMPOSITION,start),last=Send(view,SCI_LINEFROMPOSITION,end);if(end>start&&last>first&&end==Send(view,SCI_POSITIONFROMLINE,last))--last;
    Send(view,SCI_BEGINUNDOACTION);for(auto line=last;line>=first;--line){auto pos=Send(view,SCI_FINDCOLUMN,line,column);auto actual=Send(view,SCI_GETCOLUMN,pos);NSString *padding=[@"" stringByPaddingToLength:MAX(0,column-actual) withString:@" " startingAtIndex:0];NXReplaceRange(view,pos,pos,[padding stringByAppendingString:value]);}Send(view,SCI_ENDUNDOACTION);
}
- (void)characterViewer:(id)sender {[NSApp orderFrontCharacterPalette:nil];}
- (void)viewCommand:(id)sender {ScintillaView *view=self.current.editor;NSInteger action=[sender tag];if(action==0)[self.window toggleFullScreen:nil];else if(action==1)Alert([NSString stringWithFormat:@"%ld lines\n%lu UTF-16 code units\n%ld UTF-8 bytes\n%ld selected bytes",(long)Send(view,SCI_GETLINECOUNT),(unsigned long)view.string.length,(long)Send(view,SCI_GETLENGTH),(long)(Send(view,SCI_GETSELECTIONEND)-Send(view,SCI_GETSELECTIONSTART))]);else if(action==4){NXTabView *tabs=(NXTabView *)self.tabs;if(self.documentMap){[self.documentMap removeFromSuperview];self.documentMap=nil;tabs.overview=nil;}else{self.documentMap=[NXDocumentMap new];self.documentMap.editor=view;tabs.overview=self.documentMap;[tabs addSubview:self.documentMap];}tabs.needsLayout=YES;[tabs layoutSubtreeIfNeeded];}else Send(view,SCI_SETBIDIRECTIONAL,action==3?SC_BIDIRECTIONAL_R2L:SC_BIDIRECTIONAL_L2R);}
- (void)foldLevel:(id)sender {ScintillaView *view=self.current.editor;for(sptr_t line=0;line<Send(view,SCI_GETLINECOUNT);++line){auto level=Send(view,SCI_GETFOLDLEVEL,line);if((level&SC_FOLDLEVELHEADERFLAG)&&((level&SC_FOLDLEVELNUMBERMASK)-SC_FOLDLEVELBASE)==[sender tag]-1)Send(view,SCI_FOLDLINE,line,SC_FOLDACTION_TOGGLE);}}
- (void)bookmarkLines:(id)sender {
    ScintillaView *view=self.current.editor;NSInteger action=[sender tag];NSMutableString *copied=[NSMutableString new];
    std::string text(static_cast<const char *>(Text(view).bytes),Text(view).length);Send(view,SCI_BEGINUNDOACTION);
    for(sptr_t line=Send(view,SCI_GETLINECOUNT)-1;line>=0;--line){BOOL marked=(Send(view,SCI_MARKERGET,line)&1)!=0;auto start=Send(view,SCI_POSITIONFROMLINE,line),end=Send(view,SCI_POSITIONFROMLINE,line+1);if(end<0)end=text.size();
        if(action==4){Send(view,marked?SCI_MARKERDELETE:SCI_MARKERADD,line,0);continue;}
        if(marked&&action<2){NSString *part=[[NSString alloc]initWithBytes:text.data()+start length:end-start encoding:NSUTF8StringEncoding];[copied insertString:part atIndex:0];}
        if((marked&&(action==1||action==2))||(!marked&&action==3))Send(view,SCI_DELETERANGE,start,end-start);
    }Send(view,SCI_ENDUNDOACTION);if(action<2){[NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:copied forType:NSPasteboardTypeString];}[self tick:nil];
}
- (void)hashCommand:(id)sender {
    NSInteger action=[sender tag];NSData *data=nil;if(action>=4){NSOpenPanel *panel=[NSOpenPanel openPanel];if([panel runModal]!=NSModalResponseOK)return;data=[NSData dataWithContentsOfURL:panel.URL options:NSDataReadingMappedIfSafe error:nil];}else data=[self.current.editor.selectedString dataUsingEncoding:NSUTF8StringEncoding];if(!data){Alert(@"The input could not be read.");return;}
    unsigned char digest[CC_SHA512_DIGEST_LENGTH];NSUInteger size=0;auto bytes=static_cast<const unsigned char *>(data.bytes);
    // Chunk input to avoid truncating CommonCrypto's 32-bit count for large files.
    CC_MD5_CTX md5;CC_SHA1_CTX sha1;CC_SHA256_CTX sha256;CC_SHA512_CTX sha512;NSInteger type=action%4;
    if(type==0)CC_MD5_Init(&md5);else if(type==1)CC_SHA1_Init(&sha1);else if(type==2)CC_SHA256_Init(&sha256);else CC_SHA512_Init(&sha512);
    for(NSUInteger pos=0;pos<data.length;){CC_LONG n=(CC_LONG)MIN((NSUInteger)(1<<20),data.length-pos);if(type==0)CC_MD5_Update(&md5,bytes+pos,n);else if(type==1)CC_SHA1_Update(&sha1,bytes+pos,n);else if(type==2)CC_SHA256_Update(&sha256,bytes+pos,n);else CC_SHA512_Update(&sha512,bytes+pos,n);pos+=n;}
    if(type==0){CC_MD5_Final(digest,&md5);size=16;}else if(type==1){CC_SHA1_Final(digest,&sha1);size=20;}else if(type==2){CC_SHA256_Final(digest,&sha256);size=32;}else{CC_SHA512_Final(digest,&sha512);size=64;}
    NSMutableString *result=[NSMutableString new];for(NSUInteger i=0;i<size;++i)[result appendFormat:@"%02x",digest[i]];[NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:result forType:NSPasteboardTypeString];self.status.stringValue=@"Hash copied to the clipboard.";
}
@end
