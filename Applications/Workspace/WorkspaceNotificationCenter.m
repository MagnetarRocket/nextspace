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

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFDictionary.h>

#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

#import "WorkspaceNotificationCenter.h"

// Object conversion functions
//-----------------------------------------------------------------------------
static NSNumber *_convertCFtoNSNumber(CFNumberRef cfNumber);
static NSString *_convertCFtoNSString(CFStringRef cfString);
static NSArray *_convertCFtoNSArray(CFArrayRef cfArray);
static NSDictionary *_convertCFtoNSDictionary(CFDictionaryRef cfDictionary);
static id _convertCoreFoundationToFoundation(CFTypeRef value);

NSNumber *_convertCFtoNSNumber(CFNumberRef cfNumber)
{
  int value;
  CFNumberGetValue(cfNumber, CFNumberGetType(cfNumber), &value);
  return [NSNumber numberWithInt:value];
}
NSString *_convertCFtoNSString(CFStringRef cfString)
{
  const char *stringPtr;
  stringPtr = CFStringGetCStringPtr(cfString, CFStringGetSystemEncoding());
  return [NSString stringWithCString:stringPtr];
}
// TODO
NSArray *_convertCFtoNSArray(CFArrayRef cfArray)
{
  NSMutableArray *nsArray = [NSMutableArray new];
  return [nsArray autorelease];
}
NSDictionary *_convertCFtoNSDictionary(CFDictionaryRef cfDictionary)
{
  NSMutableDictionary *nsDictionary = nil;
  const void          *keys;
  const void          *values;

  if (cfDictionary) {
    nsDictionary = [NSMutableDictionary new];
    CFDictionaryGetKeysAndValues(cfDictionary, &keys, &values);
    for (int i = 0; i < CFDictionaryGetCount(cfDictionary); i++) {
      [nsDictionary setObject:_convertCoreFoundationToFoundation(&values[i]) // may be recursive
                       forKey:_convertCFtoNSString(&keys[i])]; // always CFStringRef
    }
  }
  
  return (nsDictionary ? [nsDictionary autorelease] : nil);
}
id _convertCoreFoundationToFoundation(CFTypeRef value)
{
  CFTypeID valueType = CFGetTypeID(value);
  id       returnValue = @"(null)";
  
  if (valueType == CFStringGetTypeID()) {
    returnValue = _convertCFtoNSString(value);
  }
  else if (valueType == CFNumberGetTypeID()) {
    returnValue = _convertCFtoNSNumber(value);
  }
  else if (valueType == CFArrayGetTypeID()) {
    returnValue = _convertCFtoNSArray(value);
  }
  else if (valueType == CFDictionaryGetTypeID()) {
    returnValue = _convertCFtoNSDictionary(value);
  }

  return returnValue;
}

static CFDictionaryRef _convertNStoCFDictionary(NSDictionary *dictionary);

CFDictionaryRef _convertNStoCFDictionary(NSDictionary *dictionary)
{
  CFMutableDictionaryRef cfDictionary;
  CFStringRef keyCFString;
  CFStringRef valueCFString;

  cfDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
  for (id key in [dictionary allKeys]) {
    id value = [dictionary objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
      keyCFString = CFStringCreateWithCString(kCFAllocatorDefault, [key cString],
                                              CFStringGetSystemEncoding());
      valueCFString = CFStringCreateWithCString(kCFAllocatorDefault, [value cString],
                                                CFStringGetSystemEncoding());
      CFDictionaryAddValue(cfDictionary, keyCFString, valueCFString);
      CFRelease(keyCFString);
      CFRelease(valueCFString);
    }
  }
  return cfDictionary;
}

@implementation CFObject @end

//-----------------------------------------------------------------------------
// Workspace notification center
//-----------------------------------------------------------------------------

static WorkspaceNotificationCenter *wsnc = nil;

@interface WorkspaceNotificationCenter (Private)
- (void)_postNSLocal:(NSString *)name object:(id)object userInfo:(NSDictionary *)info;
- (void)_postCFLocal:(NSString*)name userInfo:(NSDictionary*)info;
@end
@implementation WorkspaceNotificationCenter (Private)

- (void)_postNSLocal:(NSString *)name
              object:(id)object
            userInfo:(NSDictionary *)info
{
  NSNotification *aNotification = [NSNotification notificationWithName:name
                                                                object:object
                                                              userInfo:info];
  [super postNotification:aNotification];
}

- (void)_postCFLocal:(NSString *)name
            userInfo:(NSDictionary *)info
{
  const void *cfObject;
  CFStringRef cfName;
  CFDictionaryRef cfUserInfo;

  // name
  cfName = CFStringCreateWithCString(kCFAllocatorDefault, [name cString], CFStringGetSystemEncoding());
  // userInfo
  cfUserInfo = _convertNStoCFDictionary(info);
  // object
  cfObject = NULL;
 
  CFNotificationCenterPostNotification(coreFoundationCenter, cfName, cfObject, cfUserInfo, TRUE);

  CFRelease(cfName);
  CFRelease(cfUserInfo);
}

/* CF to NS notification dispatching.
   1. Convert notification name (CFNotificationName -> NSString)
   2. Convert userInfo (CFDisctionaryRef -> NSDictionary)
   3. Create and send NSNotification to NSNotificationCenter with
   [NSNotification notificationWithName:name   // converted from CFString
                                 object:object // NSObject.object
                               userInfo:info]  // converted from CFDictionaryRef
*/
/* CF notification sent with this call:
   CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                       "WMDidManageWindowNotification", // notification name
                                       wwin,                            // object
                                       NULL,                            // userInfo
                                       TRUE);

*/
static void _handleCFNotifications(CFNotificationCenterRef center,
                                   void *observer,
                                   CFNotificationName name,
                                   const void *object,
                                   CFDictionaryRef userInfo)
{
  CFObject *cfObject = [CFObject new];
  cfObject.object = object;
  
  NSLog(@"[WorkspaceNC] _handleCFNotificaition: %@ - %@",
        _convertCFtoNSString(name), _convertCFtoNSDictionary(userInfo));
  
  [wsnc _postNSLocal:_convertCFtoNSString(name)
              object:cfObject
            userInfo:_convertCFtoNSDictionary(userInfo)];
  [cfObject release];
}

@end

@implementation	WorkspaceNotificationCenter

+ (instancetype)defaultCenter
{
  if (!wsnc) {
    [[WorkspaceNotificationCenter alloc] init];
  }
  return wsnc;
}

- (void)dealloc
{
  CFNotificationCenterRemoveEveryObserver(coreFoundationCenter, self);
  CFRelease(coreFoundationCenter);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  coreFoundationCenter = CFNotificationCenterGetLocalCenter();
  wsnc = self;
  
  return self;
}

// Observers management
// 'object' is ignored for CoreFoundation call
- (void)addObserver:(id)observer
           selector:(SEL)selector
               name:(CFStringRef)name
{
  /* Register observer-name in NSNotificationCenter.
     In CF notification callback (_handleCFNotifications()) this notification will
     be forwarded to NSNotificationCenter with name specified in `name` parameter.
     `selector` of the caller must be registered in NSNotificationCenter to be called. */
  [super addObserver:observer
            selector:selector
                name:_convertCFtoNSString(name)
              object:nil];

  // Register handler-name in CFNotificationCenter
  CFNotificationCenterAddObserver(coreFoundationCenter,   // created in -init
                                  self,                   // observer
                                  _handleCFNotifications, // callback: CFNotificationCallback
                                  name,                   // notification name: CFStringRef
                                  NULL,                   // object
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
}

// Notification dispatching
- (void)postNotification:(NSNotification*)aNotification
{
  [self postNotificationName:[aNotification name]
                      object:[aNotification object]
                    userInfo:[aNotification userInfo]];
}

- (void)postNotificationName:(NSString*)name 
                      object:(id)object
{
  [self postNotificationName:name
                      object:object
                    userInfo:nil];
}

- (void)postNotificationName:(NSString*)name
                      object:(id)object
                    userInfo:(NSDictionary*)info
{
  // NSNotificationCenter
  [self _postNSLocal:name object:object userInfo:info];
  // CFNotificationCenter
  [self _postCFLocal:name userInfo:info];
}

@end
