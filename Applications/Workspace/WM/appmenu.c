#include <string.h>
#include <stdio.h>

#include <core/log_utils.h>
#include <core/string_utils.h>

#include "appmenu.h"
#include "window.h"
#include "framewin.h"
#include "actions.h"
#include "misc.h"

// Main application menu
//-------------------------------------------------------------------------------------------------
static void nullCallback(WMenu *menu, WMenuEntry *entry)
{
  WMLogInfo("Item %s was clicked in menu %s", entry->text, menu->frame->title);
}

static void mainCallback(WMenu *menu, WMenuEntry *entry)
{
  WApplication *wapp = (WApplication *)entry->clientdata;
  
  if (!strcmp(entry->text, "Hide")) {
    wHideApplication(wapp);
  } else if (!strcmp(entry->text, "Hide Others")) {
    wHideOtherApplications(wapp->last_focused);
  }
}

// "Windows" menu
//-------------------------------------------------------------------------------------------------
#define MAX_WINDOWLIST_WIDTH    400
#define ACTION_ADD              0
#define ACTION_REMOVE           1
#define ACTION_CHANGE           2
#define ACTION_CHANGE_WORKSPACE 3
#define ACTION_CHANGE_STATE     4

static void focusWindow(WMenu *menu, WMenuEntry *entry)
{
  WWindow *wwin = (WWindow *)entry->clientdata;
  wWindowSingleFocus(wwin);
}

static void windowsCallback(WMenu *menu, WMenuEntry *entry) {}

static int menuIndexForWindow(WMenu *menu, WWindow *wwin, int old_pos)
{
  int idx;

  if (menu->entry_no <= old_pos)
    return -1;

#define WS(i)  ((WWindow*)menu->entries[i]->clientdata)->frame->workspace
  if (old_pos >= 0) {
    if (WS(old_pos) >= wwin->frame->workspace
        && (old_pos == 0 || WS(old_pos - 1) <= wwin->frame->workspace)) {
      return old_pos;
    }
  }
#undef WS

  for (idx = 0; idx < menu->entry_no; idx++) {
    WWindow *tw = (WWindow *)menu->entries[idx]->clientdata;

    if (!IS_OMNIPRESENT(tw)
        && tw->frame->workspace > wwin->frame->workspace) {
      break;
    }
  }

  return idx;
}

static void updateWindowsMenu(WMenu *windows_menu, WWindow *wwin, int action)
{
  WMenuEntry *entry;
  char title[MAX_MENU_TEXT_LENGTH + 6];
  int len = sizeof(title);
  int i;
  int checkVisibility = 0;

  /*
   *  This menu is updated under the following conditions:
   *    1.  When a window is created.
   *    2.  When a window is destroyed.
   *    3.  When a window changes it's title.
   */
  if (action == ACTION_ADD) {
    char *t;
    int idx;

    if (wwin->flags.internal_window || WFLAGP(wwin, skip_window_list)) {
      return;
    }

    if (wwin->frame->title)
      snprintf(title, len, "%s", wwin->frame->title);
    else
      snprintf(title, len, "%s", DEF_WINDOW_TITLE);
    t = ShrinkString(wwin->screen_ptr->menu_entry_font, title, MAX_WINDOWLIST_WIDTH);

    if (IS_OMNIPRESENT(wwin))
      idx = -1;
    else {
      idx = menuIndexForWindow(windows_menu, wwin, -1);
    }

    entry = wMenuInsertCallback(windows_menu, idx, t, focusWindow, wwin);
    wfree(t);

    entry->flags.indicator = 1;
    if (wwin->flags.hidden) {
      entry->flags.indicator_type = MI_HIDDEN;
      entry->flags.indicator_on = 1;
    } else if (wwin->flags.miniaturized) {
      entry->flags.indicator_type = MI_MINIWINDOW;
      entry->flags.indicator_on = 1;
    } else if (wwin->flags.focused) {
      entry->flags.indicator_type = MI_DIAMOND;
      entry->flags.indicator_on = 1;
    } else if (wwin->flags.shaded) {
      entry->flags.indicator_type = MI_SHADED;
      entry->flags.indicator_on = 1;
    }

    wMenuRealize(windows_menu);
    checkVisibility = 1;
  } else {
    char *t;
    for (i = 0; i < windows_menu->entry_no; i++) {
      entry = windows_menu->entries[i];
      /* this is the entry that was changed */
      if (entry->clientdata == wwin) {
        switch (action) {
        case ACTION_REMOVE:
          wMenuRemoveItem(windows_menu, i);
          wMenuRealize(windows_menu);
          checkVisibility = 1;
          break;

        case ACTION_CHANGE:
          if (entry->text)
            wfree(entry->text);

          if (wwin->frame->title)
            snprintf(title, MAX_MENU_TEXT_LENGTH, "%s", wwin->frame->title);
          else
            snprintf(title, MAX_MENU_TEXT_LENGTH, "%s", DEF_WINDOW_TITLE);

          t = ShrinkString(wwin->screen_ptr->menu_entry_font, title, MAX_WINDOWLIST_WIDTH);
          entry->text = t;

          wMenuRealize(windows_menu);
          checkVisibility = 1;
          break;

        case ACTION_CHANGE_STATE:
          if (wwin->flags.hidden) {
            entry->flags.indicator_type = MI_HIDDEN;
            entry->flags.indicator_on = 1;
          } else if (wwin->flags.miniaturized) {
            entry->flags.indicator_type = MI_MINIWINDOW;
            entry->flags.indicator_on = 1;
          } else if (wwin->flags.shaded && !wwin->flags.focused) {
            entry->flags.indicator_type = MI_SHADED;
            entry->flags.indicator_on = 1;
          } else {
            entry->flags.indicator_on = wwin->flags.focused;
            entry->flags.indicator_type = MI_DIAMOND;
          }
          break;
        }
        break;
      }
    }
  }
  if (checkVisibility) {
    int tmp;

    tmp = windows_menu->frame->top_width + 5;
    /* if menu got unreachable, bring it to a visible place */
    if (windows_menu->frame_x < tmp - (int)windows_menu->frame->core->width) {
      wMenuMove(windows_menu, tmp - (int)windows_menu->frame->core->width,
                windows_menu->frame_y, False);
    }
  }
  wMenuPaint(windows_menu);
}

static void windowObserver(CFNotificationCenterRef center,
                           void *menu,
                           CFNotificationName name,
                           const void *window,
                           CFDictionaryRef userInfo)
{
  WMenu *windows_menu = (WMenu *)menu;
  WWindow *wwin = (WWindow *)window;
    
  if (!wwin)
    return;
  
  if (CFStringCompare(name, WMDidManageWindowNotification, 0) == 0) {
    updateWindowsMenu(windows_menu, wwin, ACTION_ADD);
  }
  else if (CFStringCompare(name, WMDidUnmanageWindowNotification, 0) == 0) {
    updateWindowsMenu(windows_menu, wwin, ACTION_REMOVE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowFocusNotification, 0) == 0) {
    updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_STATE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowNameNotification, 0) == 0) {
    updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowStateNotification, 0) == 0) {
    CFStringRef wstate = (CFStringRef)wGetNotificationInfoValue(userInfo, CFSTR("state"));
    if (CFStringCompare(wstate, CFSTR("omnipresent"), 0) == 0) {
      updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_WORKSPACE);
    }
    else {
      updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_STATE);
    }
  }
}

static WMenu *createWindowsMenu(WApplication *wapp)
{
  WMenu *windows_menu;
  WMenuEntry *tmp_item;
  CFIndex winCount = CFArrayGetCount(wapp->windows);
  WWindow *wwin = NULL;
  char *t;
  char title[MAX_MENU_TEXT_LENGTH + 6];
  int len = sizeof(title);
  WScreen *scr = wapp->main_wwin->screen_ptr;
  
  windows_menu = wMenuCreate(scr, _("Windows"), False);
  wMenuInsertCallback(windows_menu, 0, _("Arrange in Front"), windowsCallback, NULL);

  for (CFIndex i = 0; i < winCount; i++) {
    wwin = (WWindow *)CFArrayGetValueAtIndex(wapp->windows, i);
    if (wwin->frame->title) {
      snprintf(title, len, "%s", wwin->frame->title);
    } else {
      snprintf(title, len, "%s", DEF_WINDOW_TITLE);
    }
    t = ShrinkString(wwin->screen_ptr->menu_entry_font, title, MAX_WINDOWLIST_WIDTH);
    wMenuInsertCallback(windows_menu, i+1, t, windowsCallback, wwin);
  }
  
  tmp_item = wMenuAddCallback(windows_menu, _("Miniaturize Window"), windowsCallback, NULL);
  tmp_item->rtext = wstrdup("m");
  tmp_item = wMenuAddCallback(windows_menu, _("Shade Window"), windowsCallback, NULL);
  tmp_item = wMenuAddCallback(windows_menu, _("Zoom window"), windowsCallback, NULL);
  tmp_item = wMenuAddCallback(windows_menu, _("Close Window"), windowsCallback, NULL);
  tmp_item->rtext = wstrdup("w");

  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, windowObserver,
                                  WMDidManageWindowNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, windowObserver,
                                  WMDidUnmanageWindowNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, windowObserver,
                                  WMDidChangeWindowStateNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, windowObserver,
                                  WMDidChangeWindowFocusNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, windowObserver,
                                  WMDidChangeWindowStackingNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, windowObserver,
                                  WMDidChangeWindowNameNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);


  return windows_menu;
}

WMenu *wApplicationCreateMenu(WScreen *scr, WApplication *wapp)
{
  WMenu *menu, *info, *edit, *windows;
  WMenuEntry *info_item, *edit_item, *windows_item, *tmp_item;

  menu = wMenuCreate(scr, wapp->app_name, True);
  
  /* Info */

  info = wMenuCreate(scr, _("Info"), False);
  wMenuAddCallback(info, _("Info Panel..."), nullCallback, NULL);
  wMenuAddCallback(info, _("Legal..."), nullCallback, NULL);
  wMenuAddCallback(info, _("Preferences..."), nullCallback, NULL);
  info_item = wMenuAddCallback(menu, _("Info"), NULL, NULL);
  wMenuEntrySetCascade(menu, info_item, info);

  edit = wMenuCreate(scr, _("Edit"), False);
  tmp_item = wMenuAddCallback(edit, _("Cut"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("x");
  tmp_item = wMenuAddCallback(edit, _("Copy"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("c");
  tmp_item = wMenuAddCallback(edit, _("Paste"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("v");
  tmp_item = wMenuAddCallback(edit, _("Select All"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("a");
  edit_item = wMenuAddCallback(menu, _("Edit"), NULL, NULL);
  wMenuEntrySetCascade(menu, edit_item, edit);

  windows = createWindowsMenu(wapp);
  windows_item = wMenuAddCallback(menu, _("Windows"), NULL, NULL);
  wMenuEntrySetCascade(menu, windows_item, windows);
  
  tmp_item = wMenuAddCallback(menu, _("Hide"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("h");
  tmp_item = wMenuAddCallback(menu, _("Hide Others"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("H");
  tmp_item = wMenuAddCallback(menu, _("Quit"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("q");
  
  return menu;
}

void wApplicationOpenMenu(WApplication *wapp, int x, int y)
{
  WScreen *scr = wapp->main_wwin->screen_ptr;
  WMenu *menu;
  int i;

  if (!wapp->app_menu) {
    WMLogError("Applicastion menu can't be opened because it was not created");
    return;
  }
  menu = wapp->app_menu;

  /* set client data */
  for (i = 0; i < menu->entry_no; i++) {
    menu->entries[i]->clientdata = wapp;
  }
  
  if (wapp->flags.hidden) {
    menu->entries[3]->text = wstrdup(_("Unhide"));
  } else {
    menu->entries[3]->text = wstrdup(_("Hide"));
  }

  menu->flags.realized = 0;
  wMenuRealize(menu);
  
  /* Place menu on screen */
  x -= menu->frame->core->width / 2;
  if (x + menu->frame->core->width > scr->scr_width) {
    x = scr->scr_width - menu->frame->core->width;
  }
  if (x < 0) {
    x = 0;
  }
  wMenuMapAt(menu, x, y, False);
}