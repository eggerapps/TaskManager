//
//  TaskRunner.m
//  TaskRunner
//
//  Created by Jakob Egger on 2020-05-07.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import "TaskRunner.h"
#import "libpq-fe.h"

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

	conn = PQconnectdb([[NSUserDefaults standardUserDefaults] stringForKey:@"ServerURL"].UTF8String);
	if (PQstatus(conn) != CONNECTION_OK) {
		[self presentMessage:@"Connection Failed" informativeText:@(PQerrorMessage(conn))];
		PQfinish(conn);
		conn = NULL;
		self.isRunning = NO;
		return;
	}
	const char *values[2];
	values[0] = [agentIdentifier UTF8String];
	values[1] = [toolchainString UTF8String];
	PGresult *result = PQexecParams(
									conn,
									"SELECT agent_init($1, $2)",
									2,
									NULL,
									values,
									NULL,
									NULL,
									0
									);
	if (PQresultStatus(result) != PGRES_TUPLES_OK) {
		[self presentMessage:@"agent_init() failed" informativeText:@(PQerrorMessage(conn))];
		PQfinish(conn);
		conn = NULL;
		self.isRunning = NO;
		return;
	}
	
	agentID = [@(PQgetvalue(result,0,0)) intValue];
	[self logLine:[NSString stringWithFormat:@"Connected as agent ID %d", agentID]];
	
	PQclear(result);
}

-(IBAction)getNextTask:(id)sender {
	if (task) {
		[self logLine:@"Task still running…"];
		return;
	}
	
	PGresult *result = PQexec(conn, "SELECT * FROM agent_get_next_task()");
	if (PQresultStatus(result) != PGRES_TUPLES_OK) {
		[self presentMessage:@"agent_get_next_task() failed" informativeText:@(PQerrorMessage(conn))];
		PQclear(result);
		return;
	}
	
	if (PQntuples(result)==0) {
		[self logLine:@"No tasks available"];
	}
	
	int id_num = PQfnumber(result, "current_taskrun_id");
	int label_num = PQfnumber(result, "label");
	int script_num = PQfnumber(result, "script");
	int userinfo_num = PQfnumber(result, "userinfo");
	
	if (id_num == -1 || label_num == -1 || script_num == -1 || userinfo_num == -1) {
		[self logLine:@"Result does not have expected columns."];
		PQclear(result);
		return;
	}
	
	currentTaskId = [@(PQgetvalue(result,0,id_num)) intValue];
	self.currentTaskLabel = @(PQgetvalue(result,0,label_num));
	currentTaskScript = @(PQgetvalue(result,0,script_num));
	currentTaskUserInfoString = @(PQgetvalue(result,0,userinfo_num));

	PQclear(result);

	if (!currentTaskId) {
		[self logLine:@"Taskrun does not have a valid ID."];
		return;
	}
	
	[self logLine:[NSString stringWithFormat:@"Starting Taskrun %d: %@", currentTaskId, self.currentTaskLabel]];

	// create workdir for task
	NSURL *taskWorkdir = [workdir URLByAppendingPathComponent:[NSString stringWithFormat:@"task_%09d", currentTaskId] isDirectory:YES];
	NSError *error = nil;
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
	task.launchPath = @"/bin/sh";
	task.arguments = @[@"-c", @"script"];
	task_stdout = [[NSPipe alloc] init];
	task_stderr = [[NSPipe alloc] init];
	task.standardOutput = task_stderr;
	task.standardError = task_stderr;

	task_stdout.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandleForReading) {
		NSData *data = fileHandleForReading.availableData;
		if (data.length == 0) {
			[self completeTaskExitCode:task.terminationStatus];
		}
		[self logLine:[NSString stringWithFormat:@"%s", data.bytes] fd:1];
	};

	task_stderr.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandleForReading) {
		NSData *data = fileHandleForReading.availableData;
		if (data.length == 0) {
			[self completeTaskExitCode:task.terminationStatus];
		} else {
			[self logLine:[NSString stringWithFormat:@"%s", data.bytes] fd:2];
		}
	};

}

-(void)completeTaskExitCode:(int)exitCode {
	// send output to server
	if (currentTaskId && conn) {
		const char *values[2];
		values[0] = [[NSString stringWithFormat:@"%d", currentTaskId] UTF8String];
		values[1] = [[NSString stringWithFormat:@"%d", exitCode] UTF8String];
		PGresult *result = PQexecParams(
										conn,
										"CALL agent_finish($1, $2)",
										3,
										NULL,
										values,
										NULL,
										NULL,
										0
										);
		if (PQresultStatus(result) != PGRES_COMMAND_OK) {
			[self logLocally:[NSString stringWithFormat:@"Failed to call agent_finish(): %s", PQerrorMessage(conn)]];
		}
		PQclear(result);
	}
	[self logLocally:[NSString stringWithFormat:@"Task finished with exit code %d", exitCode]];
	[task terminate];
	task = nil;
	currentTaskId = 0;
	self.currentTaskLabel = nil;
	currentTaskScript = nil;
}

-(IBAction)stop:(id)sender {
	PQfinish(conn);
	conn = NULL;
	self.isRunning = NO;
	[task terminate];
	[self logLine:@"Stopping…"];
}

-(void)logLine:(NSString*)line {
	[self logLine:line fd:3];
}

-(void)logLine:(NSString*)line fd:(int)fd {
	// first log locally
	[self logLocally:line];
	
	// send output to server
	if (currentTaskId && conn) {
		const char *values[3];
		values[0] = [[NSString stringWithFormat:@"%d", currentTaskId] UTF8String];
		values[1] = [[NSString stringWithFormat:@"%d", fd] UTF8String];
		values[2] = [line UTF8String];
		PGresult *result = PQexecParams(
										conn,
										"CALL agent_log($1, $2, $3)",
										3,
										NULL,
										values,
										NULL,
										NULL,
										0
										);
		if (PQresultStatus(result) != PGRES_COMMAND_OK) {
			[self logLocally:[NSString stringWithFormat:@"Failed to send output to server: %s", PQerrorMessage(conn)]];
		}
		PQclear(result);
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

@end

int verify_context_with_keychain() {
	return NO;
}
