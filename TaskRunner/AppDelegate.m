//
//  AppDelegate.m
//  TaskRunner
//
//  Created by Jakob Egger on 2020-05-07.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[self.window makeFirstResponder:nil]; // commit pending text fields
}

-(IBAction)chooseWorkingDirectory:(id)sender {
	NSWindow *window = [sender window];
	[window makeFirstResponder:nil]; // commit pending text fields
	NSOpenPanel *folderChooser = [[NSOpenPanel alloc] init];
	folderChooser.canChooseDirectories = YES;
	folderChooser.canChooseFiles = NO;
	[folderChooser beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
		if (result==NSModalResponseOK) {
			[[NSUserDefaults standardUserDefaults] setObject:folderChooser.URL.path forKey:@"WorkingDirectory"];
		}
	}];
}

-(BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	[self.window makeKeyAndOrderFront:nil];
	return NO;
}

@end
