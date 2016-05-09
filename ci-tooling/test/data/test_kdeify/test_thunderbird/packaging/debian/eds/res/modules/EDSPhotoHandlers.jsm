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

var EXPORTED_SYMBOLS = [ "EDSPhotoHandler",
                         "EDSGenericPhotoHandler",
                         "EDSFilePhotoHandler",
                         "EDSWebPhotoHandler"]

const Cc = Components.classes;
const Ci = Components.interfaces;
const Cu = Components.utils;
const Cr = Components.results;

const DEFAULT_PHOTO_URI = "chrome://messenger/skin/addressbook/icons/contact-generic.png";

Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");

addLogger(this);

var EDSPhotoHandler = {
  onLoad: function(aCard, aDocument) {
    return true;
  },
  onShow: function(aCard, aDocument, aTargetID) {
    LOG("Setting in EDSPhotoHandler"); 
    var data = aCard.getProperty("RawData", null);
    var dataUri = "";

    if (data) {
      var mime = aCard.getProperty("MimeType", "");
      dataUri = "data:" + mime + ";base64," + btoa(data);
    }

    aDocument.getElementById(aTargetID).setAttribute("src", dataUri); 
    return true;
  },
  onSave: function(aCard, aDocument) {
    return true;
  }
}

var EDSGenericPhotoHandler = {
  onLoad: function(aCard, aDocument) {
    return true;
  },
  onShow: function(aCard, aDocument, aTargetID) {
    LOG("Setting in EDSGenericPhotoHandler");
    aDocument
    .getElementById(aTargetID)
    .setAttribute("src", DEFAULT_PHOTO_URI);
    return true;
  },
  onSave: function(aCard, aDocument) {
    aCard.setProperty("RawData", null);
    return true;
  }
}

var EDSFilePhotoHandler = {
  onLoad: function(aCard, aDocument) {
    return false;
  },
  onShow: function(aCard, aDocument, aTargetID) {
    LOG("Setting in EDSFilePhotoHandler");
    var file = aDocument.getElementById("PhotoFile").file;
    try {
      var value = Services.io.newFileURI(file).spec;
    } catch (e) {}

    if (!value)
      return false;

    aDocument.getElementById(aTargetID).setAttribute("src", value);
    return true;

  },
  onSave: function(aCard, aDocument) {
    // Turn the file photo into a bitstream that we can feed
    // into the nsIAbEDSCard.
    var file = aDocument.getElementById("PhotoFile").file;
    var uri = null;
    try {
      uri = Services.io.newFileURI(file).spec;
    } catch (e) {}

    if (!uri)
      return false;

    var data = getPhotoContentDump(uri);
    aCard.setProperty("RawData", data);
    return true;
  }
}

var EDSWebPhotoHandler = {
  onLoad: function(aCard, aDocument) {
    return false;
  },

  onShow: function(aCard, aDocument, aTargetID) {
    LOG("Setting in EDSWebPhotoHandler");
    var photoURI = aDocument.getElementById("PhotoURI").value;

    if (!photoURI)
      return false;

    aDocument.getElementById(aTargetID).setAttribute("src", photoURI);
    return true;
  },

  onSave: function(aCard, aDocument) {
    // Turn the web photo into a bitstream that we can feed
    // into the nsIAbEDSCard.
    var uri = aDocument.getElementById("PhotoURI").value;
    var data = getPhotoContentDump(uri);
    aCard.setProperty("RawData", data);
    return true;
  }
}

function getPhotoContentDump(aURI)
{
  if (!aURI)
    return false;

  Components.utils.import("resource://gre/modules/Services.jsm");
  Components.utils.import("resource://gre/modules/NetUtil.jsm");

  var channel = NetUtil.newChannel(aURI);
  var istream = channel.open();

  var bstream = Components.classes["@mozilla.org/binaryinputstream;1"].createInstance(Components.interfaces.nsIBinaryInputStream);
  bstream.setInputStream(istream);
  var data = [];
  while(bstream.available())
    data = data.concat(bstream.readByteArray(bstream.available()));
  return data;
}

