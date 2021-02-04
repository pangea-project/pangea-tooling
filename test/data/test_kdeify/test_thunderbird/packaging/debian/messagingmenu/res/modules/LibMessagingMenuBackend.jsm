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
 *    Chris Coulson <chris.coulson@canonical.com>
 *    Lars Uebernickel < lars.uebernickel@canonical.com>
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

const { utils: Cu } = Components;

var EXPORTED_SYMBOLS = [ "MessagingMenuBackend" ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://messagingmenu/modules/utils.jsm");
Cu.import("resource://messagingmenu/libs/glib.jsm");
Cu.import("resource://messagingmenu/libs/gobject.jsm");
Cu.import("resource://messagingmenu/libs/messagingmenu.jsm");

addLogger(this, "backend.libmessagingmenu");

function IndicatorImpl(aIndicator, aBackend) {
  this._attention = false;
  this._newCount = 0;
  this._label = null;
  this._backend = aBackend;
  this._indicator = aIndicator;
  aIndicator.registerImpl(this);
}

IndicatorImpl.prototype = {
  __exposedProps__: ["requestAttention", "cancelAttention", "show", "hide",
                     "newCount", "label", "visible", "hasAttention",
                     "destroy"],

  requestAttention: function II_requestAttention() {
    if (this.visible) {
      messagingmenu.messaging_menu_app_draw_attention(this._backend.mmapp,
                                                      this._indicator.folderURL);
    }

    this._attention = true;
  },

  cancelAttention: function II_cancelAttention() {
    if (this.visible) {
      messagingmenu.messaging_menu_app_remove_attention(this._backend.mmapp,
                                                        this._indicator.folderURL);
    }

    this._attention = false;
  },

  show: function II_show() {
    if (!this.visible) {
      messagingmenu.messaging_menu_app_append_source_with_count(this._backend.mmapp,
                                                                this._indicator.folderURL,
                                                                null,
                                                                this.label,
                                                                this.newCount);

      if (this._attention) {
        messagingmenu.messaging_menu_app_draw_attention(this._backend.mmapp,
                                                        this._indicator.folderURL);
      }
    }
  },

  hide: function II_hide() {
    if (this.visible) {
      messagingmenu.messaging_menu_app_remove_source(this._backend.mmapp,
                                                     this._indicator.folderURL);
    }
  },

  get newCount() {
    return this._newCount;
  },

  set newCount(aCount) {
    if (this.visible) {
      messagingmenu.messaging_menu_app_set_source_count(this._backend.mmapp,
                                                        this._indicator.folderURL,
                                                        aCount);
    }

    this._newCount = aCount;
  },

  get label() {
    return this._label;
  },

  set label(aLabel) {
    this._label = aLabel;
  },

  get visible() {
    return messagingmenu.messaging_menu_app_has_source(this._backend.mmapp,
                                                       this._indicator.folderURL) != 0;
  },

  get hasAttention() {
    return this._attention;
  },

  destroy: function() {
    this.hide();
    this._backend.unregisterIndicator(this._indicator);
  }
};

function MessagingMenuBackend(aName, aActivationCallback) {
  this.mmapp = messagingmenu.messaging_menu_app_new(aName);
  this._indicators = {};

  if (!this.mmapp || this.mmapp.isNull()) {
    throw Error("Failed to initialize backend");
  }

  this._sigid = gobject.g_signal_connect(this.mmapp, "activate-source",
                                         function(aApp, aId) {
    aActivationCallback(aId.readString());
  });

  return SimpleObjectWrapper(this);
}

MessagingMenuBackend.prototype = {
  __exposedProps__: ["enable", "disable", "remove", "shutdown",
                     "registerIndicator"],

  enable: function MMB_enable() {
    if (!this.mmapp || this.mmapp.isNull()) {
      throw Error("We have been shut down already");
    }

    messagingmenu.messaging_menu_app_register(this.mmapp);
  },

  disable: function MMB_disable() {},

  remove: function MMB_remove() {
    if (!this.mmapp || this.mmapp.isNull()) {
      throw Error("We have been shut down already");
    }

    messagingmenu.messaging_menu_app_unregister(this.mmapp);
  },

  shutdown: function MMB_shutdown() {
    if (this.mmapp || this.mmapp.isNull()) {
      gobject.g_signal_handler_disconnect(this.mmapp, this._sigid);
      gobject.g_object_unref(this.mmapp);
      this.mmapp = null;
    }
  },

  registerIndicator: function MMB_registerIndicator(aIndicator) {
    if (!this.mmapp || this.mmapp.isNull()) {
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

  unregisterIndicator: function MMB_unregisterIndicator(aIndicator) {
    if (!aIndicator) {
      throw Error("Invalid indicator entry");
    }

    if (!(aIndicator.folderURL in this._indicators)) {
      throw Error("Indicator is not registered with backend");
    }

    delete this._indicators[aIndicator.folderURL];
  }
};
