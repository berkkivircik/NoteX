// Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
// Behavioral regression tests, added 2026-11-01.
@implementation NXApp (ParityTests)
- (void)parityTests {
    if(self.secondaryVisible)[self closeSecondary:nil];NXDocument *doc=[self newDocument:nil];ScintillaView *view=doc.editor;
    for(NSArray *entry in @[@[@"• first",@"• first\n• "],@[@"- first",@"- first\n- "],@[@"* first",@"* first\n* "],@[@"  9. café",@"  9. café\n  10. "],@[@"99. item",@"99. item\n100. "],@[@"  • ",@"  "],@[@"1. \t",@""],@[@"  text",@"  text\n  "]]) {
        SetText(view,[entry[0] dataUsingEncoding:NSUTF8StringEncoding]);Send(view,SCI_SETEOLMODE,SC_EOL_LF);Send(view,SCI_GOTOPOS,Send(view,SCI_GETLENGTH));
        NSEvent *event=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:self.window.windowNumber context:nil characters:@"\r" charactersIgnoringModifiers:@"\r" isARepeat:NO keyCode:36];
        [[view content] keyDown:event];Check([view.string isEqual:entry[1]],"Return continues or exits a typed list through native key handling");
        Send(view,SCI_UNDO);Check([view.string isEqual:entry[0]],"Return and list prefix undo together");Send(view,SCI_REDO);Check([view.string isEqual:entry[1]],"redo list continuation");
    }
    for(NSNumber *mode in @[@(SC_EOL_CRLF),@(SC_EOL_CR)]){SetText(view,[@"1. abc" dataUsingEncoding:NSUTF8StringEncoding]);Send(view,SCI_SETEOLMODE,mode.intValue);Send(view,SCI_GOTOPOS,4);[self insertEditorNewline:view];Check([view.string isEqual:mode.intValue==SC_EOL_CR?@"1. a\r2. bc":@"1. a\r\n2. bc"],"split a list item preserves suffix and line endings");}
    SetText(view,[@"  • one\n  • two\nkeep" dataUsingEncoding:NSUTF8StringEncoding]);Send(view,SCI_SETSEL,0,20);[self makeList:TestCommand(1)];Check([view.string hasPrefix:@"  1. one\n  2. two\n"],"convert bullets to numbers preserving indentation");[self makeList:TestCommand(1)];Check([view.string isEqual:@"  one\n  two\nkeep"],"toggle numbered list off");
    SetText(view,[@"1. a\n1. b" dataUsingEncoding:NSUTF8StringEncoding]);Send(view,SCI_SETEOLMODE,SC_EOL_LF);Send(view,SCI_SETSELECTION,4,4);Send(view,SCI_ADDSELECTION,9,9);[self insertEditorNewline:view];Check([view.string isEqual:@"1. a\n2. \n1. b\n2. "]&&Send(view,SCI_GETSELECTIONS)==2,"independent list continuation at multiple carets");
    Send(view,SCI_SETREADONLY,1);NSData *before=Text(view);[self insertEditorNewline:view];[self makeList:TestCommand(0)];Check([Text(view) isEqual:before],"read-only documents reject list edits");Send(view,SCI_SETREADONLY,0);
    SetText(view,[@"a\nb\nc" dataUsingEncoding:NSUTF8StringEncoding]);Send(view,SCI_SETSEL,0,0);[self lineOperation:TestCommand(4)];Check([view.string isEqual:@"c\nb\na"],"reverse lines command");Send(view,SCI_UNDO);Check([view.string isEqual:@"a\nb\nc"],"line operation is one undo action");
    Send(view,SCI_MARKERADD,1,0);[self bookmarkLines:TestCommand(2)];Check([view.string isEqual:@"a\nc"],"remove bookmarked line retains neighboring lines");
    SetText(view,[@"AbC" dataUsingEncoding:NSUTF8StringEncoding]);Send(view,SCI_SETSEL,0,3);[self caseOperation:TestCommand(2)];Check([view.string isEqual:@"aBc"],"invert selected case");
    SetText(view,[@"abc" dataUsingEncoding:NSUTF8StringEncoding]);Send(view,SCI_SETSEL,0,3);[self hashCommand:TestCommand(2)];Check([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqual:@"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"],"SHA-256 selection matches published test vector");
    NSError *error=nil;
    NSArray *boost=NXSearchMatches(@"café 12 📝\nnext 34",@{@"query":@"([0-9]+)",@"replacement":@"<$1>",@"regex":@YES,@"engine":@"boost",@"matchCase":@YES},&error);
    Check(boost.count==2&&[boost[0][@"position"] integerValue]==6&&[boost[0][@"replacement"] isEqual:@"<12>"],"Boost regex preserves UTF-8 positions and capture replacements");
    Check(NXSearchMatches(@"text",@{@"query":@"[",@"regex":@YES,@"engine":@"boost"},&error)==nil,"invalid Boost regex fails before editing");
    SetText(view,[@"one two one" dataUsingEncoding:NSUTF8StringEncoding]);self.findText.stringValue=@"one";self.replaceText.stringValue=@"three";[self searchReplace:TestCommand(1)];Check([view.string isEqual:@"three two three"],"replace all applies the computed document search plan");Send(view,SCI_UNDO);Check([view.string isEqual:@"one two one"],"replace all undoes in one action");
    Check(NXLanguageCatalog().count>=90,"shared catalog includes Windows language definitions");
    for(NSDictionary *language in NXLanguageCatalog()){auto *lexer=CreateLexer([language[@"lexer"] UTF8String]);Check(lexer!=nullptr,"shared language has a linked native lexer");if(lexer)lexer->Release();}
    Check(NXLegacyEncodings().count>=20,"native legacy encoding choices are available");
    NSStringEncoding turkish=CFStringConvertEncodingToNSStringEncoding(CFStringConvertWindowsCodepageToEncoding(1254));NSData *encoded=[@"Türkçe İstanbul" dataUsingEncoding:turkish allowLossyConversion:NO];Check([[[NSString alloc]initWithData:encoded encoding:turkish] isEqual:@"Türkçe İstanbul"],"Turkish legacy encoding round trip is lossless");
    Check([@"📝" dataUsingEncoding:turkish allowLossyConversion:NO]==nil,"unrepresentable legacy characters reject conversion");
    SetText(view,[@"Rich café" dataUsingEncoding:NSUTF8StringEncoding]);Bold24(view);Send(view,SCI_SETSEL,0,Send(view,SCI_GETLENGTH));[self copyRichText:nil];SetText(view,NSData.data);[self pasteRich:TestCommand(0)];Check([view.string isEqual:@"Rich café"]&&!State(view).runs.empty(),"RTF paste preserves Unicode and inline formatting");Send(view,SCI_UNDO);Check(Text(view).length==0,"RTF text and formatting undo together");
        NXRunTool *runner=[NXRunTool new];Check([runner launchCommand:@"printf '%s' \"$NOTEX_SELECTION\"" environment:@{@"NOTEX_SELECTION":@"$(not-a-command); café"} error:&error],"launch explicit synthetic native command");
    NSTimeInterval deadline=NSProcessInfo.processInfo.systemUptime+5;while((runner.task.running||!runner.output.length)&&NSProcessInfo.processInfo.systemUptime<deadline)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    Check([runner.output isEqual:@"$(not-a-command); café"],"document environment is passed as data without shell interpolation");
    NSUInteger first=self.documents.count;for(NSUInteger i=0;i<100;++i){NXDocument *extra=[self newDocument:nil];extra.title=[NSString stringWithFormat:@"Document %lu",(unsigned long)i];}
    [self tick:nil];[self.window.contentView layoutSubtreeIfNeeded];NXTabView *tabs=(NXTabView *)self.tabs;[tabs refreshTabs];
    Check(tabs.tabViewType==NSNoTabsNoBorder&&tabs.headerHeight<=116&&tabs.tabCanvas.frame.size.height>tabs.tabScroll.frame.size.height,"100 documents wrap into a bounded scrolling tab strip");
    NSRect header=[tabs.tabScroll convertRect:tabs.tabScroll.bounds toView:nil],editor=[tabs.selectedTabViewItem.view convertRect:tabs.selectedTabViewItem.view.bounds toView:nil];Check(NSMinY(header)>=NSMaxY(editor)-1,"document tabs stay above the editor in AppKit flipped coordinates");
    NSView *firstButton=tabs.tabCanvas.subviews.firstObject;Check(firstButton.frame.origin.x==0,"first document tab is left aligned");
    NXDocument *last=self.documents.lastObject;[self moveTabFrom:self.documents.count-1 to:0];Check(self.documents.firstObject==last&&self.tabs.selectedTabViewItem==last.tab,"moving a tab preserves document identity and selection");
    [self tabCommand:TestCommand(4)];Check(last.pinned&&[last.record[@"pinned"] boolValue],"tab pin is included in recovery record");
    [self nextTab:TestCommand(-1)];Check(self.tabs.selectedTabViewItem==self.documents.lastObject.tab,"previous tab wraps around");
    // Remove only synthetic extra documents; keep the existing suite's documents intact.
    for(NXDocument *extra in self.documents.copy)if([extra.title hasPrefix:@"Document "]){[self.documents removeObject:extra];[self.tabs removeTabViewItem:extra.tab];}
    Check(self.documents.count==first,"tab stress fixture cleans up its own documents");[self.tabs selectTabViewItem:doc.tab];[self tick:nil];
}
@end
