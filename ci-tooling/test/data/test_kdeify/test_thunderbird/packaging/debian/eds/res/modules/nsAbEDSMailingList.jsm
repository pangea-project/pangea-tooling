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

const { classes: Cc, interfaces: Ci, results: Cr, utils: Cu } = Components;

var EXPORTED_SYMBOLS = [ "nsAbEDSMailingList" ];

const kMailListDirType = "moz-abedsmailinglist";
const kMailListDirScheme = kMailListDirType + "://";
const kMailListDirContractID = "@mozilla.org/addressbook/directory;1?type=" + kMailListDirType;

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource:///modules/mailServices.js");
Cu.import("resource:///modules/iteratorUtils.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");
Cu.import("resource://edsintegration/libs/gio.jsm");
Cu.import("resource://edsintegration/libs/eds.jsm");
Cu.import("resource://edsintegration/libs/ebook.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");

addLogger(this);

function nsAbEDSMailingList(aParent, aContact) {
  if (!aParent != !aContact) {
    throw Cr.NS_ERROR_INVALID_ARG;
  }

  this.wrappedJSObject = this;

  this._edsClient = null;
  this._edsContact = null;
  this._uri = "";
  this._childCards = null;

  if (aParent) {
    this.edsClient = aParent._edsClient;
  }
  if (aContact) {
    this._edsContact = ctypes.cast(gobject.g_object_ref(aContact),
                                   ebook.EContact.ptr);
  }

  if (this.edsClient && this.edsContact) {
    this._updateCards();
  }
}

nsAbEDSMailingList.prototype = {
  classDescription: "Evolution Data Server Address Book Mailing List Type",
  classID: Components.ID("{71e30b23-9bd0-41a0-8496-a10052698a00}"),
  contractID: kMailListDirContractID,
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIAbEDSMailingList,
                                         Ci.nsIAbEDSDirectory,
                                         Ci.nsIAbDirectory,
                                         Ci.nsIAbCollection,
                                         Ci.nsIAbItem]),

  get edsClient() {
    return this._edsClient;
  },

  set edsClient(aClient) {
    if (this._edsClient) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    this._edsClient = ctypes.cast(gobject.g_object_ref(aClient),
                                  eds.EClient.ptr);
  },

  get edsContact() {
    return this._edsContact;
  },

  set edsContact(aContact) {
    if (!aContact || aContact.isNull()) {
      throw Cr.NS_ERROR_INVALID_ARG;
    }

    let cstr = ctypes.cast(ebook.e_contact_get_const(aContact,
                                                     ebook.EContactFieldEnums
                                                          .E_CONTACT_UID),
                             glib.gchar.ptr);
    if (cstr.isNull()) {
      throw Error("EContact has no UID");
    }

    let uid = cstr.readString();

    if (this._edsContact && uid != this.edsId) {
      throw Error("Cannot change UID!! Old UID=" + this.edsId + ", new UID=" + uid);
    }

    if (!this._edsContact) {
      LOG("UID for " + this.URI + " is " + uid);
    } else {
      LOG("Updating mailing list for " + uid);
    }

    if (this._edsContact) {
      var oldDirName = this.dirName;
      var oldContact = this._edsContact;
      var oldHidesRecipient = this.getBoolValue("HidesRecipients", null);
    }

    this._edsContact = ctypes.cast(gobject.g_object_ref(aContact),
                                   ebook.EContact.ptr);

    if (oldContact) {
      let newDirName = this.dirName;
      let newHidesRecipients = this.getBoolValue("HidesRecipients", null);

      if (oldDirName != newDirName) {
        MailServices.ab.notifyItemPropertyChanged(this, "DirName",
                                                  oldDirName,
                                                  newDirName);
      }

      if (oldHidesRecipients != newHidesRecipients) {
        MailServices.ab.notifyItemPropertyChanged(this, "HidesRecipients",
                                                  oldHidesRecipients,
                                                  newHidesRecipients);
      }

      gobject.g_object_unref(oldContact);
    }

    this._updateCards();
  },

  _updateCards: function AbEDSML__updateCards() {
    LOG("Building mailing list for " + this.edsId);

    for (let card in fixIterator(this.addressLists, Ci.nsIAbCard)) {
      MailServices.ab.notifyDirectoryItemDeleted(this, card);
    }

    this._childCards = null;

    // In an EDS mailing list, we just have email addresses.
    // Nothing more, nothing less. No need to create a special
    // nsIAbEDSCard for these - we'll just use vanilla nsIAbCard's.
    for (let emailc in glib.listIterator(ctypes.cast(ebook.e_contact_get(this.edsContact,
                                                                         ebook.EContactFieldEnums
                                                                              .E_CONTACT_EMAIL),
                                                     glib.GList.ptr),
                                         glib.gchar.ptr, true, glib.g_free)) {
      let card = Cc["@mozilla.org/addressbook/cardproperty;1"]
                 .createInstance(Ci.nsIAbCard);

      let email = emailc.readString();

      // EDS stores the addresses like this:
      // username <email@domain.com>
      //
      // I'll use the headerParser to extract the address and the
      // name to insert into the nsIAbCard's.
      let address = MailServices
                    .headerParser
                    .extractHeaderAddressMailboxes(email);

      let name = MailServices
                 .headerParser
                 .extractHeaderAddressName(email);

      LOG("Adding " + email + " (address=" + address + ", name=" + name + ")");

      card.setProperty("PrimaryEmail", address);
      card.setProperty("DisplayName", name);

      // We want the mailing list editor to appear when double-clicking
      // on this card, so we'll pretend this card is a mailing list,
      // and pass it our URI.  A little hack-y, but it does the job.
      card.isMailList = true;
      card.mailListURI = this.URI;
      this.addressLists.appendElement(card, false);
      MailServices.ab.notifyDirectoryItemAdded(this, card);
    }
  },

  flush: function AbEDSML_flush() {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    LOG("Flushing address list to EDS contact for " + this.edsId);

    let vcard = ctypes.cast(this.edsContact, ebook.EVCard.ptr);

    ebook.e_vcard_remove_attributes(vcard, "", ebook.EVC_EMAIL);

    for (let card in fixIterator(this.addressLists, Ci.nsIAbCard)) {
      let attr = ebook.e_vcard_attribute_new(null, ebook.EVC_EMAIL);

      let name = card.getProperty("DisplayName", "");
      let address = card.getProperty("PrimaryEmail", "");
      let email = MailServices.headerParser.makeFullAddress(name, address);

      ebook.e_vcard_attribute_add_value(attr, email);
      ebook.e_vcard_append_attribute(vcard, attr);
    }
  },

  dispose: function AbEDSML_dispose() {
    ["_edsContact",
     "_edsClient"].forEach(function(key) {
      if (this[key] && !this[key].isNull()) {
        gobject.g_object_unref(this[key]);
        this[key] = null;
      }
    }, this);

    this._childCards = [];
  },

  // nsIAbEDSMailingList

  get edsId() {
    let cstr = ctypes.cast(ebook.e_contact_get_const(this.edsContact,
                                                     ebook.EContactFieldEnums
                                                          .E_CONTACT_UID),
                           glib.gchar.ptr);
    if (cstr.isNull()) {
      return null;
    }

    return cstr.readString();
  },

  // nsIAbEDSDirectory

  // void shutdown();
  // void getSupportedFields(out unsigned long aCount, [retval, array, size_is(aCount)] out string fields);

  // nsIAbDirectory

  get propertiesChromeURI() {
    return kPropertiesChromeURI;
  },

  get dirName() {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    let cstr = ctypes.cast(ebook.e_contact_get_const(this.edsContact,
                                                     ebook.EContactFieldEnums.E_CONTACT_FULL_NAME),
                           glib.gchar.ptr);
    if (cstr.isNull()) {
      return null;
    }

    return cstr.readString();
  },

  set dirName(aDirName) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    LOG("Setting dirName to \"" + aDirName + "\" for " + this.edsId);
    ebook.e_contact_set(this.edsContact,
                        ebook.EContactFieldEnums.E_CONTACT_FULL_NAME,
                        glib.gchar.array()(aDirName));
    ebook.e_contact_set(this.edsContact,
                        ebook.EContactFieldEnums.E_CONTACT_FILE_AS,
                        glib.gchar.array()(aDirName));
  },

  // readonly attribute long dirType;

  get fileName() {
    return null;
  },

  get URI() {
    return this._uri;
  },

  get position() {
    return 1;
  },

  get lastModifiedDate() {
    return 0;
  },

  set lastModifiedDate(val) {},

  get isMailList() {
    return true;
  },

  set isMailList(val) {},

  get childNodes() {
    return CreateSimpleObjectEnumerator({});
  },

  get childCards() {
    return this.addressLists.enumerate();
  },

  get isQuery() {
    return false;
  },

  init: function(aURI) {
    LOG("Initializing mailing list with URI: " + aURI);

    this._uri = aURI;
  },

  deleteDirectory: function AbEDSML_deleteDirectory(aDirectory) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  // FIXME: Implement this
  hasCard: function AbEDSML_hasCard(aCard) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  hasDirectory: function AbEDSML_hasDirectory(aDirectory) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  addCard: function AbEDSML_addCard(aCard) {
    // FIXME: Implement this
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  modifyCard: function AbEDSML_modifyCard(aModifiedCard) {
    throw Cr.NS_ERROR_UNEXPECTED;
  },

  deleteCards: function AbEDSML_deleteCards(aCards) {
    for (let i = 0; i < aCards.length; i++) {
      let cardToRemove = aCards.queryElementAt(i, Ci.nsIAbCard);
      let targetIndex = this.addressLists.indexOf(0, cardToRemove);
      if (targetIndex != -1) {
        this.addressLists.removeElementAt(targetIndex);
      }

      MailServices.ab.notifyDirectoryItemDeleted(this, cardToRemove);
    }
  },

  dropCard: function AbEDSML_dropCard(aCard, aNeedToCopyCard) {
    // Create a new card, and just copy over the DisplayName
    // and PrimaryEmail, since this is all EDS seems to care about.

    var newCard = Cc["@mozilla.org/addressbook/cardproperty;1"]
                  .createInstance(Ci.nsIAbCard);

    let address = aCard.getProperty("PrimaryEmail", "");
    let name = aCard.getProperty("DisplayName", "");
    newCard.setProperty("PrimaryEmail", address);
    newCard.setProperty("DisplayName", name);

    this.addressLists.appendElement(newCard, false);
  },

  // FIXME: Should probably look at mail.enable_autocomplete
  useForAutoComplete: function AbEDSML_useForAutoComplete(aIdentity) {
    return true;
  },

  get supportsMailingLists() {
    return false;
  },

  get addressLists() {
    if (!this._childCards) {
      this._childCards = Cc["@mozilla.org/array;1"]
                         .createInstance(Ci.nsIMutableArray);
    }

    return this._childCards;
  },

  set addressLists(val) {
    this._childCards = val;
  },

  addMailList: function AbEDSML_addMailList(aList) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  // XXX: What should go here?
  get listNickName() {
    return "";
  },

  set listNickName(val) {},

  // XXX: What should go here?
  get description() {
    return "";
  },

  set description(val) {},

  editMailListToDatabase: function AbEDSML_editMailListToDatabase(aListCard) {
    if (!this.edsContact || !this.edsClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    this.flush();

    let self = this;
    let success = ebook.e_book_client_modify_contact(ctypes.cast(this.edsClient,
                                                                 ebook.EBookClient.ptr),
                                                     this.edsContact, null,
                                                     function(aObject, aRes) {
      let error = new glib.GError.ptr;
      let client = ctypes.cast(aObject, ebook.EBookClient.ptr);
      let result = ebook.e_book_client_modify_contact_finish(client, aRes,
                                                             error.address());
      if (!result) {
        ERROR("Could not commit changes to mailing list " + self.URI + ": "
              + error.contents.message.readString());
        glib.g_error_free(error);
        return;
      }

      LOG("Committed changes for mailing list " + self.URI);
    });
  },

  copyMailList: function AbEDSML_copyMailList(aSrcList) {
    if (!aSrcList) {
      throw Cr.NS_ERROR_INVALID_ARG;
    }

    LOG("Copying list to " + this.edsId);

    this.dirName = aSrcList.dirName;
    this.addressLists = aSrcList.addressLists;
    try {
      let edsList = aSrcList.QueryInterface(Ci.nsIAbEDSMailingList);
      this.setBoolValue("HidesRecipients",
                        edsList.getBoolValue("HidesRecipients", null));
    } catch(e) {
      LOG("Source list is not a nsIAbEDSMailingList");
    }
  },

  createNewDirectory: function AbEDSML_createNewDirectory(aDirName, aURI,
                                                          aType, aPrefName) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  createDirectoryByURI: function AbEDSML_createDirectoryByURI(aDisplayName,
                                                              aURI) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  get dirPrefId() {
    return kDirPrefId;
  },

  set dirPrefId(val) {},

  getIntValue: function AbEDSML_getIntValue(aName, aDefaultValue){
    return aDefaultValue;
  },

  getBoolValue: function AbEDSML_getBoolValue(aName, aDefaultValue) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (aName == "HidesRecipients") {
      let showAddrs = ebook.e_contact_get(this.edsContact,
                                          ebook.EContactFieldEnums
                                               .E_CONTACT_LIST_SHOW_ADDRESSES);
      return showAddrs.isNull()
    }

    return aDefaultValue;
  },

  getStringValue: function AbEDSML_getStringValue(aName, aDefaultValue) {
    return aDefaultValue;
  },

  getLocalizedStringValue: function AbEDSML_getLocalizedStringValue(aName, aDefaultValue) {
    return aDefaultValue;
  },

  setIntValue: function AbEDSML_setIntValue(aName, aValue) {},

  setBoolValue: function AbEDSML_setBoolValue(aName, aValue) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (aName == "HidesRecipients") {
      let showAddrs = !aValue ? glib.TRUE : glib.FALSE;
      LOG("Configuring list " + this.edsId + " to " +
          (showAddrs ? "show" : "hide") + " recipients");
      ebook.e_contact_set(this.edsContact,
                          ebook.EContactFieldEnums.E_CONTACT_LIST_SHOW_ADDRESSES,
                          glib.GINT_TO_POINTER(showAddrs));
    }
  },

  setStringValue: function AbEDSML_setStringValue(aName, aValue) {},
  setLocalizedStringValue: function AbEDSML_setLocalizedStringValue(aName, aValue) {},

  // nsIAbCollection

  get readOnly() {
    if (!this.edsClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    return eds.e_client_is_readonly(this.edsClient);
  },

  get isRemote() {
    // XXX: Can we get this from EDS
    return false;
  },

  get isSecure() {
    // XXX: Can we get this from EDS
    return false;
  },

  // FIXME: Implement this
  cardForEmailAddress: function AbEDSML_cardForEmailAddress(aEmailAddress) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  getCardFromProperty: function AbEDSML_getCardFromProperty(aProperty, aValue, aCaseSensitive) {

    if (!aCaseSensitive)
      aValue = aValue.toLowerCase();

    for (let i = 0; i < this._childCards.length; i++) {
      let card = this._childCards[i];
      let property = card.getProperty(aProperty)
      if (!aCaseSensitive)
        property = property.toLowerCase();
      if (property == aValue)
        return card;
    }
    return null;
  },

  getCardsFromProperty: function AbEDSML_getCardsFromProperty(aProperty, aValue, aCaseSensitive) {
    let result = []
    if (!aCaseSensitive)
      aValue = aValue.toLowerCase();

    for(let i = 0; i < this._childCards.length; i++) {
      let card = this._childCards[i];
      let property = card.getProperty(aProperty)
      if (!aCaseSensitive)
        property = property.toLowerCase();
      if (property == aValue)
        result.push(card);
    }
    return CreateSimpleEnumerator(result);
  },

  // nsIAbItem

  get uuid() {
    return this.dirPrefId + "&" + this.dirName;
  },

  generateName: function AbEDSML_generateName(aGenerateFormat, aBundle) {
    return this.dirName;
  }
}

function attachAddressListToEdsContact(aContact, aAddressList) {
  ebook.e_vcard_remove_attributes(ctypes.cast(aContact, ebook.EVCard.ptr),
                                  "", ebook.EVC_EMAIL);

  for (let i = 0; i < aAddressList.length; i++) {
    // Create a new EVCardAttribute
    var attr = ebook.e_vcard_attribute_new(null, ebook.EVC_EMAIL);

    // Convert the nsIAbCard primary email and display name to something
    // we can work with:
    var card = aAddressList.queryElementAt(i, Ci.nsIAbCard);
    var name = card.getProperty("DisplayName", "");
    var address = card.getProperty("PrimaryEmail", "");
    var email = MailServices.headerParser.makeFullAddress(name, address);
    ebook.e_vcard_attribute_add_value(attr, email);
    ebook.e_vcard_add_attribute(ctypes.cast(aContact, ebook.EVCard.ptr), attr);
    LOG("Added email for mailing list: " + email);
  }
}
