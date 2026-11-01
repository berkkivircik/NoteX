// Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
// Native menu visibility and order editor, created 2026-11-01.
#import "MenuLayout.h"
#import "Storage.h"

@implementation NXMenuLayout {
    NSMenu *_canonical;
    NSDictionary *_settings;
    NSMutableDictionary *_draft;
    NSArray *_nodes;
    NSOutlineView *_tree;
    NSWindow *_dialog;
}
static BOOL ValidLayout(NSDictionary *value) {
    if (![value isKindOfClass:NSDictionary.class] || ![value[@"order"] isKindOfClass:NSDictionary.class] ||
        ![value[@"hidden"] isKindOfClass:NSArray.class] || [value[@"hidden"] count] > 5000) return NO;
    for (id key in value[@"order"]) {
        id order = value[@"order"][key];
        if (![key isKindOfClass:NSString.class] || ![order isKindOfClass:NSArray.class] || [order count] > 1000) return NO;
        for (id item in order) if (![item isKindOfClass:NSString.class]) return NO;
    }
    for (id item in value[@"hidden"]) if (![item isKindOfClass:NSString.class]) return NO;
    return YES;
}
- (NSArray *)nodesForMenu:(NSMenu *)menu parent:(NSString *)parent {
    NSMutableArray *result = [NSMutableArray new];
    for (NSMenuItem *item in menu.itemArray) {
        if (item.separatorItem) continue;
        // AppKit injects system-only commands (for example Dictation) at runtime.
        // They cannot be recreated as ordinary application menu items.
        if (item.keyEquivalentModifierMask & NSEventModifierFlagFunction) continue;
        // Keys do not depend on translated display labels for executable commands.
        NSString *local = item.submenu ? [@"menu:" stringByAppendingString:item.title] :
            [NSString stringWithFormat:@"%@:%ld", NSStringFromSelector(item.action) ?: item.title, (long)item.tag];
        NSString *key = [parent stringByAppendingFormat:@"/%@", local];
        BOOL locked = ([parent isEqual:@""] && result.count == 0) ||
            item.action == @selector(terminate:) || item.action == NSSelectorFromString(@"customizeMenus:") ||
            item.action == NSSelectorFromString(@"resetMenus:");
        [result addObject:@{@"key":key, @"parent":parent, @"title":item.title, @"locked":@(locked),
            @"item":item, @"children":item.submenu ? [self nodesForMenu:item.submenu parent:key] : @[]}];
    }
    return result;
}
- (instancetype)initWithMenu:(NSMenu *)menu settings:(NSDictionary *)settings {
    self = [super init];
    if (self) {
        _canonical = menu;
        _nodes = [self nodesForMenu:menu parent:@""];
        _settings = ValidLayout(settings) ? [settings copy] : @{@"order":@{}, @"hidden":@[]};
    }
    return self;
}
- (NSDictionary *)settings { return _settings; }
- (NSArray *)ordered:(NSArray *)nodes parent:(NSString *)parent layout:(NSDictionary *)layout {
    NSMutableArray *ordered = [NSMutableArray new];
    if (!parent.length && nodes.count) [ordered addObject:nodes[0]]; // macOS application menu stays first.
    for (NSString *key in layout[@"order"][parent]) for (NSDictionary *node in nodes)
        if ([node[@"key"] isEqual:key] && ![ordered containsObject:node]) [ordered addObject:node];
    for (NSDictionary *node in nodes) if (![ordered containsObject:node]) [ordered addObject:node];
    return ordered;
}
- (NSMenu *)render:(NSArray *)nodes parent:(NSString *)parent {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    for (NSDictionary *node in [self ordered:nodes parent:parent layout:_settings]) {
        if (![node[@"locked"] boolValue] && [_settings[@"hidden"] containsObject:node[@"key"]]) continue;
        NSMenuItem *source = node[@"item"];
        NSMenuItem *copy = [[NSMenuItem alloc] initWithTitle:source.title action:source.action keyEquivalent:source.keyEquivalent];
        copy.target = source.target; copy.tag = source.tag; copy.keyEquivalentModifierMask = source.keyEquivalentModifierMask;
        copy.state = source.state; copy.enabled = source.enabled; copy.representedObject = source.representedObject;
        copy.identifier = node[@"key"];
        if (source.submenu) {
            copy.submenu = [self render:node[@"children"] parent:node[@"key"]];
            if (!copy.submenu.numberOfItems) continue;
        }
        [menu addItem:copy];
    }
    return menu;
}
- (void)apply { NSApp.mainMenu = [self render:_nodes parent:@""]; }
- (BOOL)setLayout:(NSDictionary *)settings error:(NSError **)error {
    if (!ValidLayout(settings)) { if (error) *error = NXError(@"The menu layout is invalid."); return NO; }
    NSDictionary *previous = _settings;
    _settings = [settings copy];
    if (self.commit && !self.commit(error)) { _settings = previous; return NO; }
    [self apply]; return YES;
}
- (void)reset {
    NSError *error = nil;
    if (![self setLayout:@{@"order":@{}, @"hidden":@[]} error:&error]) [NSApp presentError:error];
}
- (NSArray *)children:(NSDictionary *)node {
    return [self ordered:node ? node[@"children"] : _nodes parent:node ? node[@"key"] : @"" layout:_draft];
}
- (NSInteger)outlineView:(NSOutlineView *)outline numberOfChildrenOfItem:(id)item { return [self children:item].count; }
- (id)outlineView:(NSOutlineView *)outline child:(NSInteger)index ofItem:(id)item { return [self children:item][index]; }
- (BOOL)outlineView:(NSOutlineView *)outline isItemExpandable:(id)item { return [item[@"children"] count] > 0; }
- (NSView *)outlineView:(NSOutlineView *)outline viewForTableColumn:(NSTableColumn *)column item:(id)item {
    if ([column.identifier isEqual:@"show"]) {
        NSButton *button = [NSButton checkboxWithTitle:@"" target:self action:@selector(toggle:)];
        button.identifier = item[@"key"];
        button.state = [_draft[@"hidden"] containsObject:item[@"key"]] && ![item[@"locked"] boolValue] ? NSControlStateValueOff : NSControlStateValueOn;
        button.enabled = ![item[@"locked"] boolValue];
        return button;
    }
    return [NSTextField labelWithString:item[@"title"]];
}
- (void)toggle:(NSButton *)button {
    NSMutableArray *hidden = [_draft[@"hidden"] mutableCopy];
    [hidden removeObject:button.identifier];
    if (button.state == NSControlStateValueOff) [hidden addObject:button.identifier];
    _draft[@"hidden"] = hidden;
}
- (NSDictionary *)find:(NSString *)key nodes:(NSArray *)nodes {
    for (NSDictionary *node in nodes) {
        if ([node[@"key"] isEqual:key]) return node;
        NSDictionary *found = [self find:key nodes:node[@"children"]];
        if (found) return found;
    }
    return nil;
}
- (void)move:(NSButton *)sender {
    NSDictionary *node = [_tree itemAtRow:_tree.selectedRow];
    if (!node || [node[@"locked"] boolValue]) return;
    NSString *parent = node[@"parent"];
    NSDictionary *parentNode = parent.length ? [self find:parent nodes:_nodes] : nil;
    NSMutableArray *siblings = [[self children:parentNode] mutableCopy];
    NSInteger position = [siblings indexOfObject:node], next = position + sender.tag;
    if (next < 0 || next >= (NSInteger)siblings.count || [siblings[next][@"locked"] boolValue]) return;
    [siblings exchangeObjectAtIndex:position withObjectAtIndex:next];
    NSMutableDictionary *order = [_draft[@"order"] mutableCopy];
    order[parent] = [siblings valueForKey:@"key"]; _draft[@"order"] = order;
    [_tree reloadData]; [_tree expandItem:nil expandChildren:YES];
    [_tree selectRowIndexes:[NSIndexSet indexSetWithIndex:[_tree rowForItem:node]] byExtendingSelection:NO];
}
- (void)resetDraft:(id)sender { _draft = [@{@"order":@{}, @"hidden":@[]} mutableCopy]; [_tree reloadData]; }
- (void)accept:(id)sender {
    NSError *error = nil;
    if (![self setLayout:_draft error:&error]) { [NSApp presentError:error]; return; }
    [NSApp stopModal]; [_dialog orderOut:nil];
}
- (void)cancel:(id)sender { [NSApp abortModal]; [_dialog orderOut:nil]; }
- (void)customizeForWindow:(NSWindow *)window {
    _draft = [_settings mutableCopy];
    _dialog = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 520) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    _dialog.title = @"Customize Menus"; _dialog.appearance = window.appearance;
    NSTextField *help = [NSTextField wrappingLabelWithString:@"Choose visible commands and reorder menus or commands with Move Up / Move Down. The NoteX menu, Quit, and layout recovery commands remain available."];
    help.frame = NSMakeRect(16, 456, 568, 48); [_dialog.contentView addSubview:help];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 68, 568, 380)]; scroll.hasVerticalScroller = YES;
    _tree = [[NSOutlineView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *title = [[NSTableColumn alloc] initWithIdentifier:@"title"]; title.title = @"Menu or Command"; title.width = 460;
    NSTableColumn *show = [[NSTableColumn alloc] initWithIdentifier:@"show"]; show.title = @"Show"; show.width = 60;
    [_tree addTableColumn:title]; [_tree addTableColumn:show]; _tree.outlineTableColumn = title; _tree.delegate = self; _tree.dataSource = self;
    scroll.documentView = _tree; [_dialog.contentView addSubview:scroll];
    NSArray *names = @[@"Move Up", @"Move Down", @"Reset", @"Cancel", @"Apply"];
    SEL actions[] = {@selector(move:), @selector(move:), @selector(resetDraft:), @selector(cancel:), @selector(accept:)};
    for (NSUInteger i = 0; i < names.count; ++i) {
        NSButton *button = [NSButton buttonWithTitle:names[i] target:self action:actions[i]];
        button.frame = NSMakeRect(16 + i * 114, 20, 108, 32); button.tag = i == 0 ? -1 : 1;
        if (i == 4) button.keyEquivalent = @"\r";
        if (i == 3) button.keyEquivalent = @"\e";
        [_dialog.contentView addSubview:button];
    }
    [_tree reloadData]; [_tree expandItem:nil expandChildren:YES];
    [_dialog center]; [NSApp runModalForWindow:_dialog];
    _dialog = nil; _tree = nil; _draft = nil;
}
@end
