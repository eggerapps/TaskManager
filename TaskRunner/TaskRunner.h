//
//  TaskRunner.h
//  TaskRunner
//
//  Created by Jakob Egger on 2020-05-07.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "libpq-fe.h"

NS_ASSUME_NONNULL_BEGIN

@interface TaskRunner : NSObject {
	PGconn *conn;
	NSURL *workdir;
	NSArray<NSString*> *toolchains;
	NSString *toolchainString;
	NSString *agentIdentifier;
	int agentID;
}

@property BOOL isRunning;
@property IBOutlet NSTextView *logTextView;
@property NSString *currentTaskLabel;

-(IBAction)start:(id)sender;
-(IBAction)stop:(id)sender;

-(void)logLine:(NSString*)line;

@end

NS_ASSUME_NONNULL_END
