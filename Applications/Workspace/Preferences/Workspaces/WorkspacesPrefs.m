/*
   "Workspaces" preferences.
   Manipulates with options of on-screen Workspaces and saves its state.

   Copyright (C) 2018 Sergii Stoian

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPXSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "WorkspacesPrefs.h"
#import <DesktopKit/NXTDefaults.h>
#import <Workspace+WM.h>
#import <Controller.h>

#include <core/wuserdefaults.h>
#include <workspace.h>

@interface WorkspacesPrefs (Private)
- (NSString *)_wmStatePath;
- (NSDictionary *)_wmState;
@end

@implementation WorkspacesPrefs (Private)

- (NSString *)_wmStatePath
{
  CFStringRef stringRef;
  const char  *wm_path;
  NSString    *path;
  
  stringRef = WMUserDefaultsCopyStringForDomain(CFSTR("WMState.plist"));
  if (!stringRef)
    return nil;
  
  wm_path = CFStringGetCStringPtr(stringRef, kCFStringEncodingUTF8);
  path = [NSString stringWithCString:wm_path];
  CFRelease(stringRef);

  NSLog(@"WMState path: %@", path);
  
  return path;
}

- (NSDictionary *)_wmState
{
  NSDictionary *wmState;

  // Defaults existance handled by WM.
  wmState = [[NSDictionary alloc] initWithContentsOfFile:[self _wmStatePath]];

  return [wmState autorelease];
}

@end

@implementation WorkspacesPrefs

- (void)dealloc
{
  NSDebugLLog(@"WorkspacesPrefs", @"WorkspacesPrefs: dealloc");

  [box release];
  [wsReps release];
  [wmStateWS release];
  
  [super dealloc];
}

- (void)awakeFromNib
{
  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];

  // Names and Numbers
  wsReps = [[NSMutableArray alloc] initWithObjects:ws1,ws2,ws3,ws4,ws5,ws6,ws7,ws8,ws9,ws10,nil];

  wmStateWS = [[NSMutableArray alloc] initWithArray:[[self _wmState] objectForKey:@"Workspaces"]];
  wsCount = (wmStateWS && [wmStateWS count] > 0) ? [wmStateWS count] : 1;
  for (int i = 9; i >= wsCount; i--) {
    [[wsReps objectAtIndex:i] removeFromSuperview];
  }

  [wsNumber selectItemWithTag:wsCount];
  [nameField setStringValue:@""];

  // Show In Dock button
  [showInDockBtn setRefusesFirstResponder:YES];
  [showInDockBtn setState:[[NXTDefaults userDefaults] boolForKey:@"ShowWorkspaceInDock"]];

  DESTROY(window);
}

// --- Protocol
- (NSString *)moduleName
{
  return _(@"Workspaces");
}

- (NSView *)view
{
  if (box == nil) {
      [NSBundle loadNibNamed:@"WorkspacesPrefs" owner:self];
    }

  return box;
}

- (void)revert:sender
{
  NSDictionary *wmDefaults;
  NSString     *shortcut;
  NSArray      *modifiers;

  wmDefaults = [[NSDictionary alloc] initWithDictionary:[self _wmState]];

  if (!wmDefaults)
    return;
  
  if (wmStateWS) [wmStateWS release];
  
  wmStateWS = [[NSMutableArray alloc] initWithArray:[wmDefaults objectForKey:@"Workspaces"]];
  [self arrangeWorkspaceReps];
  [[wsReps objectAtIndex:wDefaultScreen()->current_workspace] performClick:self];

  // NSLog(@"switchKey = %@ (%li/%li), directSwitchKey = %@ (%li/%li)",
  //       [switchKey className], [[switchKey selectedItem] tag],
  //       [switchKey numberOfItems],
  //       [directSwitchKey className], [[directSwitchKey selectedItem] tag],
  //       [directSwitchKey numberOfItems]);
  
  // Shortcuts
  shortcut = [wmDefaults objectForKey:@"NextWorkspaceKey"];
  modifiers = [shortcut componentsSeparatedByString:@"+"];
  if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod4"]) {
    [switchKey selectItemWithTag:0];
  }
  else if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod1"]) {
    [switchKey selectItemAtIndex:2];
  }
  else {
    [switchKey selectItemAtIndex:1];
  }
  
  shortcut = [wmDefaults objectForKey:@"Workspace1Key"];
  modifiers = [shortcut componentsSeparatedByString:@"+"];
  if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod4"]) {
    [directSwitchKey selectItemWithTag:0];
  }
  else if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod1"]) {
    [directSwitchKey selectItemWithTag:2];
  }
  else {
    [directSwitchKey selectItemWithTag:1];
  }
  
  [wmDefaults release];
}

// --- Utility
- (void)arrangeWorkspaceReps
{
  NSRect     repFrame = [[wsReps objectAtIndex:0] frame];
  NSUInteger repsWidth = (wsCount * repFrame.size.width) + ((wsCount-1) * 4);
  CGFloat    boxWidth = [wsBox frame].size.width;
  NSPoint    repPoint = repFrame.origin;
  NSButton   *rep;

  repPoint.x = (boxWidth - repsWidth) / 2;
  for (int i=0; i < wsCount; i++) {
    rep = [wsReps objectAtIndex:i];
    [rep setFrameOrigin:repPoint];
    repPoint.x += [rep frame].size.width + 4;
  }
  [wsBox setNeedsDisplay:YES];
}

// --- Names and Numbers
- (void)selectWorkspace:(id)sender
{
  NSButton *button;
  NSString *name = nil;

  for (int i = 0; i < wsCount; i++) {
    button = [wsReps objectAtIndex:i];
    if (sender == button) {
      [button setState:NSOnState];
      if ([wmStateWS count] > 0) {
        name = [[wmStateWS objectAtIndex:i] objectForKey:@"Name"];
      }
      [nameField setStringValue:(name ? name : @"Desktop 1")];
      selectedWSRep = button;
    } else {
      [button setState:NSOffState];
    }
  }
}

- (void)changeName:(id)sender
{
  NSInteger index = [wsReps indexOfObject:selectedWSRep];
  NSString  *name = [nameField stringValue];
  
  wWorkspaceRename(wDefaultScreen(), [wsReps indexOfObject:selectedWSRep],
                   [name cString]);
  [changeNameBtn setEnabled:NO];
  
  wScreenSaveState(wDefaultScreen());
  [wmStateWS replaceObjectAtIndex:index withObject:@{@"Name":name}];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSDictionary *wsInfo = nil;
  NSString     *wsName = nil;

  // NSLog(@"Text changed in %@", [object className]);
  if ([aNotification object] != nameField) {
    return;
  }

  if ([wmStateWS count] > 0) {
    wsInfo = [wmStateWS objectAtIndex:[wsReps indexOfObject:selectedWSRep]];
  }
  wsName = [nameField stringValue];
  
  if ([wsName rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].location != NSNotFound &&
      (!wsInfo || [wsName isEqualTo:[wsInfo objectForKey:@"Name"]] == NO)) {
    [changeNameBtn setEnabled:YES];
  } else {
    [changeNameBtn setEnabled:NO];
  }
}

- (void)setWorkspaceQuantity:(id)sender
{
  NSInteger wsQuantity = [[sender selectedItem] tag];
  int       diff = wsQuantity - wsCount;

  if (diff < 0) { // remove WS
    for (int i = wsCount; i > wsQuantity; i--) {
      wWorkspaceDelete(wDefaultScreen(), i);
      [[wsReps objectAtIndex:i-1] removeFromSuperview];
    }
  }
  else {
      wWorkspaceMake(wDefaultScreen(), diff);
      for (int i = wsCount; i < wsQuantity; i++) {
        [wsBox addSubview:[wsReps objectAtIndex:i]];
      }
      [wsBox setNeedsDisplay:YES];
  }

  wScreenSaveState(wDefaultScreen());
  [wmStateWS setArray:[[self _wmState] objectForKey:@"Workspaces"]];

  // Select last WS rep button if selected one was removed
  if ([wsReps indexOfObject:selectedWSRep] >= wsQuantity) {
    [self selectWorkspace:[wsReps objectAtIndex:wsQuantity-1]];
  }
  wsCount = wsQuantity;
  
  [self arrangeWorkspaceReps];
}

// --- Shortcuts
- (void)setSwitchShortcut:(id)sender
{
  NSInteger           selectedItemTag = [[sender selectedItem] tag];
  NSMutableDictionary *wmDefaults;
  NSString *prefix;

  wmDefaults = [[NSMutableDictionary alloc] initWithDictionary:[self _wmState]];
  if (!wmDefaults) {
    wmDefaults = [[NSMutableDictionary alloc] init];
  }
  
  switch(selectedItemTag) {
  case 0: // Alt + Control + Arrow Keys
    prefix = @"Mod4+Control";
    break;
  case 1: // Control + Arrow Keys (default)
    prefix = @"Control";
    break;
  case 2: // Cmd + Control + Arrow Keys
    prefix = @"Mod1+Control";
    break;
  }
  
  [wmDefaults setObject:[NSString stringWithFormat:@"%@+Right", prefix]
                 forKey:@"NextWorkspaceKey"];
  [wmDefaults setObject:[NSString stringWithFormat:@"%@+Left", prefix]
                 forKey:@"PrevWorkspaceKey"];
  [wmDefaults writeToFile:[self _wmStatePath] atomically:YES];
  [wmDefaults release];
}
- (void)setDirectSwitchShortcut:(id)sender
{
  NSMutableDictionary *wmDefaults;
  NSString *prefix;

  wmDefaults = [[NSMutableDictionary alloc] initWithDictionary:[self _wmState]];
  if (!wmDefaults) {
    wmDefaults = [NSMutableDictionary new];
  }
  
  switch([[sender selectedItem] tag]) {
  case 0: // Alt + Control + Number Keys
    prefix = @"Mod4+Control";
    break;
  case 1: // Control + Number Keys (default)
    prefix = @"Control";
    break;
  case 2: // Cmd + Control + Number Keys
    prefix = @"Mod1+Control";
    break;
  }

  for (int i=1; i <10; i++) {
    [wmDefaults setObject:[NSString stringWithFormat:@"%@+%i", prefix, i]
                   forKey:[NSString stringWithFormat:@"Workspace%iKey", i]];
  }
  [wmDefaults setObject:[NSString stringWithFormat:@"%@+0", prefix]
                 forKey:@"Workspace10Key"];
  [wmDefaults writeToFile:[self _wmStatePath] atomically:YES];
  [wmDefaults release];
}

// ---
- (void)setShowInDock:(id)sender
{
  [[NXTDefaults userDefaults] setBool:[sender state] ? YES : NO
                              forKey:@"ShowWorkspaceInDock"];
  if ([sender state]) {
    [[NSApp delegate] createWorkspaceBadge];
  }
  else {
    [[NSApp delegate] destroyWorkspaceBadge];    
  }
}

@end
