// Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
// Native NoteX application, created 2026-11-01.
#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>
#import "ScintillaView.h"
#import "Storage.h"
#include "ILexer.h"
#include "Lexilla.h"
#include "SciLexer.h"
#include <cstdio>
#include <cmath>

static sptr_t Send(ScintillaView *view, unsigned message, uptr_t w = 0, sptr_t l = 0) {
    return [view message:message wParam:w lParam:l];
}
static NSData *Text(ScintillaView *view) {
    auto size = Send(view, SCI_GETLENGTH);
    return [NSData dataWithBytes:reinterpret_cast<const void *>(Send(view, SCI_GETCHARACTERPOINTER)) length:size];
}
static void SetText(ScintillaView *view, NSData *data) {
    Send(view, SCI_CLEARALL);
    Send(view, SCI_ADDTEXT, data.length, reinterpret_cast<sptr_t>(data.bytes));
    Send(view, SCI_EMPTYUNDOBUFFER);
    Send(view, SCI_SETSAVEPOINT);
}
static NoteX::State State(ScintillaView *view) {
    NoteX::State state;
    Send(view, NoteX::GetState, 0, reinterpret_cast<sptr_t>(&state));
    return state;
}
static void Restore(ScintillaView *view, NoteX::State state) {
    NoteX::Restore restore{std::move(state), false};
    Send(view, NoteX::SetState, 0, reinterpret_cast<sptr_t>(&restore));
}
static void Alert(NSString *message) {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"NoteX";
    alert.informativeText = message ?: @"The operation could not be completed.";
    [alert runModal];
}

@interface NXDocument : NSObject
@property ScintillaView *editor;
@property NSTabViewItem *tab;
@property NSString *identifier;
@property NSString *path;
@property NSString *title;
@property NSString *lexer;
@property NSData *diskHash;
@property NSStringEncoding encoding;
@property BOOL bom;
@property BOOL restoredDirty;
- (BOOL)dirty;
- (NSDictionary *)record;
@end
@implementation NXDocument
- (BOOL)dirty { return self.restoredDirty || Send(self.editor, SCI_GETMODIFY); }
- (NSDictionary *)record {
    NSData *text = Text(self.editor);
    return @{@"id":self.identifier, @"path":self.path, @"title":self.title, @"lexer":self.lexer,
             @"text":text, @"format":NXCompanion(text, State(self.editor)), @"diskHash":self.diskHash,
             @"encoding":@(self.encoding), @"bom":@(self.bom), @"dirty":@(self.dirty),
             @"caret":@(Send(self.editor, SCI_GETCURRENTPOS)), @"anchor":@(Send(self.editor, SCI_GETANCHOR)),
             @"firstLine":@(Send(self.editor, SCI_GETFIRSTVISIBLELINE))};
}
@end

@interface NXApp : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTabViewDelegate, ScintillaNotificationProtocol>
@property NSWindow *window;
@property NSTabView *tabs;
@property NSMutableArray<NXDocument *> *documents;
@property NXStorage *storage;
@property NSDictionary *lastSnapshot;
@property NSTextField *status;
@property NSComboBox *family;
@property NSComboBox *size;
@property NSTextField *findText;
@property NSTextField *replaceText;
@property NSStackView *findBar;
@property NSPopUpButton *language;
@property NSTimer *timer;
@property BOOL restoring;
@property BOOL dark;
@property BOOL wrap;
@property BOOL snapshotFailed;
@property unsigned colorField;
@property NSMutableArray<NSString *> *pendingFiles;
- (NXDocument *)current;
- (NXDocument *)newDocument:(id)sender;
- (void)configureLexer:(NXDocument *)doc;
- (BOOL)snapshot:(NSError **)error;
- (BOOL)openPath:(NSString *)path error:(NSError **)error;
- (BOOL)saveDocument:(NXDocument *)doc path:(NSString *)path error:(NSError **)error;
- (void)selfTest:(NSString *)mode;
@end

@implementation NXApp
- (NXDocument *)current {
    NSInteger index = [self.tabs indexOfTabViewItem:self.tabs.selectedTabViewItem];
    return index >= 0 && index < (NSInteger)self.documents.count ? self.documents[index] : nil;
}
- (NSButton *)button:(NSString *)title action:(SEL)action tag:(NSInteger)tag {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.tag = tag;
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}
- (void)item:(NSMenu *)menu title:(NSString *)title action:(SEL)action key:(NSString *)key tag:(NSInteger)tag {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self; item.tag = tag;
    [menu addItem:item];
}
- (NSMenu *)menu:(NSString *)title parent:(NSMenu *)parent {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:title];
    item.submenu = menu;
    [parent addItem:item];
    return menu;
}
- (void)buildMenus {
    NSMenu *root = [NSMenu new];
    NSMenu *app = [self menu:@"NoteX" parent:root];
    [self item:app title:@"About NoteX" action:@selector(about:) key:@"" tag:0];
    [app addItem:NSMenuItem.separatorItem];
    NSMenuItem *hide = [[NSMenuItem alloc] initWithTitle:@"Hide NoteX" action:@selector(hide:) keyEquivalent:@"h"];
    [app addItem:hide];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit NoteX" action:@selector(terminate:) keyEquivalent:@"q"];
    [app addItem:quit];
    NSMenu *file = [self menu:@"File" parent:root];
    [self item:file title:@"New Tab" action:@selector(newDocument:) key:@"n" tag:0];
    [self item:file title:@"Open…" action:@selector(open:) key:@"o" tag:0];
    [self item:file title:@"Save" action:@selector(save:) key:@"s" tag:0];
    [self item:file title:@"Save As…" action:@selector(saveAs:) key:@"S" tag:0];
    [self item:file title:@"Close Tab…" action:@selector(closeTab:) key:@"w" tag:0];
    [file addItem:NSMenuItem.separatorItem];
    [self item:file title:@"Show Session Folder" action:@selector(showSession:) key:@"" tag:0];
    NSMenu *edit = [self menu:@"Edit" parent:root];
    for (NSArray *entry in @[@[@"Undo", @"undo:", @"z"], @[@"Redo", @"redo:", @"Z"],
                            @[@"Cut", @"cut:", @"x"], @[@"Copy", @"copy:", @"c"],
                            @[@"Paste", @"paste:", @"v"], @[@"Select All", @"selectAll:", @"a"]]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:entry[2]];
        [edit addItem:item];
    }
    [edit addItem:NSMenuItem.separatorItem];
    [self item:edit title:@"Find and Replace…" action:@selector(showFind:) key:@"f" tag:0];
    [self item:edit title:@"Find Next" action:@selector(findNext:) key:@"g" tag:0];
    [self item:edit title:@"Go to Line…" action:@selector(goToLine:) key:@"l" tag:0];
    NSMenu *format = [self menu:@"Format" parent:root];
    [self item:format title:@"Bold" action:@selector(toggleFormat:) key:@"b" tag:NoteX::Bold];
    [self item:format title:@"Italic" action:@selector(toggleFormat:) key:@"i" tag:NoteX::Italic];
    [self item:format title:@"Underline" action:@selector(toggleFormat:) key:@"u" tag:NoteX::Underline];
    [self item:format title:@"Strikethrough" action:@selector(toggleFormat:) key:@"" tag:NoteX::Strike];
    [self item:format title:@"Text Color…" action:@selector(pickColor:) key:@"" tag:NoteX::Fore];
    [self item:format title:@"Highlight Color…" action:@selector(pickColor:) key:@"" tag:NoteX::Highlight];
    [self item:format title:@"Clear Formatting" action:@selector(clearFormat:) key:@"" tag:0];
    [self item:format title:@"Bulleted List" action:@selector(makeList:) key:@"" tag:0];
    [self item:format title:@"Numbered List" action:@selector(makeList:) key:@"" tag:1];
    NSMenu *view = [self menu:@"View" parent:root];
    [self item:view title:@"Toggle Word Wrap" action:@selector(toggleWrap:) key:@"" tag:0];
    [self item:view title:@"Toggle Dark Appearance" action:@selector(toggleDark:) key:@"" tag:0];
    [self item:view title:@"Zoom In" action:@selector(editorCommand:) key:@"+" tag:SCI_ZOOMIN];
    [self item:view title:@"Zoom Out" action:@selector(editorCommand:) key:@"-" tag:SCI_ZOOMOUT];
    [self item:view title:@"Reset Zoom" action:@selector(editorCommand:) key:@"0" tag:SCI_SETZOOM];
    [self item:view title:@"Next Tab" action:@selector(nextTab:) key:@"]" tag:1];
    [self item:view title:@"Previous Tab" action:@selector(nextTab:) key:@"[" tag:-1];
    NSMenu *help = [self menu:@"Help" parent:root];
    [self item:help title:@"macOS Guide and Limitations" action:@selector(guide:) key:@"" tag:0];
    [self item:help title:@"Source Code and License" action:@selector(source:) key:@"" tag:0];
    NSApp.mainMenu = root;
}
- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1120, 740)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"NoteX";
    self.window.minSize = NSMakeSize(900, 450);
    self.window.delegate = self;
    self.window.releasedWhenClosed = NO;
    self.window.frameAutosaveName = @"NoteXMainWindow";
    [self.window center];
    NSView *content = self.window.contentView;
    self.family = [[NSComboBox alloc] initWithFrame:NSMakeRect(0, 0, 170, 26)];
    [self.family addItemsWithObjectValues:[NSFontManager.sharedFontManager.availableFontFamilies sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
    self.family.stringValue = @"JetBrains Mono"; self.family.target = self; self.family.action = @selector(changeFamily:);
    [self.family.widthAnchor constraintEqualToConstant:170].active = YES;
    self.size = [[NSComboBox alloc] initWithFrame:NSMakeRect(0, 0, 64, 26)];
    [self.size addItemsWithObjectValues:@[@"8", @"9", @"10", @"11", @"12", @"13", @"14", @"16", @"18", @"24", @"32", @"48", @"72", @"96"]];
    self.size.stringValue = @"13"; self.size.target = self; self.size.action = @selector(changeSize:);
    [self.size.widthAnchor constraintEqualToConstant:64].active = YES;
    self.language = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.language addItemWithTitle:@"Plain Text"];
    for (int i = 0; i < GetLexerCount(); ++i) { char name[128]{}; GetLexerName(i, name, sizeof name); [self.language addItemWithTitle:@(name)]; }
    self.language.target = self; self.language.action = @selector(changeLanguage:);
    [self.language.widthAnchor constraintEqualToConstant:140].active = YES;
    NSStackView *toolbar = [NSStackView stackViewWithViews:@[
        [self button:@"+" action:@selector(newDocument:) tag:0], self.family, self.size,
        [self button:@"B" action:@selector(toggleFormat:) tag:NoteX::Bold],
        [self button:@"I" action:@selector(toggleFormat:) tag:NoteX::Italic],
        [self button:@"U" action:@selector(toggleFormat:) tag:NoteX::Underline],
        [self button:@"S̶" action:@selector(toggleFormat:) tag:NoteX::Strike],
        [self button:@"Color" action:@selector(pickColor:) tag:NoteX::Fore],
        [self button:@"Highlight" action:@selector(pickColor:) tag:NoteX::Highlight], self.language]];
    toolbar.spacing = 6;
    toolbar.edgeInsets = NSEdgeInsetsMake(8, 10, 8, 10);
    self.findText = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 24)];
    self.findText.placeholderString = @"Find";
    self.findText.target = self; self.findText.action = @selector(findNext:);
    self.replaceText = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 24)];
    self.replaceText.placeholderString = @"Replace with";
    for (NSTextField *field in @[self.findText, self.replaceText]) [field.widthAnchor constraintGreaterThanOrEqualToConstant:160].active = YES;
    self.findBar = [NSStackView stackViewWithViews:@[self.findText, self.replaceText,
        [self button:@"Next" action:@selector(findNext:) tag:0],
        [self button:@"Replace" action:@selector(replace:) tag:0],
        [self button:@"Replace All" action:@selector(replace:) tag:1],
        [self button:@"Done" action:@selector(hideFind:) tag:0]]];
    self.findBar.edgeInsets = NSEdgeInsetsMake(4, 10, 4, 10);
    self.findBar.hidden = YES;
    self.tabs = [[NSTabView alloc] initWithFrame:NSZeroRect];
    self.tabs.delegate = self;
    self.status = [NSTextField labelWithString:@"UTF-8"];
    NSStackView *stack = [NSStackView stackViewWithViews:@[toolbar, self.findBar, self.tabs, self.status]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 4;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-6],
        [toolbar.widthAnchor constraintEqualToAnchor:stack.widthAnchor], [self.tabs.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [self.tabs.heightAnchor constraintGreaterThanOrEqualToConstant:200]]];
    [self.tabs setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    for (NSString *font in @[@"JetBrainsMono.ttf", @"Inter.ttf"]) {
        NSURL *url = [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:[@"Fonts" stringByAppendingPathComponent:font]];
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, nil);
    }
    self.documents = [NSMutableArray new];
    self.dark = YES; self.wrap = YES; self.restoring = YES;
    NSError *error = nil;
    NSString *profile = NSProcessInfo.processInfo.environment[@"NOTEX_PROFILE"];
    if (!profile.length) profile = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NoteX"];
    self.storage = [[NXStorage alloc] initWithDirectory:profile error:&error];
    NSDictionary *session = self.storage ? [self.storage load:&error] : nil;
    if (error) { Alert(error.localizedDescription); exit(1); }
    if (session[@"dark"]) self.dark = [session[@"dark"] boolValue];
    if (session[@"wrap"]) self.wrap = [session[@"wrap"] boolValue];
    [self buildMenus]; [self buildWindow];
    self.window.appearance = [NSAppearance appearanceNamed:self.dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
    for (NSDictionary *record in session[@"documents"]) {
        NXDocument *doc = [self newDocument:nil];
        doc.identifier = record[@"id"]; doc.path = record[@"path"]; doc.title = record[@"title"];
        doc.diskHash = record[@"diskHash"]; doc.encoding = [record[@"encoding"] unsignedIntegerValue]; doc.bom = [record[@"bom"] boolValue];
        doc.lexer = record[@"lexer"];
        SetText(doc.editor, record[@"text"]);
        NoteX::State state;
        NXReadCompanion(record[@"format"], record[@"text"], state);
        Restore(doc.editor, std::move(state));
        Send(doc.editor, SCI_EMPTYUNDOBUFFER); Send(doc.editor, SCI_SETSAVEPOINT);
        doc.restoredDirty = [record[@"dirty"] boolValue];
        auto length = Send(doc.editor, SCI_GETLENGTH);
        Send(doc.editor, SCI_SETSEL, std::clamp<sptr_t>([record[@"anchor"] longLongValue], 0, length),
             std::clamp<sptr_t>([record[@"caret"] longLongValue], 0, length));
        Send(doc.editor, SCI_SETFIRSTVISIBLELINE, std::max<long long>(0, [record[@"firstLine"] longLongValue]));
        [self configureLexer:doc];
    }
    if (!self.documents.count) [self newDocument:nil];
    NSInteger selected = [session[@"selected"] integerValue];
    if (selected >= 0 && selected < (NSInteger)self.documents.count) [self.tabs selectTabViewItemAtIndex:selected];
    self.restoring = NO;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeFirstResponder:self.current.editor];
    [self tick:nil];
    if (self.storage.recoveredPrevious) Alert(@"The latest session snapshot could not be read. NoteX restored the previous snapshot and retained the damaged file in the session folder. The most recent edits may be missing.");
    for (NSString *path in self.pendingFiles) {
        NSError *openError = nil;
        if (![self openPath:path error:&openError]) Alert(openError.localizedDescription);
    }
    self.pendingFiles = nil;
    NSArray *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [arguments indexOfObject:@"--self-test"];
    if (index != NSNotFound && index + 1 < arguments.count) {
        NSString *mode = arguments[index + 1];
        dispatch_async(dispatch_get_main_queue(), ^{ [self selfTest:mode]; });
    }
}
- (NXDocument *)newDocument:(id)sender {
    NXDocument *doc = [NXDocument new];
    doc.identifier = NSUUID.UUID.UUIDString; doc.path = @""; doc.lexer = @"null";
    doc.title = [NSString stringWithFormat:@"Untitled %lu", (unsigned long)self.documents.count + 1];
    doc.diskHash = NSData.data; doc.encoding = NSUTF8StringEncoding;
    doc.editor = [[ScintillaView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 620)];
    doc.editor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    Send(doc.editor, SCI_SETCODEPAGE, SC_CP_UTF8);
    Send(doc.editor, SCI_SETEOLMODE, SC_EOL_LF);
    Send(doc.editor, SCI_SETTABWIDTH, 4); Send(doc.editor, SCI_SETUSETABS, 0);
    Send(doc.editor, SCI_SETMARGINTYPEN, 0, SC_MARGIN_NUMBER); Send(doc.editor, SCI_SETMARGINWIDTHN, 0, 56);
    Send(doc.editor, SCI_SETWRAPMODE, self.wrap ? SC_WRAP_WORD : SC_WRAP_NONE);
    Send(doc.editor, SCI_STYLESETFONT, STYLE_DEFAULT, reinterpret_cast<sptr_t>("JetBrains Mono"));
    Send(doc.editor, SCI_STYLESETSIZEFRACTIONAL, STYLE_DEFAULT, 1300);
    [self theme:doc];
    doc.editor.delegate = self;
    doc.tab = [[NSTabViewItem alloc] initWithIdentifier:doc.identifier];
    doc.tab.label = doc.title; doc.tab.view = doc.editor;
    [self.documents addObject:doc]; [self.tabs addTabViewItem:doc.tab]; [self.tabs selectTabViewItem:doc.tab];
    [self.window makeFirstResponder:doc.editor];
    return doc;
}
- (void)theme:(NXDocument *)doc {
    int back = self.dark ? 0x26211c : 0xffffff;
    int fore = self.dark ? 0xefece8 : 0x282828;
    Send(doc.editor, SCI_STYLESETBACK, STYLE_DEFAULT, back);
    Send(doc.editor, SCI_STYLESETFORE, STYLE_DEFAULT, fore);
    Send(doc.editor, SCI_STYLECLEARALL);
    Send(doc.editor, SCI_STYLESETFORE, STYLE_LINENUMBER, self.dark ? 0xaaa299 : 0x777777);
    Send(doc.editor, SCI_SETCARETFORE, self.dark ? 0xc5d9ff : 0x222222);
    Send(doc.editor, SCI_SETSELBACK, 1, self.dark ? 0x765637 : 0xeedbb7);
    Send(doc.editor, SCI_SETSELFORE, 0, 0);
    [self configureLexer:doc];
}
- (void)configureLexer:(NXDocument *)doc {
    auto *lexer = CreateLexer(doc.lexer.UTF8String);
    Send(doc.editor, SCI_SETILEXER, 0, reinterpret_cast<sptr_t>(lexer));
    // Common lexer styles; users can select any bundled Lexilla lexer.
    if ([doc.lexer isEqual:@"cpp"] || [doc.lexer isEqual:@"python"]) {
        const char *keywords = [doc.lexer isEqual:@"python"] ?
            "False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield" :
            "alignas auto bool break case catch char class const constexpr continue default delete do double else enum explicit extern false float for friend if inline int long namespace new nullptr operator private protected public return short signed sizeof static struct switch template this throw true try typedef typename union unsigned using virtual void volatile while export import function let var async await function return typeof null undefined";
        Send(doc.editor, SCI_SETKEYWORDS, 0, reinterpret_cast<sptr_t>(keywords));
        Send(doc.editor, SCI_STYLESETFORE, 1, self.dark ? 0x88aa88 : 0x337733);
        Send(doc.editor, SCI_STYLESETFORE, 2, self.dark ? 0x88aa88 : 0x337733);
        Send(doc.editor, SCI_STYLESETFORE, 5, self.dark ? 0xe6bfa0 : 0xa04060);
        Send(doc.editor, SCI_STYLESETFORE, 6, self.dark ? 0x9ac8df : 0x226699);
    }
    Send(doc.editor, SCI_COLOURISE, 0, -1);
}
- (void)notification:(SCNotification *)notification {
    if (!self.restoring && notification->nmhdr.code == SCN_UPDATEUI) [self updateControls];
}
- (void)updateControls {
    NXDocument *doc = self.current;
    if (!doc) return;
    // Leave the active field editor alone while a font value is being entered.
    if (self.window.firstResponder == self.family.currentEditor || self.window.firstResponder == self.size.currentEditor) return;
    NoteX::SelectionFormat query;
    query.start = Send(doc.editor, SCI_GETSELECTIONSTART); query.end = Send(doc.editor, SCI_GETSELECTIONEND);
    Send(doc.editor, NoteX::GetFormat, 0, reinterpret_cast<sptr_t>(&query));
    self.family.stringValue = (query.value.mask & NoteX::Family) ? @(query.value.family.c_str()) : @"JetBrains Mono";
    self.size.stringValue = [NSString stringWithFormat:@"%g", (query.value.mask & NoteX::Size) ? query.value.size / 100.0 : 13.0];
    [self.language selectItemWithTitle:[doc.lexer isEqual:@"null"] ? @"Plain Text" : doc.lexer];
    self.window.title = [NSString stringWithFormat:@"%@%@ — NoteX", doc.title, doc.dirty ? @" •" : @""];
    if (!self.snapshotFailed) self.status.stringValue = [NSString stringWithFormat:@"  Line %ld   Column %ld   %@   %lu characters",
        (long)Send(doc.editor, SCI_LINEFROMPOSITION, Send(doc.editor, SCI_GETCURRENTPOS)) + 1,
        (long)Send(doc.editor, SCI_GETCOLUMN, Send(doc.editor, SCI_GETCURRENTPOS)) + 1,
        doc.encoding == NSUTF8StringEncoding ? @"UTF-8" : @"UTF-16", (unsigned long)doc.editor.string.length];
}
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    [self updateControls];
    [self.window makeFirstResponder:self.current.editor];
}
- (BOOL)snapshot:(NSError **)error {
    if (self.restoring) return YES;
    NSMutableArray *documents = [NSMutableArray new];
    for (NXDocument *doc in self.documents) [documents addObject:doc.record];
    NSDictionary *session = @{@"schema":@1, @"documents":documents,
        @"selected":@([self.tabs indexOfTabViewItem:self.tabs.selectedTabViewItem]), @"dark":@(self.dark), @"wrap":@(self.wrap)};
    if ([session isEqual:self.lastSnapshot]) return YES;
    if (![self.storage save:session error:error]) return NO;
    self.lastSnapshot = session;
    return YES;
}
- (void)tick:(id)sender {
    NSError *error = nil;
    self.snapshotFailed = ![self snapshot:&error];
    if (self.snapshotFailed) self.status.stringValue = [@"Recovery snapshot failed: " stringByAppendingString:error.localizedDescription];
    for (NXDocument *doc in self.documents) doc.tab.label = [doc.title stringByAppendingString:doc.dirty ? @" •" : @""];
    [self updateControls];
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
    NSError *error = nil;
    if (![self snapshot:&error]) { Alert(error.localizedDescription); return NSTerminateCancel; }
    return NSTerminateNow;
}
- (BOOL)windowShouldClose:(NSWindow *)window { [NSApp terminate:nil]; return NO; }
- (void)applicationDidResignActive:(NSNotification *)notification { [self tick:nil]; }
- (BOOL)application:(NSApplication *)application openFile:(NSString *)filename {
    if (!self.window) {
        if (!self.pendingFiles) self.pendingFiles = [NSMutableArray new];
        [self.pendingFiles addObject:filename];
        return YES;
    }
    NSError *error = nil;
    BOOL ok = [self openPath:filename error:&error];
    if (!ok) Alert(error.localizedDescription);
    return ok;
}
- (BOOL)openPath:(NSString *)path error:(NSError **)error {
    for (NXDocument *existing in self.documents) if ([existing.path isEqual:path]) { [self.tabs selectTabViewItem:existing.tab]; return YES; }
    NSData *disk = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!disk) return NO;
    NSStringEncoding encoding = NSUTF8StringEncoding; BOOL bom = NO;
    NSData *content = disk;
    const auto *bytes = static_cast<const unsigned char *>(disk.bytes);
    if (disk.length >= 3 && !memcmp(bytes, "\xef\xbb\xbf", 3)) { content = [disk subdataWithRange:NSMakeRange(3, disk.length - 3)]; bom = YES; }
    else if (disk.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) { encoding = NSUTF16LittleEndianStringEncoding; bom = YES; content = [disk subdataWithRange:NSMakeRange(2, disk.length - 2)]; }
    else if (disk.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) { encoding = NSUTF16BigEndianStringEncoding; bom = YES; content = [disk subdataWithRange:NSMakeRange(2, disk.length - 2)]; }
    NSString *string = [[NSString alloc] initWithData:content encoding:encoding];
    if (!string || [string rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound) {
        if (error) *error = NXError(@"This file is not UTF-8 or BOM-marked UTF-16 text. It has not been modified."); return NO;
    }
    NXDocument *doc = [self newDocument:nil];
    doc.path = path; doc.title = path.lastPathComponent; doc.encoding = encoding; doc.bom = bom; doc.diskHash = NXDigest(disk);
    SetText(doc.editor, [string dataUsingEncoding:NSUTF8StringEncoding]);
    Send(doc.editor, SCI_SETEOLMODE, [string containsString:@"\r\n"] ? SC_EOL_CRLF : SC_EOL_LF);
    NSDictionary *lexers = @{@"c":@"cpp", @"h":@"cpp", @"cc":@"cpp", @"cpp":@"cpp", @"hpp":@"cpp", @"m":@"cpp", @"mm":@"cpp", @"js":@"cpp", @"ts":@"cpp", @"java":@"cpp", @"py":@"python", @"json":@"json", @"xml":@"xml", @"html":@"html", @"css":@"css", @"md":@"markdown", @"sh":@"bash", @"sql":@"sql", @"yaml":@"yaml", @"yml":@"yaml", @"swift":@"swift", @"rs":@"rust"};
    doc.lexer = lexers[path.pathExtension.lowercaseString] ?: @"null";
    [self configureLexer:doc];
    NSString *sidecar = [path stringByAppendingString:@".notex"];
    if (![NSFileManager.defaultManager fileExistsAtPath:sidecar]) {
        auto old = NoteX::previousSidecarExtension();
        std::string extension(old.begin(), old.end());
        sidecar = [path stringByAppendingString:@(extension.c_str())];
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:sidecar]) {
        NSData *data = [NSData dataWithContentsOfFile:sidecar];
        NoteX::State state;
        if (NXReadCompanion(data, Text(doc.editor), state)) Restore(doc.editor, std::move(state));
        else Alert(@"The formatting companion does not match this document or could not be read. The text was opened without applying it; the companion was preserved.");
    }
    Send(doc.editor, SCI_EMPTYUNDOBUFFER); Send(doc.editor, SCI_SETSAVEPOINT);
    [self tick:nil];
    return YES;
}
- (void)open:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel]; panel.allowsMultipleSelection = YES;
    if ([panel runModal] != NSModalResponseOK) return;
    for (NSURL *url in panel.URLs) { NSError *error = nil; if (![self openPath:url.path error:&error]) Alert(error.localizedDescription); }
}
- (BOOL)saveDocument:(NXDocument *)doc path:(NSString *)path error:(NSError **)error {
    // A recovery snapshot precedes the two-file save; failures leave the tab dirty.
    if (![self snapshot:error]) return NO;
    if ([path isEqual:doc.path]) {
        NSData *existing = [NSData dataWithContentsOfFile:path options:0 error:error];
        if (!existing || ![NXDigest(existing) isEqual:doc.diskHash]) {
            if (error) *error = NXError(@"The file changed outside NoteX or is no longer readable. Use Save As to preserve your edits without overwriting it."); return NO;
        }
    }
    NSString *companion = [path stringByAppendingString:@".notex"];
    if ([NSFileManager.defaultManager fileExistsAtPath:companion] && !NXOwnedCompanion([NSData dataWithContentsOfFile:companion])) {
        if (error) *error = NXError(@"An unrelated file occupies the .notex companion path. Neither file was overwritten. Choose another filename."); return NO;
    }
    NSData *text = Text(doc.editor);
    NSString *string = [[NSString alloc] initWithData:text encoding:NSUTF8StringEncoding];
    NSData *encoded = [string dataUsingEncoding:doc.encoding allowLossyConversion:NO];
    if (!encoded) { if (error) *error = NXError(@"The text cannot be represented in the selected encoding."); return NO; }
    NSMutableData *disk = [NSMutableData new];
    if (doc.bom) {
        if (doc.encoding == NSUTF8StringEncoding) [disk appendBytes:"\xef\xbb\xbf" length:3];
        else if (doc.encoding == NSUTF16LittleEndianStringEncoding) [disk appendBytes:"\xff\xfe" length:2];
        else [disk appendBytes:"\xfe\xff" length:2];
    }
    [disk appendData:encoded];
    if (!NXWrite(disk, path, error)) return NO;
    doc.path = path; doc.title = path.lastPathComponent; doc.diskHash = NXDigest(disk); doc.restoredDirty = YES;
    if (!NXWrite(NXCompanion(text, State(doc.editor)), companion, error)) return NO;
    Send(doc.editor, SCI_SETSAVEPOINT); doc.restoredDirty = NO;
    [self tick:nil];
    return YES;
}
- (BOOL)saveCurrentAs:(BOOL)saveAs {
    NXDocument *doc = self.current;
    NSString *path = doc.path;
    if (saveAs || !path.length) {
        NSSavePanel *panel = [NSSavePanel savePanel]; panel.nameFieldStringValue = doc.title;
        if ([panel runModal] != NSModalResponseOK) return NO;
        path = panel.URL.path;
    }
    NSError *error = nil;
    if (![self saveDocument:doc path:path error:&error]) { Alert(error.localizedDescription); return NO; }
    return YES;
}
- (void)save:(id)sender { [self saveCurrentAs:NO]; }
- (void)saveAs:(id)sender { [self saveCurrentAs:YES]; }
- (void)closeTab:(id)sender {
    NXDocument *doc = self.current;
    if (doc.dirty) {
        NSAlert *alert = [NSAlert new]; alert.messageText = [NSString stringWithFormat:@"Save changes to %@?", doc.title];
        alert.informativeText = @"Closing this tab discards its unsaved changes. Quitting NoteX instead preserves open tabs for your next session.";
        [alert addButtonWithTitle:@"Save"]; [alert addButtonWithTitle:@"Cancel"]; [alert addButtonWithTitle:@"Discard"];
        auto response = [alert runModal];
        if (response == NSAlertSecondButtonReturn || (response == NSAlertFirstButtonReturn && ![self saveCurrentAs:NO])) return;
    }
    NSError *error = nil;
    if (![self snapshot:&error]) { Alert(error.localizedDescription); return; }
    [self.tabs removeTabViewItem:doc.tab]; [self.documents removeObject:doc];
    if (!self.documents.count) [self newDocument:nil];
    [self tick:nil];
}
- (void)apply:(NoteX::Format)format fields:(unsigned)fields {
    auto *view = self.current.editor;
    NoteX::Change change; change.start = Send(view, SCI_GETSELECTIONSTART); change.end = Send(view, SCI_GETSELECTIONEND);
    change.value = format; change.fields = fields;
    Send(view, NoteX::ApplyFormat, 0, reinterpret_cast<sptr_t>(&change));
    [self.window makeFirstResponder:view]; [self tick:nil];
}
- (void)toggleFormat:(id)sender {
    unsigned field = static_cast<unsigned>([sender tag]);
    NoteX::SelectionFormat query; auto *view = self.current.editor;
    query.start = Send(view, SCI_GETSELECTIONSTART); query.end = Send(view, SCI_GETSELECTIONEND);
    Send(view, NoteX::GetFormat, 0, reinterpret_cast<sptr_t>(&query));
    NoteX::Format format = query.value; format.mask |= field;
    bool mixed = query.mixed & field;
    if (field == NoteX::Bold) format.bold = mixed || !format.bold;
    if (field == NoteX::Italic) format.italic = mixed || !format.italic;
    if (field == NoteX::Underline) format.underline = mixed || !format.underline;
    if (field == NoteX::Strike) format.strike = mixed || !format.strike;
    [self apply:format fields:field];
}
- (void)changeFamily:(id)sender {
    if (![NSFontManager.sharedFontManager.availableFontFamilies containsObject:self.family.stringValue]) { NSBeep(); return; }
    NoteX::Format format; format.mask = NoteX::Family; format.family = self.family.stringValue.UTF8String;
    [self apply:format fields:NoteX::Family];
}
- (void)changeSize:(id)sender {
    double size = self.size.doubleValue;
    if (!std::isfinite(size) || size < 6 || size > 96) { NSBeep(); return; }
    NoteX::Format format; format.mask = NoteX::Size; format.size = static_cast<int>(size * 100);
    [self apply:format fields:NoteX::Size];
}
- (void)clearFormat:(id)sender { [self apply:NoteX::Format{} fields:NoteX::All]; }
- (void)pickColor:(id)sender {
    self.colorField = static_cast<unsigned>([sender tag]);
    NSColorPanel *panel = NSColorPanel.sharedColorPanel; panel.target = self; panel.action = @selector(changeColor:);
    panel.continuous = NO; panel.showsAlpha = NO; [panel orderFront:nil];
}
- (void)changeColor:(NSColorPanel *)panel {
    NSColor *color = [panel.color colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    unsigned rgb = (unsigned)lround(color.redComponent * 255) | ((unsigned)lround(color.greenComponent * 255) << 8) | ((unsigned)lround(color.blueComponent * 255) << 16);
    NoteX::Format format; format.mask = self.colorField;
    if (self.colorField == NoteX::Fore) format.fore = rgb; else format.highlight = rgb;
    [self apply:format fields:self.colorField];
}
- (void)makeList:(id)sender {
    auto *view = self.current.editor;
    auto first = Send(view, SCI_LINEFROMPOSITION, Send(view, SCI_GETSELECTIONSTART));
    auto last = Send(view, SCI_LINEFROMPOSITION, Send(view, SCI_GETSELECTIONEND));
    Send(view, SCI_BEGINUNDOACTION);
    for (auto line = last; line >= first; --line) {
        NSString *prefix = [sender tag] ? [NSString stringWithFormat:@"%ld. ", (long)(line - first + 1)] : @"• ";
        Send(view, SCI_INSERTTEXT, Send(view, SCI_POSITIONFROMLINE, line), reinterpret_cast<sptr_t>(prefix.UTF8String));
    }
    Send(view, SCI_ENDUNDOACTION); [self tick:nil];
}
- (void)changeLanguage:(id)sender { self.current.lexer = self.language.indexOfSelectedItem == 0 ? @"null" : self.language.titleOfSelectedItem; [self configureLexer:self.current]; }
- (void)toggleWrap:(id)sender { self.wrap = !self.wrap; for (NXDocument *doc in self.documents) Send(doc.editor, SCI_SETWRAPMODE, self.wrap ? SC_WRAP_WORD : SC_WRAP_NONE); }
- (void)toggleDark:(id)sender {
    self.dark = !self.dark;
    self.window.appearance = [NSAppearance appearanceNamed:self.dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
    for (NXDocument *doc in self.documents) [self theme:doc];
}
- (void)editorCommand:(id)sender { Send(self.current.editor, static_cast<unsigned>([sender tag])); }
- (void)nextTab:(id)sender {
    NSInteger index = [self.tabs indexOfTabViewItem:self.tabs.selectedTabViewItem];
    index = (index + [sender tag] + self.documents.count) % self.documents.count;
    [self.tabs selectTabViewItemAtIndex:index];
}
- (void)showFind:(id)sender { self.findBar.hidden = NO; [self.window makeFirstResponder:self.findText]; }
- (void)hideFind:(id)sender { self.findBar.hidden = YES; [self.window makeFirstResponder:self.current.editor]; }
- (void)findNext:(id)sender {
    if (!self.findText.stringValue.length) { [self showFind:nil]; return; }
    if (![self.current.editor findAndHighlightText:self.findText.stringValue matchCase:NO wholeWord:NO scrollTo:YES wrap:YES]) NSBeep();
}
- (void)replace:(id)sender {
    if (!self.findText.stringValue.length) return;
    [self.current.editor findAndReplaceText:self.findText.stringValue byText:self.replaceText.stringValue matchCase:NO wholeWord:NO doAll:[sender tag] != 0];
    [self tick:nil];
}
- (void)goToLine:(id)sender {
    NSAlert *alert = [NSAlert new]; alert.messageText = @"Go to Line";
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)]; field.stringValue = @"1";
    alert.accessoryView = field; [alert addButtonWithTitle:@"Go"]; [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) Send(self.current.editor, SCI_GOTOLINE, std::max<NSInteger>(0, field.integerValue - 1));
}
- (void)about:(id)sender {
    [NSApp orderFrontStandardAboutPanelWithOptions:@{NSAboutPanelOptionApplicationName:@"NoteX",
        NSAboutPanelOptionApplicationVersion:@"1.3.2 — Native macOS Preview 1",
        NSAboutPanelOptionCredits:[[NSAttributedString alloc] initWithString:@"Native AppKit • Scintilla • Lexilla\nCopyright © 2026 Berk Kivircik and contributors.\nGNU General Public License version 3.\nSee Help for source, licensing, and preview limitations."]}];
}
- (void)showSession:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:self.storage.directory]]; }
- (void)guide:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSBundle.mainBundle URLForResource:@"README" withExtension:@"md"]]; }
- (void)source:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/berkkivircik/NoteX"]]; }
@end

#include "SelfTest.inc"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NXApp *delegate = [NXApp new];
        NSApp.delegate = delegate;
        [NSApp run];
    }
    return 0;
}
