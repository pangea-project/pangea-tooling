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

const { interfaces: Ci, results: Cr, utils: Cu } = Components;

var EXPORTED_SYMBOLS = [ "nsAbEDSCard" ];

Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource:///modules/mailServices.js");
Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource:///modules/iteratorUtils.jsm");
Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");
Cu.import("resource://edsintegration/libs/gio.jsm");
Cu.import("resource://edsintegration/libs/eds.jsm");
Cu.import("resource://edsintegration/libs/ebook.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSPhone.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSIMAccount.jsm");
Cu.import("resource://edsintegration/modules/nsAbSimpleProperty.jsm");
Cu.import("resource://edsintegration/modules/EDSFieldMappers.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSEmailAddress.jsm");

addLogger(this);

function nsAbEDSCard(aParent, aContact) {
  if (!aParent || !aContact || aContact.isNull()) {
    throw Cr.NS_ERROR_INVALID_ARG;
  }

  this.__uid = null;
  this._dirName = null;
  this._phoneNumbers = null;
  this._IMAccounts = null;
  this._emailAddrs = null;

  // Add a reference to aEBook and aEContact so that GLib
  // doesn't swallow it up.
  this._edsClient = ctypes.cast(gobject.g_object_ref(aParent._edsClient),
                                eds.EClient.ptr);
  this._parent = aParent;
  this._parentWrapped = null;
  this._parentURI = null;
  this._edsContact = ctypes.cast(gobject.g_object_ref(aContact),
                                 ebook.EContact.ptr);

  if (this._uid) {
    LOG("New nsAbEDSCard, uid=" + this._uid + ", EContact=" + this.edsContact);
  } else {
    LOG("New temporary nsAbEDSCard, EContact=" + this.edsContact);
  }

  constructEDSFieldMappers(this);
}


nsAbEDSCard.prototype = {
  classDescription: "Evolution Data Server Address Book Contact",
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIAbEDSCard,
                                         Ci.nsIAbCard,
                                         Ci.nsIAbItem]),

  _emailAddressTypes: [
    ebook.WORK,
    ebook.HOME,
    ebook.OTHER
  ],

  get _uid() {
    if (!this.__uid) {
      let cstr = ctypes.cast(ebook.e_contact_get_const(this.edsContact,
                                                       ebook.EContactFieldEnums
                                                            .E_CONTACT_UID),
                             glib.gchar.ptr);
      if (!cstr.isNull()) {
        this.__uid = cstr.readString();
      }
    }

    return this.__uid;
  },

  get _edsBookClient() {
    return ctypes.cast(this._edsClient, ebook.EBookClient.ptr);
  },

  get edsContact() {
    return this._edsContact;
  },

  set edsContact(aContact) {
    if (!aContact || aContact.isNull()) {
      throw Cr.NS_ERROR_INVALID_ARG;
    }

    let cstr = ctypes.cast(ebook.e_contact_get_const(aContact,
                                                     ebook.EContactFieldEnums.E_CONTACT_UID),
                           glib.gchar.ptr);
    if (cstr.isNull()) {
      throw Error("Contact has no UID");
    }

    let uid = cstr.readString();

    if (uid != this.localId) {
      throw Error("Cannot change UID!! Old UID=" + this.localId + ", new UID=" +
                  cstr.readString());
    }

    LOG("Updating card " + uid + ", new EContact=" + aContact);

    let oldContact = this._edsContact;
    this._edsContact = ctypes.cast(gobject.g_object_ref(aContact),
                                   ebook.EContact.ptr);

    var oldValues = {};
    for (let mapper in fixIterator(this._mappers)) {
      try {
        let keys = mapper.keys;
        for (let i = 0; i < keys.length; i++) {
          let key = keys[i];
          oldValues[key] = this.getProperty(key, "");
        }

        mapper.edsContact = this._edsContact;
      } catch(e) {
        ERROR("Failed to update mapper", e);
      }
    }

    gobject.g_object_unref(oldContact);

    this._IMAccounts = null;
    this._phoneNumbers = null;
    this._emailAddrs = null;

    for (let key in oldValues) {
      let oldValue = oldValues[key];
      let newValue = this.getProperty(key, "");

      if (oldValue != newValue) {
        LOG("Property " + key + " changed from " + oldValue + " to " + newValue);
        MailServices.ab.notifyItemPropertyChanged(this, key, oldValue, newValue);
      }
    }
  },

  _fetchPhoneNumbers: function AbEDSCard__fetchPhoneNumbers() {
    this._phoneNumbers = [];
    for (let attr in glib.listIterator(ebook.e_contact_get_attributes(this.edsContact,
                                                                      ebook.EContactFieldEnums.E_CONTACT_TEL),
                                       ebook.EVCardAttribute.ptr, true, ebook.e_vcard_attribute_free)) {
      let phone = new nsAbEDSPhone();
      phone.number = ebook.e_vcard_attribute_get_value(attr);
      phone.type = this._getPhoneType(attr);
      this._phoneNumbers.push(phone);
    }
  },

  _getPhoneType: function AbEDSCard__getPhoneType(aAttr) {
    for (let key in gPhoneVCardMap) {
      let map = gPhoneVCardMap[key];
      if (ebook.e_vcard_attribute_has_type(aAttr, map.type_1) &&
          (map.type_2 == null ||
           ebook.e_vcard_attribute_has_type(aAttr, map.type_2))) {
        return key;
      }
    }
    return null;
  },

  _fetchIMAccounts: function AbEDSCard__fetchIMAccounts() {
    this._IMAccounts = [];
    for (let edsType in gTbFieldFromEDSIMType) {
      // Retrieve and append any attributes for each service.
      let svcType = gTbFieldFromEDSIMType[edsType];
      for (let attr in glib.listIterator(ebook.e_contact_get_attributes(this.edsContact,
                                                                        ebook.EContactFieldEnums[edsType]),
                                         ebook.EVCardAttribute.ptr, true, ebook.e_vcard_attribute_free)) {
        let account = new nsAbEDSIMAccount();
        account.username = ebook.e_vcard_attribute_get_value(attr);
        account.type = svcType;
        this._IMAccounts.push(account);
      }
    }
  },

  _fetchEmailAddrs: function AbEDSCard__fetchEmailAddrs() {
    this._emailAddrs = [];

    for (let attr in glib.listIterator(ebook.e_contact_get_attributes(this.edsContact,
                                                                      ebook.EContactFieldEnums.E_CONTACT_EMAIL),
                                       ebook.EVCardAttribute.ptr, true, ebook.e_vcard_attribute_free)) {
      let email = new nsAbEDSEmailAddress();
      let type = this._resolveEmailType(attr);
      let address = ebook.e_vcard_attribute_get_value(attr);
      email.address = address;
      email.type = type;
      this._emailAddrs.push(email);
    }
  },

  _resolveEmailType: function AbEDSCard__resolveEmailType(aAttr) {
    for (let i = 0; i < this._emailAddressTypes.length; i++) {
      if (ebook.e_vcard_attribute_has_type(aAttr, this._emailAddressTypes[i])) {
        return this._emailAddressTypes[i];
      }
    }

    WARN("Could not resolve email type for an nsAbEDSEmailAddress - "
         + "setting as OTHER.");
    return ebook.OTHER;
  },

  dispose: function AbEDSCard_dispose() {
    ["_edsClient",
     "_edsContact"].forEach(function(aKey) {
       if (this[aKey] && !this[aKey].isNull()) {
         gobject.g_object_unref(this[aKey]);
       }
       this[aKey] = null;
     }, this);

    this._mappers = [];
    this._parent = null;
    this._parentWrapped = null;
  },

  flush: function AbEDSCard_flush() {
    if (!this.edsContact || !this._edsBookClient) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    LOG("Flushing changes to EContact");

    for (let mapper in fixIterator(this._mappers)) {
      // Flush any pending changes to the EContact
      mapper.flush();
    }
  },

  commit: function EDSCard_commit() {
    if (!this.edsContact || !this._edsBookClient) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    LOG("Committing changes for card with UID " + this._uid);

    for (let mapper in fixIterator(this._mappers)) {
      // Flush any pending changes to the EContact
      try {
        mapper.flush();
      } catch(e) {
        ERROR("Failed to commit changes", e);
        throw Cr.NS_ERROR_FAILURE;
      }
    }

    let self = this;

    // Commit for real
    ebook.e_book_client_modify_contact(this._edsBookClient, this.edsContact, null,
                                       function(aObject, aRes) {
      let error = new glib.GError.ptr;
      let client = ctypes.cast(aObject, ebook.EBookClient.ptr);
      let result = ebook.e_book_client_modify_contact_finish(client,
                                                             aRes,
                                                             error.address());
      if (!result) {
        ERROR("Could not commit changes to card " + self._uid + ": "
              + error.contents.message.readString());
        glib.g_error_free(error);
        return;
      }

      LOG("Committed changes for card with UID " + self._uid);
    });
  },

  // nsIAbEDSCard

  getPhoneNumbers: function AbEDSCard_getPhoneNumbers(aCount) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    if (!this._phoneNumbers) {
      this._fetchPhoneNumbers();
    }

    aCount.value = this._phoneNumbers.length;
    return this._phoneNumbers;
  },

  setPhoneNumbers: function AbEDSCard_setPhoneNumbers(aCount, aAddrs) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    let list = [];
    for (let i = 0; i < aCount; i++) {
      let phone = aAddrs[i];
      if (!phone.type) {
        throw Error("Phone number has no type");
      }

      let map = gPhoneVCardMap[phone.type];

      if (!map) {
        throw Error("Unrecognized type: " + phone.type);
      }

      let attr = ebook.e_vcard_attribute_new("", ebook.EVC_TEL);

      ebook.e_vcard_attribute_add_param_with_value(attr,
                                                   ebook.e_vcard_attribute_param_new(ebook.EVC_TYPE),
                                                   map.type_1);
      if (map.type_2) {
        ebook.e_vcard_attribute_add_param_with_value(attr,
                                                     ebook.e_vcard_attribute_param_new(ebook.EVC_TYPE),
                                                     map.type_2);
      }

      ebook.e_vcard_attribute_add_value(attr, phone.number);

      list.push(attr);
    }

    let vcard = ctypes.cast(this.edsContact, ebook.EVCard.ptr);

    ebook.e_vcard_remove_attributes(vcard, null, ebook.EVC_TEL);
    list.forEach(function(attr) {
      // The EContact takes ownership of the EVCardAttribute
      ebook.e_vcard_append_attribute(vcard, attr);
    });
  },

  getIMAccounts: function AbEDSCard_getIMAccounts(aCount) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    if (!this._IMAccounts) {
      this._fetchIMAccounts();
    }

    aCount.value = this._IMAccounts.length;
    return this._IMAccounts;
  },

  setIMAccounts: function AbEDSCard_setIMAccounts(aCount, aAccts) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    let list = [];
    for (let i = 0; i < aCount; i++) {
      let acct = aAccts[i];
      if (!acct.type) {
        throw Error("IM account does not specify an account type");
      }

      if (!(acct.type in gEDSIMTypeFromTbField)) {
        throw Error("Unrecognized IM account type: " + acct.type);
      }

      let edsType = gEDSIMTypeFromTbField[acct.type];

      let name = ebook.e_contact_vcard_attribute(ebook.EContactFieldEnums[edsType]);
      let attr = ebook.e_vcard_attribute_new("", name);

      // Maybe at some point we should respect the "location",
      // of this attribute - but for now, we ignore it.
      let typeParam = ebook.e_vcard_attribute_param_new(ebook.EVC_TYPE);
      ebook.e_vcard_attribute_add_param_with_value(attr, typeParam, ebook.HOME);

      ebook.e_vcard_attribute_add_value(attr, acct.username);

      list.push(attr);
    }

    let vcard = ctypes.cast(this.edsContact, ebook.EVCard.ptr);

    for (let edsType in gTbFieldFromEDSIMType) {
      let name = ebook.e_contact_vcard_attribute(ebook.EContactFieldEnums[edsType]);
      ebook.e_vcard_remove_attributes(vcard, null, name);
    }

    list.forEach(function(attr) {
      // The EContact takes ownership of the EVCardAttribute
      ebook.e_vcard_append_attribute(vcard, attr);
    });
  },

  getEmailAddrs: function AbEDSCard_getEmailAddrs(aCount) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    if (!this._emailAddrs) {
      this._fetchEmailAddrs();
    }

    aCount.value = this._emailAddrs.length;
    return this._emailAddrs;
  },

  setEmailAddrs: function AbEDSCard_setEmailAddrs(aCount, aAddrs) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    list = [];
    for (let i = 0; i < aCount; i++) {
      let email = aAddrs[i];

      let attr = ebook.e_vcard_attribute_new("", ebook.EVC_EMAIL);

      let typeParam = ebook.e_vcard_attribute_param_new(ebook.EVC_TYPE);
      ebook.e_vcard_attribute_add_param_with_value(attr, typeParam, email.type);

      ebook.e_vcard_attribute_add_value(attr, email.address);

      list.push(attr);
    }

    let vcard = ctypes.cast(this.edsContact, ebook.EVCard.ptr);

    ebook.e_vcard_remove_attributes(vcard, null, ebook.EVC_EMAIL);
    list.forEach(function(attr) {
      // The EContact takes ownership of the EVCardAttribute
      ebook.e_vcard_append_attribute(vcard, attr);
    });
  },

  get parentDirectory() {
    if (!this._parentWrapped) {
      this._parentWrapped = MailServices.ab.getDirectory(this._parent.URI);
    }

    return this._parentWrapped.QueryInterface(Ci.nsIAbEDSDirectory);
  },

  // nsIAbCard

  get directoryId() {
    return this._parent.uuid;
  },

  set directoryId(aValue) {},

  get localId() {
    return this._uid;
  },

  set localId(aValue) {
  },

  get properties() {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    // This is used by nsAbCardProperty::Copy, for copying nsIAbCard's
    // around.
    //
    // Go through each item in the property map, preparing
    // an nsIProperty.
    let result = {};
    for (let mapper in fixIterator(this._mappers)) {
      try {
        let clonedMap = mapper.cloneMap();
        Object.keys(clonedMap).forEach(function(key) {
          result[key] = new nsAbSimpleProperty(key, clonedMap[key]);
        });
      } catch(e) {
        ERROR("Failed to clone properties from mapper", e);
        throw Cr.NS_ERROR_FAILURE;
      }
    }

    return CreateSimpleObjectEnumerator(result);
  },

  getProperty: function AbEDSCard_getProperty(aKey, aDefaultValue) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    for (let mapper in fixIterator(this._mappers)) {
      try {
        if (mapper.readsKey(aKey)) {
          let result = mapper.read(aKey);
          if (result == null)
            return aDefaultValue;
          else
            return result;
        }
      } catch(e) {
        ERROR("Failed to read property " + aKey, e);
        throw Cr.NS_ERROR_FAILURE;
      }
    }
    return aDefaultValue;
  },

  getPropertyAsAString: function AbEDSCard_getPropertyAsAString(aName) {
    return this.getProperty(aName, null);
  },

  getPropertyAsAUTF8String: function AbEDSCard_getPropertyAsAUTF8String(aName) {
    return this.getProperty(aName, null);
  },

  getPropertyAsUint32: function AbEDSCard_getPropertyAsUint32(aName) {
    return this.getProperty(aName, null);
  },

  getPropertyAsBool: function AbEDSCard_getPropertyAsBool(aName) {
    return this.getProperty(aName, null);
  },

  setProperty: function AbEDSCard_setProperty(aKey, aValue) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    LOG("Setting property: " + aKey + " to " + aValue);

    let oldValue = this.getProperty(aKey, "");
    for (let mapper in fixIterator(this._mappers)) {
      try {
        if (mapper.readsKey(aKey)) {
          mapper.write(aKey, aValue);
          MailServices.ab.notifyItemPropertyChanged(this, aKey, oldValue, aValue);
          return;
        }
      } catch(e) {
        ERROR("Failed to write property " + aKey, e);
        throw Cr.NS_ERROR_FAILURE;
      }
    }
    WARN("Could not find nsIAbEDSCard mapper for property: " + aKey);
  },

  setPropertyAsAString: function AbEDSCard_setPropertyAsAString(aName, aValue) {
    this.setProperty(aName, aValue);
  },

  setPropertyAsAUTF8String: function AbEDSCard_setPropertyAsAUTF8String(aName, aValue) {
    this.setProperty(aName, aValue);
  },

  setPropertyAsUint32: function AbEDSCard_setPropertyAsUint32(aName, aValue) {
    this.setProperty(aName, aValue);
  },

  setPropertyAsBool: function AbEDSCard_setPropertyAsBool(aName, aValue) {
    this.setProperty(aName, aValue);
  },

  deleteProperty: function AbEDSCard_deleteProperty(aKey) {
    if (!this.edsContact) {
      throw Cr.NS_ERROR_UNEXPECTED;
    }

    LOG("Deleting property: " + aKey);

    let oldValue = this.getProperty(aKey, "");
    for (let mapper in fixIterator(this._mappers)) {
      try {
        if (mapper.readsKey(aKey)) {
          mapper.clear(aKey);
          MailServices.ab.notifyItemPropertyChanged(this, aKey, oldValue, null);
          return;
        }
      } catch(e) {
        ERROR("Failed to delete property " + aKey, e);
        throw Cr.NS_ERROR_FAILURE;
      }
    }
    WARN("Could not find nsIAbEDSCard mapper for property: " + aKey);
  },

  get firstName() {
    return this.getProperty("FirstName", "");
  },

  set firstName(firstName) {
    this.setProperty("FirstName", firstName);
  },

  get lastName() {
    return this.getProperty("LastName", "");
  },

  set lastName(lastName) {
    this.setProperty("LastName", lastName);
  },

  get displayName() {
    return this.getProperty("DisplayName", "");
  },

  set displayName(displayName) {
    this.setProperty("DisplayName", displayName);
  },

  get primaryEmail() {
    return this.getProperty("PrimaryEmail", "");
  },

  set primaryEmail(primaryEmail) {},

  hasEmailAddress: function AbEDSCard_hasEmailAddress(aEmailAddress) {
    let emails = this.getEmailAddrs({});
    for (let i = 0; i < emails.length; i++) {
      let email = emails[i];
      if (email.address == aEmailAddress)
        return true;
    }
    return false;
  },

  translateTo: function AbEDSCard_translateTo(aType) {
    return Cr.NS_ERROR_ILLEGAL_VALUE;
  },

  generatePhoneticName: function AbEDSCard_generatePhoneticName(aLastNameFirst) {
    return "";
  },

  generateChatName: function AbEDSCard_generateChatName() {
    return "";
  },

  copy: function AbEDSCard_copy(aSrcCard) {
    if (!aSrcCard) {
      throw Cr.NS_ERROR_INVALID_ARG;
    }

    for (let property in fixIterator(aSrcCard.properties, Ci.nsIProperty)) {
      if (this.parentDirectory.getSupportedFields({})
                              .indexOf(property.name) != -1) {
        this.setProperty(property.name, property.value);
      }
    }

    let addrs = [];
    let phones = [];
    let imAccounts = [];

    try {
      let edsCard = aSrcCard.QueryInterface(Ci.nsIAbEDSCard);

      edsCard.getEmailAddrs({}).forEach(function(src) {
        let cloned = new nsAbEDSEmailAddress();
        cloned.address = src.address;
        cloned.type = src.type;
        addrs.push(cloned);
      });

      edsCard.getPhoneNumbers({}).forEach(function(src) {
        if (this.parentDirectory.getSupportedPhoneTypes({})
                                .indexOf(src.type) != -1) {
          let cloned = new nsAbEDSPhone();
          cloned.number = src.number;
          cloned.type = src.type;
          phones.push(cloned);
        }
      }, this);


      edsCard.getIMAccounts({}).forEach(function(src) {
        if (this.parentDirectory.getSupportedIMTypes({})
                                .indexOf(src.type) != -1) {
          let cloned = new nsAbEDSIMAccount();
          cloned.username = src.username;
          cloned.type = src.type;
          imAccounts.push(cloned);
        }
      }, this);

    } catch(e) {
      if (e.name != "NS_NOINTERFACE") throw e;

      // This is not a nsIAbEDSCard
      ["PrimaryEmail",
       "SecondEmail"].forEach(function(key) {
        let value = aSrcCard.getProperty(key, null);
        if (value) {
          let email = new nsAbEDSEmailAddress();
          email.address = value;
          email.type = ebook.OTHER;
          addrs.push(email);
        }
      });


      Object.keys(gPhoneVCardMap).forEach(function(key) {
        let value = aSrcCard.getProperty(key, null);
        if (value) {
          let phone = new nsAbEDSPhone();
          phone.number = value;
          phone.type = key;
          phones.push(phone);
        }
      });

      Object.keys(gEDSIMTypeFromTbField).forEach(function(key) {
        let value = aSrcCard.getProperty(key, null);
        if (value) {
          let account = new nsAbEDSIMAccount();
          account.username = value;
          account.type = key;
          imAccounts.push(account);
        }
      });

      Object.keys(gVCardPropFromUnsupportedTbField).forEach(function(key) {
        this.setProperty(key, aSrcCard.getProperty(key, null));
      }, this);
    }

    this.setEmailAddrs(addrs.length, addrs);
    this.setPhoneNumbers(phones.length, phones);
    this.setIMAccounts(imAccounts.length, imAccounts);
  },

  equals: function AbEDSCard_equals(aCard) {
    try {
      return (aCard.uuid == this.uuid);
    } catch(e) { return false; }
  },

  get isMailList() {
    return false;
  },

  set isMailList(aIsMailList) {},

  get mailListURI() {
    return "";
  },

  set mailListURI(aValue) {},

  // nsIAbItem

  get uuid() {
    return MailServices.ab.generateUUID(this.directoryId, this.localId);
  },

  // XXX: What do we do with the generateFormat here?
  generateName: function AbEDSCard_generateName(aGenerateFormat, aBundle) {
    return this.displayName;
  }
}
