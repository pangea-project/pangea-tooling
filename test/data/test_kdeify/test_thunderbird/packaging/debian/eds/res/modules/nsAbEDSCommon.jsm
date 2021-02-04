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

const { interfaces: Ci, utils: Cu } = Components;

var EXPORTED_SYMBOLS = [ "kPropertiesChromeURI",
                         "kExtensionChromeID",
                         "gAbLookup",
                         "CreateSimpleEnumerator",
                         "CreateSimpleObjectEnumerator",
                         "_" ];

const kExtensionChromeID = "chrome://edsintegration";
const kPropertiesChromeURI = "chrome://messenger/content/addressbook/abAddressBookNameDialog.xul";

Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource://gre/modules/AddonLogging.jsm");
Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");

addLogger(this);

// Addressbooks, mapped by URI
var gAbLookup = {};

function CreateSimpleEnumerator(aArray) {
  return {
    _i: 0,
    QueryInterface: XPCOMUtils.generateQI([Ci.nsISimpleEnumerator]),
    hasMoreElements: function CSE_hasMoreElements() {
      return this._i < aArray.length;
    },
    getNext: function CSE_getNext() {
      return aArray[this._i++];
    }
  };
}

function CreateSimpleObjectEnumerator(aObj) {
  return {
    _i: 0,
    _keys: Object.keys(aObj),
    QueryInterface: XPCOMUtils.generateQI([Ci.nsISimpleEnumerator]),
    hasMoreElements: function CSOE_hasMoreElements() {
      return this._i < this._keys.length;
    },
    getNext: function CSOE_getNext() {
      return aObj[this._keys[this._i++]];
    }
  };
}

var StringHelper = {
  get bundle() {
    if (!this._bundle) {
      this._bundle = Services.strings.createBundle("chrome://edsintegration/locale/edsCommon.properties"); 
    }
    return this._bundle;
  },
  
  getString: function SH_getString(aStringName, aInjectionArray) {
    try {
      if (Array.isArray(aInjectionArray)) {
        return StringHelper.bundle.formatStringFromName(aStringName, aInjectionArray,
                                                        aInjectionArray.length);
      }
      return StringHelper.bundle.GetStringFromName(aStringName);
    } catch(e) {
      ERROR("Could not find translation string with name: " + aStringName, e);
    }
    return "";
  },
}

var _ = StringHelper.getString;
