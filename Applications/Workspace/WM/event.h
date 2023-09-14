/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2013 Window Maker Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __WORKSPACE_WM_EVENT__
#define __WORKSPACE_WM_EVENT__

#include <X11/Xlib.h>
#include <sys/types.h>
#include "config.h"
#include "window.h"

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

typedef void (WDeathHandler)(pid_t pid, unsigned int status, void *cdata);

void WMRunLoop_V0(void);
void WMRunLoop_V1(void);
noreturn void EventLoop(void);
void DispatchEvent(XEvent *event);
void ProcessPendingEvents(void);
WMagicNumber wAddDeathHandler(pid_t pid, WDeathHandler *callback, void *cdata);
Bool IsDoubleClick(WScreen *scr, XEvent *event);

/* called from the signal handler */
void NotifyDeadProcess(pid_t pid, unsigned char status);

#endif /* __WORKSPACE_WM_EVENT__ */
