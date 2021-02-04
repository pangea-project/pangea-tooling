/* -*- Mode: javascript; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 *	 Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 * 
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is messagingmenu-extension
 *
 * The Initial Developer of the Original Code is
 * Mozilla Messaging, Ltd.
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *    Mike Conley <mconley@mozillamessaging.com>
 *    Chris Coulson <chris.coulson@canonical.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 * 
 * ***** END LICENSE BLOCK ***** */

var EXPORTED_SYMBOLS = [ "MessagingMenu" ];

const Cc = Components.classes;
const Ci = Components.interfaces;
const Cu = Components.utils;

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://gre/modules/FileUtils.jsm");
Cu.import("resource://gre/modules/AddonManager.jsm");
Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource:///modules/mailServices.js");
Cu.import("resource:///modules/iteratorUtils.jsm");
Cu.import("resource:///modules/gloda/mimemsg.js");
Cu.import("resource://messagingmenu/modules/utils.jsm");
Cu.import("resource://messagingmenu/libs/glib.jsm");
Cu.import("resource://messagingmenu/libs/gobject.jsm");
Cu.import("resource://messagingmenu/libs/gdk.jsm");
Cu.import("resource://messagingmenu/libs/unity.jsm");
Cu.import("resource://messagingmenu/modules/LibMessagingMenuBackend.jsm");
Cu.import("resource://messagingmenu/modules/LibIndicateBackend.jsm");

addLogger(this);

const kUninterestingFolders = Ci.nsMsgFolderFlags.Trash
                              | Ci.nsMsgFolderFlags.Junk
                              | Ci.nsMsgFolderFlags.SentMail
                              | Ci.nsMsgFolderFlags.Drafts
                              | Ci.nsMsgFolderFlags.Templates
                              | Ci.nsMsgFolderFlags.Queue
                              | Ci.nsMsgFolderFlags.Archive;

const kMaxIndicators                    = 6;
const kAddonId                          = "messagingmenu@mozilla.com";
const kPrefRoot                         = "extensions.messagingmenu.";
const kPrefIncludeNewsgroups            = "includeNewsgroups";
const kPrefIncludeRSS                   = "includeRSS";
const kPrefEnabled                      = "enabled";
const kPrefAttentionForAll              = "attentionForAll";
const kPrefInboxOnly                    = "inboxOnly";
const kPrefAccounts                     = "mail.accountmanager.accounts";
const NS_PREFBRANCH_PREFCHANGE_TOPIC_ID = "nsPref:changed";

XPCOMUtils.defineLazyGetter(this, "gBackend", function() {
  try {
    var backend = new MessagingMenuBackend(Services.appinfo.name.toLowerCase()
                                           + '.desktop',
                                           onSourceActivated);
    LOG("Loaded libmessaging-menu backend");
  } catch(e) {
    try {
      var backend = new IndicateBackend(Services.appinfo.name.toLowerCase()
                                        + '.desktop',
                                        onSourceActivated, onOpen3Pane,
                                        onOpenCompose, onOpenContacts);
      LOG("Loaded libindicate backend");
    } catch(e) {}
  }

  return backend;
});

XPCOMUtils.defineLazyGetter(this, "gMessenger", function() {
  return Cc["@mozilla.org/messenger;1"].createInstance()
                                       .QueryInterface(Ci.nsIMessenger);
});

XPCOMUtils.defineLazyGetter(this, "gPrefs", function() {
  return new Prefs(Services.prefs.getBranch(kPrefRoot));
});

function injectTimestampHack(aTimestamp) {
  let atts = new gdk.GdkWindowAttributes;
  atts.window_type = 1;
  atts.x = atts.y = 0;
  atts.width = atts.height = 1;
  atts.wclass = 1;
  atts.event_mask = 0;
  let win = gdk.gdk_window_new(null, atts.address(), 0);
  gdk.gdk_x11_window_set_user_time(win, aTimestamp);
  gdk.gdk_window_destroy(win);
}

function openWindowByType(aType, aURL, aTimestamp) {
  let win = null;
  if (aType) {
    win = Cc["@mozilla.org/appshell/window-mediator;1"]
          .getService(Ci.nsIWindowMediator).getMostRecentWindow(aType);
  }

  if (!win) {
      win = Cc["@mozilla.org/embedcomp/window-watcher;1"]
            .getService(Ci.nsIWindowWatcher)
            .openWindow(null, aURL, "",
                        "chrome,extrachrome,menubar,resizable,scrollbars,status,toolbar", null);
  }

  if (win) {
    if (aTimestamp) {
      // Get the GdkWindow handle for this window. We handle 3 cases:
      // 1. TB17 and newer with nsIBaseWindow.nativeHandle
      // 2. Ubuntu TB15/16 with nsIBaseWindow_UBUNTU_ONLY.nativeHandle
      // 3. Pre-TB17 (or pre-TB15 Ubuntu builds) with no access to handle
      let nsIBaseWindow = Ci.nsIBaseWindow_UBUNTU_ONLY || Ci.nsIBaseWindow;
      let baseWin = win.QueryInterface(Ci.nsIInterfaceRequestor)
                    .getInterface(Ci.nsIWebNavigation)
                    .QueryInterface(Ci.nsIDocShellTreeItem)
                    .treeOwner
                    .QueryInterface(nsIBaseWindow);
      if (!("nativeHandle" in baseWin)) {
        injectTimestampHack(aTimestamp);
      } else {
        gdk.gdk_x11_window_set_user_time(gdk.GdkWindow
                                         .ptr(ctypes
                                              .UInt64(baseWin
                                                      .nativeHandle)),
                                         aTimestamp);
      }
    }

    win.focus();
  }

  return win;
}

function onSourceActivated(aFolderURL, aTimestamp) {
  LOG("Received click event on indicator for folder " + aFolderURL);

  let indicatorEntry = MessagingMenuEngine.mIndicators[aFolderURL];
  if (!indicatorEntry) {
    throw Error("No indicator for folder " + aFolderURL);
  }

  // Hide the indicator
  MessagingMenuEngine.hideIndicator(indicatorEntry);

  let msg = gMessenger.msgHdrFromURI(indicatorEntry.messageURL);
  if(!msg) {
    throw Error("Invalid message URI " + indicatorEntry.messageURL);
  }

  // Focus 3pane
  LOG("Opening 3pane");
  let win = openWindowByType("mail:3pane",
                             "chrome://messenger/content/messenger.xul",
                             aTimestamp)
  if (!win) {
    throw Error("Failed to open 3pane");
  }

  win.document.getElementById("tabmail").switchToTab(0);
  win.gFolderTreeView.selectFolder(msg.folder);
  win.gFolderDisplay.selectMessage(msg);
}

function onOpen3Pane(aTimestamp) {
  LOG("Opening 3pane");
  openWindowByType("mail:3pane",
                   "chrome://messenger/content/messenger.xul",
                   aTimestamp);
}

function onOpenCompose(aTimestamp) {
  LOG("Opening composer");
  openWindowByType(null,
                   "chrome://messenger/content/messengercompose/messengercompose.xul",
                   aTimestamp);
}

function onOpenContacts(aTimestamp) {
  LOG("Opening addressbook");
  openWindowByType("mail:addressbook",
                   "chrome://messenger/content/addressbook/addressbook.xul",
                   aTimestamp);
}

function hasMultipleAccounts() {
  let count = 0;
  // We don't want to just call Count() on the account nsISupportsArray, as we
  // want to filter out accounts with "none" as the incoming server type
  // (eg, for Local Folders)
  for (let account in fixIterator(MailServices.accounts.accounts,
                                  Ci.nsIMsgAccount)) {
    if (account.incomingServer.type != "none") {
      count++
    }
  }

  return count > 1;
}

// Helper class to wrap a nsIPrefBranch and allow the caller
// to specify default values to be used where the pref doesn't exist
function Prefs(aBranch) {
  this.branch = aBranch;
}

Prefs.prototype = {
  getBoolPref: function P_getBoolPref(aName, aDefaultValue) {
    try {
      return this.branch.getBoolPref(aName);
    } catch(e) {
      return aDefaultValue;
    }
  },

  setCharPref: function P_setCharPref(aName, aValue) {
    this.branch.setCharPref(aName, aValue);
  },

  getCharPref: function P_getCharPref(aName, aDefaultValue) {
    try {
      return this.branch.getCharPref(aName);
    } catch(e) {
      return aDefaultValue;
    }
  },

  setIntPrefAsChar: function P_setIntPrefAsChar(aName, aValue) {
    this.setCharPref(aName, aValue.toString());
  },

  getIntPrefFromChar: function P_getIntPrefFromChar(aName, aDefaultValue) {
    return parseInt(this.getCharPref(aName, aDefaultValue.toString()));
  },

  clearUserPref: function P_clearUserPref(aName) {
    this.branch.clearUserPref(aName);
  },

  addObserver: function P_addObserver(aDomain, aObserver, aHoldWeak) {
    this.branch.QueryInterface(Ci.nsIPrefBranch2)
      .addObserver(aDomain, aObserver, aHoldWeak);
  },

  removeObserver: function P_removeObserver(aDomain, aObserver) {
    this.branch.QueryInterface(Ci.nsIPrefBranch2)
      .removeObserver(aDomain, aObserver);
  }
};

function MMMessageFilterState() {
  this._shouldIndicate = null;
  this._shouldRequestAttention = null;
}

MMMessageFilterState.prototype = {
  acceptMessageIfTrue: function(aTest, aMsg) {
    if (this._shouldIndicate !== null)
      return;

    if (aTest()) {
      LOG("Accepting message: " + aMsg);
      this._shouldIndicate = true;
    }
  },

  rejectMessageIfTrue: function(aTest, aMsg) {
    if (this._shouldIndicate !== null)
      return;

    if (aTest()) {
      LOG("Rejecting message: " + aMsg);
      this._shouldIndicate = false;
    }
  },

  requestAttentionIfTrue: function(aTest, aMsg) {
    if (this._shouldIndicate == false || this._shouldRequestAttention != null)
      return;

    if (aTest()) {
      LOG("Requesting attention for message: " + aMsg);
      this._shouldRequestAttention = true;
    }
  },

  dontRequestAttentionIfTrue: function(aTest, aMsg) {
    if (this._shouldIndicate == false || this._shouldRequestAttention != null)
      return;

    if (aTest()) {
      LOG("Not requesting attention for message: " + aMsg);
      this._shouldRequestAttention = false;
    }
  },

  get shouldIndicate() {
    return this._shouldIndicate == true;
  },

  get shouldRequestAttention() {
    return this._shouldRequestAttention == true;
  }
};

/* Given a particular message header, determines whether or not
 * it's something that's worth showing in the Messaging Menu.
 *
 * @param aItemHeader An nsIMsgDBHdr for a message.
 * @param aCallback A function to call if the message should 
 *                  be indicated to the user
 */
function MMMessageFilter (aItemHeader, aCallback) {
  // FIXME:  This function needs a bit of cleanup - I think the plinko-style
  // boolean flag stuff could be done a bit better.
  // See bug 806123:  https://bugs.launchpad.net/messagingmenu-extension/+bug/806123

  LOG("Applying filter for message " + aItemHeader.folder.getUriForMsg(aItemHeader) +
      " in " + aItemHeader.folder.folderURL);

  var state = new MMMessageFilterState();
  var folder = aItemHeader.folder;

  state.rejectMessageIfTrue(function() {
    let junkScore = aItemHeader.getStringProperty("junkscore");
    return (junkScore != "" && junkScore != "0");
  }, "Message has junkscore != 0");

  state.rejectMessageIfTrue(function() {
    return (folder.flags & kUninterestingFolders) != 0;
  }, "Message in blacklisted folder");

  state.rejectMessageIfTrue(function() {
    return (aItemHeader.flags & Ci.nsMsgMessageFlags.New) == 0;
  }, "Message is not new");

  state.acceptMessageIfTrue(function() {
    return (folder.flags & Ci.nsMsgFolderFlags.Mail) != 0;
  }, "Message is mail message");

  state.acceptMessageIfTrue(function() {
    return (gPrefs.getBoolPref(kPrefIncludeNewsgroups, true) &&
            (folder.flags & Ci.nsMsgFolderFlags.Newsgroup) != 0);
  }, "Message is newsgroup message");

  state.acceptMessageIfTrue(function() {
    return (gPrefs.getBoolPref(kPrefIncludeRSS, true) &&
            folder.server.type == "rss");
  }, "Message is from RSS feed");

  MsgHdrToMimeMessage(aItemHeader, null, function(aMsgHdr, aMimeMsg) {

    state.requestAttentionIfTrue(function() {
      return gPrefs.getBoolPref(kPrefAttentionForAll, false);
    }, "attentionForAll preference is set to true");

    state.requestAttentionIfTrue(function() {
      return aItemHeader.priority >= Ci.nsMsgPriority.high;
    }, "Message sent with high priority");

    state.requestAttentionIfTrue(function() {
      return aItemHeader.isFlagged;
    }, "Message is starred");

    state.dontRequestAttentionIfTrue(function() {
      return (aItemHeader.priority <= Ci.nsMsgPriority.low &&
              aItemHeader.priority > Ci.nsMsgPriority.none);
    }, "Message sent with low priority");

    // Use of Precedence is discouraged by RFC 2076, but we use this to catch
    // message from Launchpad
    state.dontRequestAttentionIfTrue(function() {
      return ((aMimeMsg.has("auto-submitted") &&
               aMimeMsg.get("auto-submitted") != "no") ||
              (aMimeMsg.has("precedence") &&
               aMimeMsg.get("precedence") == "bulk"));
    }, "Automated message (Auto-Submitted != no || Precedence == bulk)");

    state.dontRequestAttentionIfTrue(function() {
      return aMimeMsg.has("list-id");
    }, "Mailing list message");

    state.dontRequestAttentionIfTrue(function() {
      if (!aMimeMsg.has("return-path"))
        return false;

      let re = /.*<([^>]*)>/;
      let rp = aMimeMsg.get("return-path").replace(re, "$1");
      let from = aItemHeader.author.replace(re, "$1");

      return rp != from;
    }, "Possible automated message (Return-Path != From)");

    state.dontRequestAttentionIfTrue(function() {
      if (!aMimeMsg.has("sender"))
        return false;

      let re = /.*<([^>]*)>/;
      let sender = aMimeMsg.get("sender").replace(re, "$1");
      let from = aItemHeader.author.replace(re, "$1");

      return sender.toLowerCase() != from.toLowerCase();
    }, "Possible automated message (Sender != From)");

    state.requestAttentionIfTrue(function() {
      let recipients = aItemHeader.recipients.split(",");
      let re = /.*<([^>]*)>/; // Convert "Foo <bar>" in to "bar"
      for (let i in recipients) {
        let recipient = recipients[i].replace(re, "$1").toLowerCase();

        for (let id in fixIterator(MailServices.accounts.allIdentities,
                                   Ci.nsIMsgIdentity)) {
          if (recipient.indexOf(id.email.toLowerCase()) != -1)
            return true;
        }
      }

      return false;
    }, "Message is addressed directly to us");

    if (state.shouldIndicate)
      aCallback(state.shouldRequestAttention);
  }, true, {
    partsOnDemand: true,
  });
}

function MMIndicatorEntry(aFolder) {
  LOG("Creating indicator for folder " + aFolder.folderURL);
  this._folder = aFolder;
  this.dateInSeconds = 0;
  this.messageURL = null;

  Services.prefs.addObserver(kPrefAccounts, this, false);
  gPrefs.addObserver("", this, false);

  gBackend.registerIndicator(SimpleObjectWrapper(this));

  this._refreshLabel();
}

MMIndicatorEntry.prototype = {
  __exposedProps__: ["registerImpl", "folderURL"],

  registerImpl: function MMIE_registerImpl(aImpl) {
    this._impl = aImpl;
  },
 
  requestAttention: function MMIE_requestAttention() {
    if (!this.active) {
      throw Error("Can't request attention for an inactive indicator");
    }

    LOG("Requesting attention for folder " + this.label);
    this._impl.requestAttention();
  },

  cancelAttention: function MMIE_cancelAttention() {
    LOG("Cancelling attention for folder " + this.label);
    this._impl.cancelAttention();
  },

  show: function MMIE_show() {
    if (!this.active) {
      throw Error("Cannot display an inactive indicator");
    }

    LOG("Showing indicator for folder " + this.label);
    this._impl.show();
  },

  hide: function MMIE_hide() {
    LOG("Hiding indicator for folder " + this.label);
    this._impl.hide();
  },

  set newCount(aCount) {
    LOG("Setting unread count for folder " + this.label +
        " to " + aCount.toString());
    this._impl.newCount = aCount;
  },

  get newCount() {
    return this._impl.newCount;
  },

  set label(aLabel) {
    LOG("Setting label for folder " + this.folderURL + " to " + aLabel);
    this._impl.label = aLabel;
  },

  get label() {
    return this._impl.label;
  },

  get active() {
    return this.newCount > 0;
  },

  get visible() {
    return this._impl.visible;
  },

  get folderURL() {
    return this._folder.folderURL;
  },

  get priority() {
    let score = 0;

    if (this._folder.flags & Ci.nsMsgFolderFlags.Inbox) {
      score += 3;
    }

    if (this._impl.hasAttention) {
      score += 1;
    }

    return score;
  },

  isInbox: function MMIE_isInbox() {
    return this._folder.flags & Ci.nsMsgFolderFlags.Inbox;
  },

  // We consider an indicator to be less important if:
  // 1) It has a lower priority, or
  // 2) It has the same priority and is more recent
  hasPriorityOver: function MMIE_hasPriorityOver(aIndicator) {
    return ((aIndicator.priority < this.priority) ||
            ((aIndicator.dateInSeconds > this.dateInSeconds) &&
             (aIndicator.priority == this.priority))) ? true : false;
  },

  _refreshLabel: function MMIE__refreshLabel() {
    if (gPrefs.getBoolPref("inboxOnly", false) &&
        this.isInbox()) {
      this.label = this._folder.server.prettyName;
    } else if (hasMultipleAccounts()) {
      this.label = this._folder.prettiestName +
                   " (" + this._folder.server.prettyName + ")";
    } else {
      this.label = this._folder.prettiestName;
    }
  },

  destroy: function MMIE_destroy() {
    LOG("Destroying indicator for folder " + this.folderURL);
    this._impl.destroy();
    this._impl = null;

    Services.prefs.removeObserver(kPrefAccounts, this);
    gPrefs.removeObserver("", this);
  },

  observe: function MMIE_observe(subject, topic, data) {
    if (data == kPrefAccounts) {
      // An account was added or removed. Note that this observer fires
      // before nsIMsgAccountManager is up-to-date, so we add the next
      // bit to the event loop
      LOG("Account settings updated. Updating label for folder " +
          this.folderURL);
      var self = this;
      let timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
      timer.initWithCallback(function(aTimer) {
        self.refreshLabel();
      }, 0, Ci.nsITimer.TYPE_ONE_SHOT);
    } else {
      this.refreshLabel();
    }
  }
};

var UnityLauncher = {

  get entry() {
    if (this._entry)
      return this._entry;

    var appName = Cc["@mozilla.org/xre/app-info;1"].
                    getService(Ci.nsIXULAppInfo).name.toLowerCase();
    this._entry =
      unity.unity_launcher_entry_get_for_desktop_id(appName + ".desktop");
    if (!this._entry)
      throw "Failed to create UnityLauncherEntry";

    Services.obs.addObserver(this, "xpcom-will-shutdown", false);

    return this._entry;
  },

  set entry(aEntry) {
    if (this._entry)
      gobject.g_object_unref(this._entry);

    this._entry = aEntry;
  },

  observe: function UL_observe(aSubject, aTopic, aData) {
    if (aTopic == "xpcom-will-shutdown") {
      this.entry = null;
      if (unity.available) {
        unity.close();
      }
    }
  },

  setCount: function UL_setCount(aCount) {
    if (!unity.available)
      return;

    if (aCount === null) {
      unity.unity_launcher_entry_set_count_visible(this.entry, false);
    } else {
      unity.unity_launcher_entry_set_count(this.entry, aCount);
      unity.unity_launcher_entry_set_count_visible(this.entry, true);
    }
  }
};

var MessagingMenuEngine = {
  __exposedProps__: ["available"],
  _backend: null,
  initialized: false,
  enabled: false,
  mIndicators: {},
  _badgeCount: 0,

  get available() {
    return (gobject.available &&
            gdk.available &&
            gBackend);
  },

  get badgeCount() {
    return this._badgeCount;
  },

  set badgeCount(aCount) {
    LOG("Setting total new count to " + aCount.toString());
    this._badgeCount = aCount;
    if (aCount > 0) {
      UnityLauncher.setCount(aCount);
    } else {
      UnityLauncher.setCount(null);
    }
  },

  get visibleCount() {
    let count = 0;
    for each (let indicator in this.mIndicators) {
      if (indicator.visible) {
        count += 1;
      }
    }

    LOG("Visible count = " + count);
    return count;
  },

  init: function MME_init() {
    if (this.initialized) {
      return;
    }

    LOG("Initializing MessagingMenu");

    if (!this.available) {
      WARN("The required libraries aren't available");
      this.initialized = true;
      return;
    }

    AddonManager.addAddonListener(this);
    gPrefs.addObserver("", this, false);
    Services.obs.addObserver(this, "xpcom-will-shutdown", false);

    this.badgeCount = 0;

    if (gPrefs.getBoolPref(kPrefEnabled, true)) {
      this.enable();
    } else {
      this.disableAndHide();
    }

    this.initialized = true;
  },

  enable: function MME_enable() {
    if (this.enabled) {
      WARN("Trying to enable more than once");
      return;
    }

    LOG("Enabling messaging indicator");
    gBackend.enable();

    let notificationFlags = Ci.nsIFolderListener.added |
                            Ci.nsIFolderListener.boolPropertyChanged
    MailServices.mailSession.AddFolderListener(this, notificationFlags);

    this.enabled = true;
  },

  disableAndHide: function MME_disableAndHide() {
    LOG("Hiding messaging indicator");

    gBackend.remove();
    this.disable();
  },

  cleanup: function MME_cleanup() { },

  disable: function MME_disable() {
    if (!this.enabled) {
      return;
    }

    LOG("Disabling messaging indicator");

    MailServices.mailSession.RemoveFolderListener(this);

    // Remove references for any leftover indicators
    for each (let indicator in this.mIndicators) {
      indicator.destroy();
    }
    this.mIndicators = {};

    gBackend.disable();
    this.badgeCount = 0;
    this.enabled = false;
  },

  shutdown: function MME_shutdown() {
    if (!this.initialized) {
      WARN("Calling shutdown before we are initialized");
      return;
    }

    LOG("Shutting down");

    this.disable();

    if (this._backend) {
      this._backend.shutdown();
      this._backend = null;
    }

    AddonManager.removeAddonListener(this);
    Services.obs.removeObserver(this, "xpcom-will-shutdown");
    gPrefs.removeObserver("", this);

    this.initialized = false;
  },

  refreshBadgeCount: function MME_refreshBadgeCount() {
    let inboxOnly = gPrefs.getBoolPref(kPrefInboxOnly, false);
    let accumulator = 0;
    for each (let indicator in this.mIndicators) {
      if (!indicator.isInbox() && inboxOnly) {
        continue;
      }

      accumulator += indicator.newCount;
    }

    this.badgeCount = accumulator;
  },

  refreshVisibility: function MME_refreshVisibility() {
    let inboxOnly = gPrefs.getBoolPref(kPrefInboxOnly, false);
    for each (let indicator in this.mIndicators) {
      if (!indicator.isInbox() && inboxOnly) {
        indicator.hide();
      } else {
        this.maybeShowIndicator(indicator);
      }
    }
  },

  maybeShowIndicator: function MME_maybeShowIndicator(aIndicator) {
    LOG("Maybe showing indicator for folder " + aIndicator.label);
    LOG("Indicator priority is " + aIndicator.priority.toString());

    if (!aIndicator.active) {
      LOG("Not showing inactive indicator");
      return;
    }

    // Don't show more than kMaxIndicators indicators
    if (this.visibleCount < kMaxIndicators) {
      aIndicator.show();
    } else {
      if (aIndicator.visible) {
        LOG("Indicator is already visible");
        return;
      }

      // We are already displaying kMaxIndicators. Lets see if one of the
      // current ones can be bumped off, to make way for the new one
      LOG("There are already " + kMaxIndicators.toString() + " visible indicators");
      let doomedIndicator = null;

      // This will make your head explode, but basically, what we want to do
      // is iterate over the currently displayed indicator entries and see if
      // one of them should make way for the new indicator.
      for each (let existingIndicator in this.mIndicators) {
        // This one already isn't visible, so don't care...
        if (!existingIndicator.visible) {
          continue;
        }

        let refIndicator = doomedIndicator ? doomedIndicator : aIndicator;

        if (refIndicator.hasPriorityOver(existingIndicator)) {
          LOG("Indicator with priority=" + existingIndicator.priority.toString() +
              " and dateInSeconds=" + existingIndicator.dateInSeconds + " is " +
              " a candidate for hiding");
          doomedIndicator = existingIndicator;
        }
      }

      if (doomedIndicator) {
        doomedIndicator.hide();
        aIndicator.show();
      }
    }
  },

  /* Given a message header, displays an indicator for it's folder
   * and requests attention
   *
   * @param aItemHeader A nsIMsgDBHdr for the message that we're
   *        trying to show in the Messaging Menu.
   */
  doIndication: function MME_doIndication(aItemHeader, aShouldRequestAtt) {
    let itemFolder = aItemHeader.folder;
    let folderURL = itemFolder.folderURL;
    LOG("Doing indication for folder " + folderURL);
    if (!this.mIndicators[folderURL]) {
      // Create an indicator for this folder if one doesn't already exist
      this.mIndicators[folderURL] = new MMIndicatorEntry(itemFolder);
    }

    let indicator = this.mIndicators[folderURL];

    LOG("Current indicator dateInSeconds = " + indicator.dateInSeconds.toString());
    LOG("Message item dateInSeconds = " + aItemHeader.dateInSeconds.toString());
    if (indicator.active) {
      LOG("Indicator for folder is already active");
    }

    if (!indicator.active ||
        (indicator.dateInSeconds > aItemHeader.dateInSeconds)) {
      indicator.messageURL = itemFolder.getUriForMsg(aItemHeader);
      indicator.dateInSeconds = aItemHeader.dateInSeconds;
    }

    indicator.newCount += 1;

    if (aShouldRequestAtt) {
      indicator.requestAttention();
    }

    if (!indicator.isInbox() && gPrefs.getBoolPref("inboxOnly", false)) {
      LOG("Suppressing non-inbox indicator in inbox-only mode");
      return;
    }

    this.badgeCount += 1;

    this.maybeShowIndicator(indicator);
  },

  hideIndicator: function MME_hideIndicator(aIndicator) {
    delete this.mIndicators[aIndicator.folderURL];
    aIndicator.destroy();

    this.refreshBadgeCount();
    if (this.visibleCount < kMaxIndicators) {
      this.refreshVisibility();
    }
  },

  /* Observes when items are added to folders, and when
   * message flags change.  Also listens for notifications
   * sent by uMessagingMenuService for opening messages based
   * on an Indicator that was clicked.
   */
  OnItemAdded: function MME_OnItemAdded(parentItem, item) {
    if (item instanceof Ci.nsIMsgDBHdr) {
      LOG("Item " + item.folder.getUriForMsg(item) + " added to " +
          item.folder.folderURL);
      let self = this;
      MMMessageFilter(item, function(aShouldRequestAtt) {
        try {
          self.doIndication(item, aShouldRequestAtt);
        } catch(e) { ERROR("Error running filter on message", e); }
      });
    }
  },

  OnItemBoolPropertyChanged: function MME_OnItemBoolPropertyChanged(item,
                                                                    property,
                                                                    oldValue,
                                                                    newValue) {
    if (item instanceof Ci.nsIMsgFolder &&
        item.folderURL in this.mIndicators &&
        property.toString() == "NewMessages" && newValue == false) {
      LOG("Folder " + item.folderURL + " no longer has new messages");
      this.hideIndicator(this.mIndicators[item.folderURL]);
    }
  },

  observe: function(aSubject, aTopic, aData) {
    if (aTopic == "xpcom-will-shutdown") {
      LOG("Got shutdown notification");
      this.shutdown();
    } else if (aTopic == NS_PREFBRANCH_PREFCHANGE_TOPIC_ID) {
      LOG("Got prefchange notification for " + aData);
      if (aData == kPrefEnabled) {
        let prefs = new Prefs(aSubject.QueryInterface(Ci.nsIPrefBranch));
        let enabled = prefs.getBoolPref(aData, true);
        if (enabled) {
          this.enable();
        } else {
          this.disableAndHide();
        }
      } else if (aData == kPrefInboxOnly) {
        this.refreshVisibility();
        this.refreshBadgeCount();
      }
    } else {
      WARN("Observer notification not intended for us: " + aTopic);
    }
  },

  onUninstalling: function(aAddon, aNeedsRestart) {
    if (aAddon.id == kAddonId) {
      LOG("Addon is being uninstalled");
      this.cleanup();
    }
  },

  onDisabling: function(aAddon, aNeedsRestart) {
    if (aAddon.id == kAddonId) {
      LOG("Addon is being disabled");
      this.disableAndHide();
    }
  },

  onEnabling: function(aAddon, aNeedsRestart) {
    if (aAddon.id == kAddonId) {
      LOG("Addon is being enabled");
      this.enable();
    }
  }
}

MessagingMenuEngine.init();

var MessagingMenu = SimpleObjectWrapper(MessagingMenuEngine);
