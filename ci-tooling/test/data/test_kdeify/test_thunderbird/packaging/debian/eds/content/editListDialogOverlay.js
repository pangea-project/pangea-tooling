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

Components.utils.import("resource://gre/modules/Services.jsm");
Components.utils.import("resource:///modules/mailServices.js");
Components.utils.import("resource:///modules/iteratorUtils.jsm");

Components.utils.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");

var EDSMailingListEditor = {

  _active: null,

  get bundle() {
    if (this._bundle)
      return this._bundle;

    this._bundle = Services.strings.createBundle("chrome://edsintegration/locale/contactEditor.properties");
    return this._bundle;
  },

  getString: function EDSMLE_getString(aStringName) {
    try {
      return this.bundle.GetStringFromName(aStringName);
    }
    catch (e) {
      Services.console.logStringMessage(e.message);
    }
    return "";
  },

  onLoad: function EDSMLE_onLoad(aDocument) {
    RegisterLoadListener(EDSMailingListEditor.onLoadList);
  },

  goInert: function EDSMLE_goInert(aDocument) {
    if (this._active == false) {
      return;
    }

    // Unregister save listener;
    UnregisterSaveListener(EDSMailingListEditor.onSaveList);
    aDocument.getElementById("ListNickNameContainer").collapsed = false;
    aDocument.getElementById("ListDescriptionContainer").collapsed = false;
    aDocument.getElementById("HidesRecipientsContainer").collapsed = true;
    aDocument.defaultView.sizeToContent();
    this._active = false;
  },

  goActive: function EDSMLE_goActive(aDocument, aDirectory) {
    if (this._active) {
      return;
    }

    RegisterSaveListener(EDSMailingListEditor.onSaveList);
    aDocument.getElementById("ListNickNameContainer").collapsed = true;
    aDocument.getElementById("ListDescriptionContainer").collapsed = true;
    aDocument.getElementById("HidesRecipientsContainer").collapsed = false;
    aDocument.defaultView.sizeToContent();
    this._active = true;
  },

  onLoadList: function EDSMLE_onLoadList(aList, aDocument) {
    // If we're editing an EDS Mailing List, or creating a new
    // mailing list under an nsIAbEDSDirectory, then aList should
    // query to nsIAbEDSDirectory.
    var edsList;
    try {
      edsList = aList.QueryInterface(Components.interfaces
                                     .nsIAbEDSDirectory);
    } catch(e) {
      // It isn't, bail out
      EDSMailingListEditor.goInert(aDocument);
      return;
    }
    
    // Gah, have to set gListCard to null, otherwise the double-clicked
    // entry for editing will get its displayName overwritten.  Ugh.
    gListCard = null;
    EDSMailingListEditor.goActive(aDocument, edsList.parentDirectory);
    var hideRecips = aDocument.getElementById("HidesRecipients");
    hideRecips.checked = aList.getBoolValue("HidesRecipients", false);
  },

  onSaveList: function EDSMLE_onSaveList(aList, aDocument) {
    if (!aList)
      return;

    let edsList = aList.QueryInterface(Components.interfaces
                                       .nsIAbEDSMailingList);
    let hideRecips = aDocument.getElementById("HidesRecipients");
    edsList.setBoolValue("HidesRecipients", hideRecips.checked);
  },

  populateEDSFields: function EDSMLE_PopulateEDSFields(aList, aDocument) {
    if (aList.getBoolValue("HidesRecipients", false)) {
      let hideRecips = aDocument.getElementById("HidesRecipients");
      hideRecips.checked = true;
    }
  },
}

EDSMailingListEditor.onLoad(document);
