//
//  TaskRunner.m
//  TaskRunner
//
//  Created by Jakob Egger on 2020-05-07.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import "TaskRunner.h"

@implementation TaskRunner

-(IBAction)start:(id)sender {
	_logTextView.string = @"Starting…\n";
	[_logTextView didChangeText];
	[_logTextView setNeedsDisplay:YES];
	
	[[sender window] makeFirstResponder:nil];
	self.isRunning = YES;
	
	agentIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"AgentIdentifier"];
	if (!agentIdentifier) {
		[self presentMessage:@"Parameter missing" informativeText:@"Please provide a unique string as agent identifier."];
		self.isRunning = NO;
		return;
	}
	
	toolchains = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"Toolchains"];
	if (!toolchains) {
		[self presentMessage:@"Parameter missing" informativeText:@"Please provide at least one toolchain."];
		self.isRunning = NO;
		return;
	}
	toolchainString = [NSString stringWithFormat:@"{%@}", [toolchains componentsJoinedByString:@","]];
	if ([toolchainString rangeOfString:@"\""].location != NSNotFound) {
		[self presentMessage:@"Invalid Toolchain" informativeText:@"Please don't include double quotes in the toolchain list."];
		self.isRunning = NO;
		return;
	}
	
	NSString *workdir_path = [[NSUserDefaults standardUserDefaults] stringForKey:@"WorkingDirectory"];
	workdir = workdir_path ? [NSURL fileURLWithPath:workdir_path] : nil;
	if (!workdir) {
		[self presentMessage:@"Parameter missing" informativeText:@"Please provide a path for the working directory"];
		self.isRunning = NO;
		return;
	}
	NSError *error = nil;
	if (![[NSFileManager defaultManager] createDirectoryAtURL:workdir withIntermediateDirectories:YES attributes:nil error:&error]) {
		[self presentMessage:@"Could not create working directory" informativeText:error.localizedDescription];
		self.isRunning = NO;
		return;
	}

	connection = [PGConnection connectionToDatabase:[[NSUserDefaults standardUserDefaults] stringForKey:@"ServerURL"] error:&error];
	if (!connection) {
		[self presentError:error];
		self.isRunning = NO;
		return;
	}

	PGResult *result = [connection executeQuery: @"SELECT agent_init($1, $2)"
									 withParams: @[agentIdentifier, toolchainString]
										  error: &error];
	if (!result) {
		[connection disconnect];
		connection = nil;
		[self presentError:error];
		self.isRunning = NO;
		return;
	}

	agentID = [[result stringAtRow:0 column:0] intValue];
	[self logLine:[NSString stringWithFormat:@"Connected as agent ID %d", agentID]];
}

-(IBAction)getNextTask:(id)sender {
	if (task) {
		[self logLine:@"Task still running…"];
		return;
	}
	
	NSError *error = nil;
	PGResult *result = [connection executeQuery: @"SELECT * FROM agent_get_next_task()"
									 withParams: nil 
										  error: &error];
	if (!result) {
		[self presentError:error];
		return;
	}
	
	if (result.numRows == 0) {
		[self logLine:@"No tasks available"];
		return;
	}
		
	currentTaskId = [[result stringAtRow:0 columnName:@"taskrun_id"] intValue];
	self.currentTaskLabel = [result stringAtRow:0 columnName:@"label"];
	currentTaskScript = [result stringAtRow:0 columnName:@"script"];
	currentTaskUserInfoString = [result stringAtRow:0 columnName:@"userinfo"];

	if (!currentTaskId) {
		[self logLine:@"Taskrun does not have a valid ID."];
		return;
	}
	
	[self logLine:[NSString stringWithFormat:@"Starting Taskrun %d: %@", currentTaskId, self.currentTaskLabel]];

	// create workdir for task
	NSURL *taskWorkdir = [workdir URLByAppendingPathComponent:[NSString stringWithFormat:@"task_%09d", currentTaskId] isDirectory:YES];
	if (![[NSFileManager defaultManager] createDirectoryAtURL:taskWorkdir withIntermediateDirectories:YES attributes:nil error:&error]) {
		[self logLine:[NSString stringWithFormat:@"Could not create work dir: %@", error]];
		[self completeTaskExitCode:-50000];
		return;
	}
	
	// create script
	NSURL *scriptURL = [taskWorkdir URLByAppendingPathComponent:@"script" isDirectory:NO];
	if (![currentTaskScript writeToURL:scriptURL atomically:NO encoding:NSUTF8StringEncoding error:&error]) {
		[self logLine:[NSString stringWithFormat:@"Could not write script to work dir: %@", error]];
		[self completeTaskExitCode:-50001];
		return;
	}
	if (![[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @(0700)} ofItemAtPath:scriptURL.path error:&error]) {
		[self logLine:[NSString stringWithFormat:@"Could not make script executable: %@", error]];
		[self completeTaskExitCode:-50002];
		return;
	}
	
	task = [[NSTask alloc] init];
	task.currentDirectoryPath = taskWorkdir.path;
	task.launchPath = @"/bin/bash";
	task.arguments = @[@"-c", @"./script"];
	task_stdout = [[NSPipe alloc] init];
	task_stderr = [[NSPipe alloc] init];
	task.standardOutput = task_stdout;
	task.standardError = task_stderr;

	__weak TaskRunner *weakSelf = self;
	task_stdout.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandleForReading) {
		dispatch_sync(dispatch_get_main_queue(), ^{
			[weakSelf readFromFileHandle:fileHandleForReading fd:1];
		});
	};

	task_stderr.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandleForReading) {
		dispatch_sync(dispatch_get_main_queue(), ^{
			[weakSelf readFromFileHandle:fileHandleForReading fd:2];
		});
	};
	
	task.terminationHandler = ^(NSTask *completedTask){
		dispatch_sync(dispatch_get_main_queue(), ^{
			// remove readaility handlers
			// this should not be necessary, but there is a bug on macos 10.12 where nstask uses lots of CPU when the task is completed and ever makes the final call to the readability handler
			if ([completedTask.standardOutput isKindOfClass:[NSPipe class]]) {
				NSPipe *pipe = completedTask.standardOutput;
				pipe.fileHandleForReading.readabilityHandler = nil;
			}
			if ([completedTask.standardError isKindOfClass:[NSPipe class]]) {
				NSPipe *pipe = completedTask.standardError;
				pipe.fileHandleForReading.readabilityHandler = nil;
			}
			// read remaining data (if any), then report task completion
			TaskRunner *strongSelf = weakSelf;
			if (strongSelf && strongSelf->task == completedTask) {
				[strongSelf readFromFileHandle:strongSelf->task_stdout.fileHandleForReading fd:1];
				[strongSelf readFromFileHandle:strongSelf->task_stderr.fileHandleForReading fd:2];
				[strongSelf completeTaskExitCode:completedTask.terminationStatus];
			}
		});
	};
	
	[task launch];
}

-(void)readFromFileHandle:(NSFileHandle * _Nonnull)fileHandleForReading fd:(int)fd {
	NSData *data = fileHandleForReading.availableData;
	if (data.length) {
		NSString *string = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
		if (!string) string = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSISOLatin1StringEncoding];
		if (!string) string = @"����";
		[self logLine:string fd:fd];
	}
}

-(void)completeTaskExitCode:(int)exitCode {
	[self logLocally:[NSString stringWithFormat:@"Task finished with exit code %d", exitCode]];
	// send output to server
	if (currentTaskId && connection) {
		NSError *error = nil;
		if (![connection executeCommand: @"CALL agent_finish($1, $2)"
							 withParams: @[@(currentTaskId), @(exitCode)]
								  error: &error]) {
			[self logLocally:[NSString stringWithFormat:@"Failed to call agent_finish(): %@", error]];
		}
	}
	[task terminate];
	task = nil;
	currentTaskId = 0;
	self.currentTaskLabel = nil;
	currentTaskScript = nil;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self getNextTask:self];
	});
}

-(IBAction)stop:(id)sender {
	if (task) {
		[task terminate];
		[self logLine:@"Aborting…" fd:3];
		[self completeTaskExitCode:-55555];
	}
	connection = nil;
	self.isRunning = NO;
}

-(void)logLine:(NSString*)line {
	[self logLine:line fd:3];
}

-(void)logLine:(NSString*)line fd:(int)fd {
	// first log locally
	[self logLocally:line];
	
	// send output to server
	if (currentTaskId && connection) {
		NSError *error = nil;
		if (![connection executeCommand: @"CALL agent_log($1, $2, $3)" 
							 withParams: @[@(currentTaskId), @(fd), line]
								  error: &error]) {
			[self logLocally:[NSString stringWithFormat:@"Failed to send output to server: %@", error]];
		}
	}
}

-(void)logLocally:(NSString*)line {
	BOOL isEndVisible = NSMaxY(_logTextView.visibleRect) >= NSMaxY(_logTextView.bounds);
	[_logTextView replaceCharactersInRange:NSMakeRange(_logTextView.string.length,0)
								withString:[line stringByAppendingString:@"\n"]];
	[_logTextView didChangeText];
	[_logTextView setNeedsDisplay:YES];
	if (isEndVisible) [_logTextView scrollToEndOfDocument:nil];
}


-(void)presentMessage:(NSString*)messageText informativeText:(NSString*)informativeText {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = messageText;
	alert.informativeText = informativeText;
	[alert beginSheetModalForWindow:_logTextView.window completionHandler:nil];
}

-(void)presentError:(NSError*)error {
	[NSApp presentError:error modalForWindow:_logTextView.window delegate:nil didPresentSelector:nil contextInfo:nil];
}

@end
