//
//  TaskRunner.h
//  TaskRunner
//
//  Created by Jakob Egger on 2020-05-07.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "PGConnection.h"

NS_ASSUME_NONNULL_BEGIN

@interface TaskRunner : NSObject {
	PGConnection *connection;
	NSURL *workdir;
	NSArray<NSString*> *toolchains;
	NSString *toolchainString;
	NSString *agentIdentifier;
	int agentID;
	int currentTaskId;
	NSString *currentTaskScript;
	NSString *currentTaskUserInfoString;
	NSTask *task;
	NSPipe *task_stdout;
	NSPipe *task_stderr;
	dispatch_source_t stdout_src;
	dispatch_source_t stderr_src;
}

@property BOOL isRunning;
@property IBOutlet NSTextView *logTextView;
@property(nullable) NSString *currentTaskLabel;

-(IBAction)start:(id)sender;
-(IBAction)getNextTask:(id)sender;
-(IBAction)stop:(id)sender;

-(void)logLine:(NSString*)line;

@end

NS_ASSUME_NONNULL_END
