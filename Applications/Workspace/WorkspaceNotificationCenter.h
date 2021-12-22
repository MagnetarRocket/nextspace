/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <Foundation/NSNotification.h>
#import <CoreFoundation/CFNotificationCenter.h>

// #import <AppKit/AppKitDefines.h>
// APPKIT_EXPORT NSString *GSWorkspaceNotification;
// APPKIT_EXPORT NSString *GSWorkspacePreferencesChanged;

@interface WorkspaceNotificationCenter : NSNotificationCenter
{
  CFNotificationCenterRef coreFoundationCenter;
  //  CFDictionaryRef         cfObservers;
}
+ (instancetype)defaultCenter;

- (void)addObserver:(id)observer
           selector:(SEL)selector
               name:(CFStringRef)name;
@end

@interface CFObject : NSObject
@property (readwrite) const void *object;
@end

// Window manager - notifications defined in WM/WM.h
extern CFStringRef WMDidManageWindowNotification;
extern CFStringRef WMDidUnmanageWindowNotification;

extern CFStringRef WMDidChangeWorkspaceNotification;
extern CFStringRef WMDidChangeWindowStateNotification;
