/*
 * Copyright (c) 2010, Wei Mingzhi <whistler@openoffice.org>.
 * All Rights Reserved.
 *
 * Based on: Cdrom for Psemu Pro like Emulators
 * By: linuzappz <linuzappz@hotmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses>.
 */

#import "PluginConfigController.h"
#include "typedefs.h"
#include "sio1.h"
#import "ARCBridge.h"

#define APP_ID @"net.pcsxr.Bladesio1"
#define PrefsKey APP_ID @" Settings"

static PluginConfigController *windowController = nil;

#define kSioEnabled @"SIO Enabled"
#define kSioPort @"Port"
#define kSioPlayer @"Player"
#define kSioIPAddress @"IP address"

void AboutDlgProc()
{
	// Get parent application instance
	NSApplication *app = [NSApplication sharedApplication];
	NSBundle *bundle = [NSBundle bundleWithIdentifier:APP_ID];

	// Get Credits.rtf
	NSString *path = [bundle pathForResource:@"Credits" ofType:@"rtf"];
	NSAttributedString *credits;
	if (path) {
		credits = [[NSAttributedString alloc] initWithPath: path
				documentAttributes:NULL];
		AUTORELEASEOBJNORETURN(credits);
		
	} else {
		credits = AUTORELEASEOBJ([[NSAttributedString alloc] initWithString:@""]);
	}

	// Get Application Icon
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[bundle bundlePath]];
	NSSize size = NSMakeSize(64, 64);
	[icon setSize:size];

	[app orderFrontStandardAboutPanelWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:
			[bundle objectForInfoDictionaryKey:@"CFBundleName"], @"ApplicationName",
			icon, @"ApplicationIcon",
			[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], @"ApplicationVersion",
			[bundle objectForInfoDictionaryKey:@"CFBundleVersion"], @"Version",
			[bundle objectForInfoDictionaryKey:@"NSHumanReadableCopyright"], @"Copyright",
			credits, @"Credits",
			nil]];
}

void ConfDlgProc()
{
	NSWindow *window;

	if (windowController == nil) {
		windowController = [[PluginConfigController alloc] initWithWindowNibName:@"Bladesio1PluginConfig"];
	}
	window = [windowController window];

	[windowController loadValues];

	[window center];
	[window makeKeyAndOrderFront:nil];
}

void ReadConfig()
{
	NSDictionary *keyValues;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
								[NSDictionary dictionaryWithObjectsAndKeys:
								 @NO, kSioEnabled,
								 @((unsigned short)33307), kSioPort,
								 @"127.0.0.1", kSioIPAddress,
								 @(PLAYER_DISABLED), kSioPlayer,
								 nil], PrefsKey, nil]];

	keyValues = [defaults dictionaryForKey:PrefsKey];

	settings.enabled = [[keyValues objectForKey:kSioEnabled] boolValue];
	settings.port = [[keyValues objectForKey:kSioPort] unsignedShortValue];
	settings.player = [[keyValues objectForKey:kSioPlayer] intValue];
	strlcpy(settings.ip, [[keyValues objectForKey:kSioIPAddress] cStringUsingEncoding:NSASCIIStringEncoding], sizeof(settings.ip));
}

@implementation Bladesio1PluginConfigController

- (IBAction)cancel:(id)sender
{
	[self close];
}

- (IBAction)ok:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	NSMutableDictionary *writeDic = [NSMutableDictionary dictionaryWithDictionary:keyValues];

	
	NSString *theAddress = [ipAddressField stringValue];
	{
		unsigned char a, b, c, d;
		if (sscanf([theAddress cStringUsingEncoding:NSASCIIStringEncoding], "%s.%s.%s.%s", &a, &b, &c, &d) != 4) {
			NSBeginAlertSheet(@"Invalid IP address", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"The IP address cannot be a hostname,");
		}
	}
	
	[writeDic setObject:(([enabledButton state]  == NSOnState) ? @YES : @NO) forKey:kSioEnabled];
	[writeDic setObject:[ipAddressField stringValue] forKey:kSioIPAddress];
	[writeDic setObject:@((unsigned short)[portField intValue]) forKey:kSioPort];
	

	switch ([playerMenu indexOfSelectedItem]) {
		default:
		case 0: [writeDic setObject:@(PLAYER_DISABLED) forKey:kSioPlayer]; break;
		case 1: [writeDic setObject:@(PLAYER_MASTER) forKey:kSioPlayer]; break;
		case 2: [writeDic setObject:@(PLAYER_SLAVE) forKey:kSioPlayer]; break;
	}

	// write to defaults
	[defaults setObject:writeDic forKey:PrefsKey];
	[defaults synchronize];

	// and set global values accordingly
	ReadConfig();

	[self close];
}

- (IBAction)toggleEnabled:(id)sender
{
	BOOL isEnabled = [enabledButton state] == NSOnState ? YES : NO;
	
	for (NSView *subView in [configBox subviews]) {
		if ([subView isKindOfClass:[NSTextField class]] && ![(NSTextField*)subView isEditable]) {
				[(NSTextField*)subView setTextColor:isEnabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]];
		} else {
			[(NSControl*)subView setEnabled:isEnabled];
		}
	}
}

- (IBAction)resetPreferences:(id)sender
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:PrefsKey];
	[self loadValues];
}

- (void)loadValues
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	ReadConfig();

	// load from preferences
	RELEASEOBJ(keyValues);
	keyValues = [[defaults dictionaryForKey:PrefsKey] mutableCopy];

	[enabledButton setState: [[keyValues objectForKey:kSioEnabled] boolValue] ? NSOnState : NSOffState];
	[ipAddressField setTitleWithMnemonic:[keyValues objectForKey:kSioIPAddress]];
	[portField setValue:[keyValues objectForKey:kSioPort]];
	
	switch ([[keyValues objectForKey:kSioPlayer] intValue]) {
		default:
		case PLAYER_DISABLED: [playerMenu selectItemAtIndex:0]; break;
		case PLAYER_MASTER: [playerMenu selectItemAtIndex:1]; break;
		case PLAYER_SLAVE: [playerMenu selectItemAtIndex:2]; break;
	}
}

- (void)awakeFromNib
{
}

@end

char* PLUGLOC(char *toloc)
{
	NSBundle *mainBundle = [NSBundle bundleForClass:[PluginConfigController class]];
	NSString *origString = nil, *transString = nil;
	origString = [NSString stringWithCString:toloc encoding:NSUTF8StringEncoding];
	transString = [mainBundle localizedStringForKey:origString value:nil table:nil];
	return (char*)[transString cStringUsingEncoding:NSUTF8StringEncoding];
}
