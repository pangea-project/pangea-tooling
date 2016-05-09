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

const { classes: Cc, interfaces: Ci, utils: Cu } = Components;

var EXPORTED_SYMBOLS = [ "IndicateBackend" ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://gre/modules/NetUtil.jsm");
Cu.import("resource://gre/modules/FileUtils.jsm");
Cu.import("resource://messagingmenu/modules/utils.jsm");
Cu.import("resource://messagingmenu/libs/glib.jsm");
Cu.import("resource://messagingmenu/libs/gobject.jsm");
Cu.import("resource://messagingmenu/libs/dbusmenu.jsm");
Cu.import("resource://messagingmenu/libs/indicate.jsm");

addLogger(this, "backend.libindicate");

const kUserBlacklistDir = ".config/indicators/messages/applications-blacklist/";

function LauncherEntryFind(aDir, aDesktopFile, aCallback) {
  new LauncherEntryFinder(aDir, aDesktopFile, aCallback);
}

// Small helper class which takes a directory containing messaging menu
// launcher entries and tells the listener whether one of them is ours
function LauncherEntryFinder(aDir, aDesktopFile, aCallback) {
  LOG("Searching for launcher entry for " + aDesktopFile + " in " + aDir.path);
  if (!aDir.exists() || !aDir.isDirectory()) {
    LOG(aDir.path + " does not exist or is not a directory");
    aCallback(null);
    return;
  }

  this.callback = aCallback;
  this.desktopFile = aDesktopFile;
  this.entries = aDir.directoryEntries;
  this.dir = aDir;

  this.processNextEntry();
}

LauncherEntryFinder.prototype = {
  processNextEntry: function MMEF_processNextEntry() {
    if (this.entries.hasMoreElements()) {
      var entry = this.entries.getNext().QueryInterface(Ci.nsIFile);
      if (!entry.isFile()) {
        this.processNextEntry();
      }
      var self = this;
      NetUtil.asyncFetch(entry, function(inputStream, status) {
        let data = NetUtil.readInputStreamToString(inputStream, inputStream.available());
        if (data.replace(/\n$/,"") == self.desktopFile) {
          LOG("Found launcher entry " + entry.path);
          self.callback(entry);
        } else {
          self.processNextEntry();
        }
      });
    } else {
      LOG("No launcher entry found");
      this.callback(null);
    }
  }
};

function IndicatorImpl(aIndicator, aBackend) {
  this._attention = false;
  this._newCount = 0;
  this._label = null;

  this._indicator = aIndicator;
  this._backend = aBackend;
  this._nativeIndicator = indicate.indicate_indicator_new();

  let self = this;
  this._sigid = gobject.g_signal_connect(this._nativeIndicator, "user-display",
                                         function(aNativeIndicator,
                                                  aTimestamp) {
    aBackend.activateCallback(self._indicator.folderURL, aTimestamp);
  });

  aIndicator.registerImpl(SimpleObjectWrapper(this));
}

IndicatorImpl.prototype = {
  __exposedProps__: ["requestAttention", "cancelAttention", "show", "hide",
                     "newCount", "label", "visible", "hasAttention",
                     "destroy"],

  requestAttention: function II_requestAttention() {
    if (this.visible) {
      indicate.indicate_indicator_set_property(this._nativeIndicator,
                                               indicate.INDICATOR_MESSAGES_PROP_ATTENTION,
                                               "true");
    }

    this._attention = true;
  },

  cancelAttention: function II_cancelAttention() {
    if (this.visible) {
      indicate.indicate_indicator_set_property(this._nativeIndicator,
                                               indicate.INDICATOR_MESSAGES_PROP_ATTENTION,
                                               "false");
    }

    this._attention = false;
  },

  show: function II_show() {
    if (!this.visible) {
      indicate.indicate_indicator_show(this._nativeIndicator);

      if (this._attention) {
        indicate.indicate_indicator_set_property(this._nativeIndicator,
                                                 indicate.INDICATOR_MESSAGES_PROP_ATTENTION,
                                                 "true");
      }
    }
  },

  hide: function II_hide() {
    if (this.visible) {
      indicate.indicate_indicator_hide(this._nativeIndicator);

      if (this._attention) {
        indicate.indicate_indicator_set_property(this._nativeIndicator,
                                                 indicate.INDICATOR_MESSAGES_PROP_ATTENTION,
                                                 "false");
      }
    }
  },

  get newCount() {
    return this._newCount;
  },

  set newCount(aCount) {
    indicate.indicate_indicator_set_property(this._nativeIndicator,
                                             indicate.INDICATOR_MESSAGES_PROP_COUNT,
                                             aCount.toString());

    this._newCount = aCount;
  },

  get label() {
    return this._label;
  },

  set label(aLabel) {
    indicate.indicate_indicator_set_property(this._nativeIndicator,
                                             indicate.INDICATOR_MESSAGES_PROP_NAME,
                                             aLabel);
    this._label = aLabel;
  },

  get visible() {
    return indicate.indicate_indicator_is_visible(this._nativeIndicator) != 0;
  },

  get hasAttention() {
    return this._attention;
  },

  destroy: function() {
    if (this._nativeIndicator) {
      gobject.g_signal_handler_disconnect(this._nativeIndicator, this._sigid);
      gobject.g_object_unref(this._nativeIndicator);
      this._nativeIndicator = null;
    }

    this._backend.unregisterIndicator(this._indicator);
  }
};

function IndicateBackend(aName, aActivationCallback, aOpen3PaneCallback,
                         aOpenComposeCallback, aOpenContactsCallback) {
  this._name = aName;
  this.activateCallback = aActivationCallback;

  this._server = indicate.indicate_server_ref_default();
  if (!this._server || this._server.isNull()) {
    throw Error("Failed to create libindicate server");
  }

  this._sigs = [];

  indicate.indicate_server_set_type(this._server, "message.email");
  indicate.indicate_server_set_desktop_file(this._server, this._desktopFile);

  this._sigs.push([this._server,
                   gobject.g_signal_connect(this._server, "server-display",
                                            function(aServer, aTimestamp) {
    aOpen3PaneCallback(aTimestamp);
  })]);

  let bundle = Services.strings.createBundle(
                "chrome://messagingmenu/locale/messagingmenu.properties");

  let server = dbusmenu.dbusmenu_server_new("/messaging/commands");
  let root = dbusmenu.dbusmenu_menuitem_new();

  let composeMi = dbusmenu.dbusmenu_menuitem_new();
  dbusmenu.dbusmenu_menuitem_property_set(composeMi, "label",
                                          bundle.GetStringFromName("composeNewMessage"));
  dbusmenu.dbusmenu_menuitem_property_set_bool(composeMi, "visible", true);

  this._sigs.push([composeMi,
                   gobject.g_signal_connect(composeMi,
                                            dbusmenu.MENUITEM_SIGNAL_ITEM_ACTIVATED,
                                            function(aItem, aTimestamp) {
    aOpenComposeCallback(aTimestamp);
  })]);

  dbusmenu.dbusmenu_menuitem_child_append(root, composeMi);
  // I can't believe that this doesn't inherit from GInitiallyUnowned.
  // It really, really sucks that we need to do this....
  gobject.g_object_unref(composeMi);

  let contactsMi = dbusmenu.dbusmenu_menuitem_new();
  dbusmenu.dbusmenu_menuitem_property_set(contactsMi, "label",
                                          bundle.GetStringFromName("contacts"));
  dbusmenu.dbusmenu_menuitem_property_set_bool(contactsMi, "visible", true);

  this._sigs.push([contactsMi,
                   gobject.g_signal_connect(contactsMi,
                                            dbusmenu.MENUITEM_SIGNAL_ITEM_ACTIVATED, 
                                            function(aItem, aTimestamp) {
    aOpenContactsCallback(aTimestamp);
  })]);

  dbusmenu.dbusmenu_menuitem_child_append(root, contactsMi);
  gobject.g_object_unref(contactsMi); // This too

  dbusmenu.dbusmenu_server_set_root(server, root);
  gobject.g_object_unref(root); // And this...

  indicate.indicate_server_set_menu(this._server, server);
  gobject.g_object_unref(server);

  this._indicators = {};

  return SimpleObjectWrapper(this);
}

IndicateBackend.prototype = {
  __exposedProps__: ["enable", "disable", "remove", "shutdown",
                     "registerIndicator"],

  enable: function IB_enable() {
    if (!this._server || this._server.isNull()) {
      throw Error("We have been shut down already");
    }

    indicate.indicate_server_show(this._server);

    let userBlacklistDir = Services.dirsvc.get("Home", Ci.nsILocalFile);
    userBlacklistDir.appendRelativePath(kUserBlacklistDir);
    LauncherEntryFind(userBlacklistDir, this._desktopFile, function(aFile) {
      if (aFile) {
        LOG("Removing launcher entry " + aFile.path);
        aFile.remove(false);
      }
    });
  },

  disable: function IB_disable() {
    if (!this._server || this._server.isNull()) {
      throw Error("We have been shut down already");
    }

    indicate.indicate_server_hide(this._server);
  },

  remove: function IB_remove() {
    if (!this._server || this._server.isNull()) {
      throw Error("We have been shut down already");
    }

    let userBlacklistDir = Services.dirsvc.get("Home", Ci.nsILocalFile);
    userBlacklistDir.appendRelativePath(kUserBlacklistDir);

    let self = this;
    LauncherEntryFind(userBlacklistDir, this._desktopFile, function(aFile) {
      if (aFile) {
        return;
      }

      if (!userBlacklistDir.exists()) {
        userBlacklistDir.create(Ci.nsILocalFile.DIRECTORY_TYPE, 0755);
      }

      let entry = userBlacklistDir.clone();
      entry.append(Services.appinfo.name.toLowerCase());
      let ostream = FileUtils.openSafeFileOutputStream(entry,
                                                       FileUtils.MODE_WRONLY |
                                                       FileUtils.MODE_CREATE |
                                                       FileUtils.MODE_TRUNCATE);
      let converter = Cc["@mozilla.org/intl/scriptableunicodeconverter"]
                      .createInstance(Ci.nsIScriptableUnicodeConverter);
      converter.charset = "UTF-8";
      let istream = converter.convertToInputStream(self._desktopFile);
      NetUtil.asyncCopy(istream, ostream, null);
    });
  },

  shutdown: function IB_shutdown() {
    if (this._server || this._server.isNull()) {
      this._sigs.forEach(function(sig) {
        gobject.g_signal_handler_disconnect(sig[0], sig[1]);
      });
      gobject.g_object_unref(this._server);
      this._server = null;
    }
  },

  registerIndicator: function IB_registerIndicator(aIndicator) {
    if (!this._server || this._server.isNull()) {
      throw Error("We have been shut down already");
    }

    if (!aIndicator) {
      throw Error("Invalid indicator entry");
    }

    if (aIndicator.folderURL in this._indicators) {
      throw Error("Indicator already registered with backend");
    }

    this._indicators[aIndicator.folderURL] = new IndicatorImpl(aIndicator,
                                                               this);
  },

  unregisterIndicator: function IB_unregisterIndicator(aIndicator) {
    if (!aIndicator) {
      throw Error("Invalid indicator entry");
    }

    if (!(aIndicator.folderURL in this._indicators)) {
      throw Error("Indicator is not registered with backend");
    }

    delete this._indicators[aIndicator.folderURL];
  },

  get _desktopFile() {
    return "/usr/share/applications/" + this._name;
  }
};
