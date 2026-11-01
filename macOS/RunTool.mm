// Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
// Commands run only after an explicit Run action; output is bounded in memory.
#import "RunTool.h"
#import "Storage.h"
@implementation NXRunTool {
    NSTextField *_name,*_command,*_status;
    NSPopUpButton *_saved;
    NSTextView *_outputView;
    NSButton *_run,*_stop;
    NSPipe *_pipe;
}
- (instancetype)init {return [super initWithWindow:nil];}
- (BOOL)launchCommand:(NSString *)command environment:(NSDictionary *)environment error:(NSError **)error {
    if(self.task.running){if(error)*error=NXError(@"A command is already running. Stop it before starting another.");return NO;}
    if(!command.length||command.length>65536){if(error)*error=NXError(@"Enter a command of at most 65,536 characters.");return NO;}
    self.captured=[NSMutableData new];self.output=@"";self.task=[NSTask new];self.task.executableURL=[NSURL fileURLWithPath:@"/bin/zsh"];self.task.arguments=@[@"-lc",command];
    NSMutableDictionary *variables=[NSProcessInfo.processInfo.environment mutableCopy];[variables addEntriesFromDictionary:environment ?: @{}];self.task.environment=variables;
    if([environment[@"NOTEX_DIRECTORY"] length])self.task.currentDirectoryURL=[NSURL fileURLWithPath:environment[@"NOTEX_DIRECTORY"]];
    _pipe=[NSPipe pipe];self.task.standardOutput=_pipe;self.task.standardError=_pipe;self.task.standardInput=NSFileHandle.fileHandleWithNullDevice;
    __weak NXRunTool *owner=self;
    _pipe.fileHandleForReading.readabilityHandler=^(NSFileHandle *handle){NSData *data=handle.availableData;if(!data.length){handle.readabilityHandler=nil;return;}NXRunTool *strong=owner;if(!strong)return;@synchronized(strong){NSUInteger available=strong.captured.length<1024*1024?1024*1024-strong.captured.length:0;if(available)[strong.captured appendData:[data subdataWithRange:NSMakeRange(0,MIN(data.length,available))]];}};
    self.task.terminationHandler=^(NSTask *task){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NXRunTool *strong=owner;if(!strong)return;
        // Never wait for EOF on the UI thread: a child may retain the pipe.
        strong->_pipe.fileHandleForReading.readabilityHandler=nil;
        @synchronized(strong){strong.output=[[NSString alloc]initWithData:strong.captured encoding:NSUTF8StringEncoding] ?: @"The command produced non-UTF-8 output.";}
        dispatch_async(dispatch_get_main_queue(),^{strong->_outputView.string=strong.output;strong->_status.stringValue=[NSString stringWithFormat:@"Exit status: %d%@",task.terminationStatus,strong.captured.length>=1024*1024?@" — output limited to 1 MB":@""];strong->_run.enabled=YES;strong->_stop.enabled=NO;});
    });};
    if(![self.task launchAndReturnError:error]){_pipe.fileHandleForReading.readabilityHandler=nil;return NO;}_run.enabled=NO;_stop.enabled=YES;_status.stringValue=@"Running…";return YES;
}
- (void)run:(id)sender {NSError *error=nil;if(![self launchCommand:_command.stringValue environment:self.documentEnvironment?self.documentEnvironment():@{} error:&error])[NSApp presentError:error];}
- (void)stop:(id)sender {if(self.task.running)[self.task terminate];}
- (void)select:(id)sender {NSInteger index=_saved.indexOfSelectedItem-1;if(index>=0){_name.stringValue=self.commands[index][@"name"];_command.stringValue=self.commands[index][@"command"];}else{_name.stringValue=@"";_command.stringValue=@"";}}
- (void)refresh {[_saved removeAllItems];[_saved addItemWithTitle:@"New Command"];for(NSDictionary *command in self.commands)[_saved addItemWithTitle:command[@"name"]];}
- (void)save:(id)sender {
    NSString *name=[_name.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!name.length||name.length>100||!_command.stringValue.length){[NSApp presentError:NXError(@"Enter a name of at most 100 characters and a command.")];return;}
    NSMutableArray *commands=[self.commands mutableCopy] ?: [NSMutableArray new];NSInteger selected=_saved.indexOfSelectedItem-1;
    for(NSUInteger i=0;i<commands.count;++i)if((NSInteger)i!=selected&&[commands[i][@"name"] caseInsensitiveCompare:name]==NSOrderedSame){[NSApp presentError:NXError(@"Choose a unique command name.")];return;}
    NSDictionary *record=@{@"name":name,@"command":_command.stringValue};if(selected>=0)commands[selected]=record;else [commands addObject:record];
    if(self.saveCommands&&self.saveCommands(commands)){self.commands=commands;[self refresh];[_saved selectItemWithTitle:name];}
}
- (void)remove:(id)sender {NSInteger index=_saved.indexOfSelectedItem-1;if(index<0)return;NSMutableArray *commands=[self.commands mutableCopy];[commands removeObjectAtIndex:index];if(self.saveCommands&&self.saveCommands(commands)){self.commands=commands;[self refresh];[self select:nil];}}
- (void)showForWindow:(NSWindow *)parent {
    if(!self.window){self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,720,480) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];self.window.releasedWhenClosed=NO;self.window.title=@"Run Command";
        _saved=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(16,432,688,28) pullsDown:NO];_saved.target=self;_saved.action=@selector(select:);[self.window.contentView addSubview:_saved];
        _name=[[NSTextField alloc]initWithFrame:NSMakeRect(16,394,688,26)];_name.placeholderString=@"Command name";[self.window.contentView addSubview:_name];
        _command=[[NSTextField alloc]initWithFrame:NSMakeRect(16,356,688,26)];_command.placeholderString=@"Shell command (zsh)";[self.window.contentView addSubview:_command];
        NSTextField *help=[NSTextField wrappingLabelWithString:@"Commands run in zsh. Use quoted environment variables such as \"$NOTEX_FILE\", \"$NOTEX_DIRECTORY\", \"$NOTEX_SELECTION\", and \"$NOTEX_LINE\". Selecting or saving a command does not run it."];help.frame=NSMakeRect(16,290,688,56);[self.window.contentView addSubview:help];
        NSArray *names=@[@"Run",@"Stop",@"Save Command",@"Delete Command"];SEL actions[]={@selector(run:),@selector(stop:),@selector(save:),@selector(remove:)};
        for(NSUInteger i=0;i<names.count;++i){NSButton *button=[NSButton buttonWithTitle:names[i] target:self action:actions[i]];button.frame=NSMakeRect(16+i*170,250,160,32);[self.window.contentView addSubview:button];if(i==0)_run=button;if(i==1){_stop=button;button.enabled=NO;}}
        NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(16,48,688,190)];scroll.hasVerticalScroller=YES;_outputView=[[NSTextView alloc]initWithFrame:scroll.bounds];_outputView.editable=NO;_outputView.font=[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];scroll.documentView=_outputView;[self.window.contentView addSubview:scroll];
        _status=[NSTextField labelWithString:@"Ready"];_status.frame=NSMakeRect(16,12,688,26);[self.window.contentView addSubview:_status];[self refresh];[self.window center];
    }self.window.appearance=parent.appearance;[self.window makeKeyAndOrderFront:nil];
}
@end
