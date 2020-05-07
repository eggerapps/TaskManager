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



-(IBAction)stop:(id)sender {
	PQfinish(conn);
	conn = NULL;
	self.isRunning = NO;
	[self logLine:@"Stopping…"];
}

-(void)logLine:(NSString*)line {
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
