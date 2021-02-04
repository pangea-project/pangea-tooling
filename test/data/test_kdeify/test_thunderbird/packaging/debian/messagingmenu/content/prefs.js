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

var gMessagingMenuPrefs = {};

(function() {
  Components.utils.import("resource://gre/modules/Services.jsm");
  Components.utils.import("resource://messagingmenu/modules/MessagingMenuModule.jsm");

  if (!MessagingMenu.available) return;

  this.updateState = function() {
    let inboxOnlyCheck = document.getElementById("indicatorInboxOnly");
    let enabledCheck = document.getElementById("indicatorEnabled");
    inboxOnlyCheck.disabled = !enabledCheck.checked;
  }

  let generalPane = document.getElementById("paneGeneral");
  var self = this;
  generalPane.addEventListener("paneload", function onLoad() {

    function addInboxOnlyRadio(box, bundle) {
      let group = document.createElement("radiogroup");
      group.setAttribute("id", "indicatorInboxOnly");
      group.setAttribute("preference", "extensions.messagingmenu.inboxOnly");
      group.setAttribute("class", "indent");
      box.appendChild(group);

      let item = document.createElement("radio");
      item.setAttribute("value", "false");
      item.setAttribute("label", bundle.getString("allFoldersPref"));
      group.appendChild(item);

      item = document.createElement("radio");
      item.setAttribute("value", "true");
      item.setAttribute("label", bundle.getString("inboxOnlyPref"));
      group.appendChild(item);

      // XXX: Why do we need to do this? Our radiogroup has a preference attribute
      //      which points to a node that already exists in the document...
      group.selectedIndex = Services.prefs.getBoolPref("extensions.messagingmenu.inboxOnly") ? 1 : 0;
    }

    function addEnableCheck(box, bundle) {
      let checkbox = document.createElement("checkbox");

      checkbox.setAttribute("id", "indicatorEnabled");
      checkbox.setAttribute("label", bundle.getString("enablePref"));
      checkbox.setAttribute("preference", "extensions.messagingmenu.enabled");

      // XXX: Why do we need to do this? Our checkbox has a preference attribute
      //      which points to a node that already exists in the document...
      if (Services.prefs.getBoolPref("extensions.messagingmenu.enabled")) {
        checkbox.setAttribute("checked", "true");
      }

      checkbox.setAttribute("oncommand", "gMessagingMenuPrefs.updateState()");

      box.appendChild(checkbox);
    }

    generalPane.removeEventListener("paneload", onLoad, false);

    // XXX: We can't use an overlay here, as the groupbox we want to drop
    //      our checkbox in has no ID. So, we find it and add the checkbox
    //      manually
    try {
      let box = document.getElementById("newMailNotification").parentNode;
      let bundle = document.getElementById("bundleMessagingMenu");

      addEnableCheck(box, bundle);
      addInboxOnlyRadio(box, bundle);
      self.updateState();
    } catch(e) { }

  }, false);
}).call(gMessagingMenuPrefs);
