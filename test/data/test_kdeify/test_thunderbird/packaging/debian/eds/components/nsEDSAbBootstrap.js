/* -*- Mode: javascript; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
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
 * The Original Code is edsintegration.
 *
 * The Initial Developer of the Original Code is
 * Mozilla Corp.
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 * Mike Conley <mconley@mozilla.com>
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

const { utils: Cu, classes: Cc, interfaces: Ci } = Components;

const PREF_BRANCH = "ldap_2.servers.eds.";

Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSDirectory.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSMailingList.jsm");

addLogger(this, "eds.bootstrap");

function nsEDSAbBootstrap() {
  // Establish shutdown hook
  LOG("Starting EDS addressbook module");
  Services.obs.addObserver(this, "quit-application-granted", false);

  // Add the bootstrap pref if it doesn't already exist.
  this.ensureInstalledPrefs(); 
}

nsEDSAbBootstrap.prototype = {
  classDescription: "EDS Address Book Bootstrapper",
  classID: Components.ID("{5455275c-32b0-44c2-80bd-2a4457f854df}"),
  contractID: "@mozilla.org/addressbook/eds-bootrapper;1",
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIObserver]),

  _branch: null,
  get branch() {
    if (!this._branch) {
      this._branch = Services.prefs.getBranch(PREF_BRANCH);
    }
    return this._branch;
  },

  observe: function(aSubject, aTopic, aData) {
    if (aTopic != "quit-application-granted") {
      return;
    }

    this.shutdown();
  },

  shutdown: function EDSI_shutdown() {
    // Get each EDS directory and shut them down.
    LOG("Shutting down EDS integration...");
    for (let uri in gAbLookup) {
      LOG("Shutting down EDS address book with URI: " + uri);
      if (gAbLookup[uri]) {
        gAbLookup[uri].shutdown();
        delete gAbLookup[uri];
      }
    }
  },

  ensureInstalledPrefs: function EDSI_ensureInstalledPrefs() {
    // Install the prefs
    LOG("Installing EDS bootstrap prefs.");
    this.branch.setCharPref("uri", "moz-abedsdirectory://");
    this.branch.setCharPref("filename", "eds.mab");
    this.branch.setCharPref("description", "EDS Address Book Bootstrapper");
    this.branch.setIntPref("dirType", 3);
    this.branch.setIntPref("position", 1);
  }
};

var NSGetFactory = XPCOMUtils.generateNSGetFactory([nsEDSAbBootstrap,
                                                    nsAbEDSDirectory,
                                                    nsAbEDSDirFactory,
                                                    nsAbEDSMailingList]);
