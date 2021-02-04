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
 * Chris Coulson <chris.coulson@canonical.com>
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

var EXPORTED_SYMBOLS = [ "gTbFieldsFromEDSField",
                         "gTbFieldFromEDSPhoneType",
                         "gTbFieldFromEDSIMType",
                         "gEDSIMTypeFromTbField",
                         "gVCardPropFromUnsupportedTbField",
                         "gPhoneVCardMap",
                         "constructEDSFieldMappers" ];

Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://gre/modules/FileUtils.jsm");
Cu.import("resource://gre/modules/NetUtil.jsm");
Cu.import("resource:///modules/iteratorUtils.jsm");
Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");
Cu.import("resource://edsintegration/libs/eds.jsm");
Cu.import("resource://edsintegration/libs/ebook.jsm");

addLogger(this);

var gMap = {}; // Map of Thunderbird properties to EDS properties + types (only for properties that have direct equivalents)
var gMapperConstructors = []; // List of mapper constructors for each card

var gPhoneMap = { // Map of Thunderbird properties to EDS phone types and vcard types
  "_edsAssistantPhone": { "E_CONTACT_PHONE_ASSISTANT": {
    type_1: ebook.EVC_X_ASSISTANT,
    type_2: null
  }},
  "WorkPhone": { "E_CONTACT_PHONE_BUSINESS": {
    type_1: "WORK",
    type_2: "VOICE"
  }},
  "_edsWorkFax": { "E_CONTACT_PHONE_BUSINESS_FAX": {
    type_1: "WORK",
    type_2: "FAX"
  }},
  "_edsCallbackPhone": { "E_CONTACT_PHONE_CALLBACK": {
    type_1: ebook.EVC_X_CALLBACK,
    type_2: null
  }},
  "_edsCarPhone": { "E_CONTACT_PHONE_CAR": {
    type_1: "CAR",
    type_2: null
  }},
  "_edsCompanyPhone": { "E_CONTACT_PHONE_COMPANY": {
    type_1: "X-EVOLUTION-COMPANY",
    type_2: null
  }},
  "HomePhone": { "E_CONTACT_PHONE_HOME": {
    type_1: "HOME",
    type_2: "VOICE"
  }},
  "FaxNumber": { "E_CONTACT_PHONE_HOME_FAX": {
    type_1: "HOME",
    type_2: "FAX"
  }},
  "_edsISDNNumber": { "E_CONTACT_PHONE_ISDN": {
    type_1: "ISDN",
    type_2: null
  }},
  "CellularNumber": { "E_CONTACT_PHONE_MOBILE": {
    type_1: "CELL",
    type_2: null
  }},
  "_edsOtherPhone": { "E_CONTACT_PHONE_OTHER": {
    type_1: "VOICE",
    type_2: null
  }},
  "_edsOtherFax": { "E_CONTACT_PHONE_OTHER_FAX": {
    type_1: "FAX",
    type_2: null
  }},
  "PagerNumber": { "E_CONTACT_PHONE_PAGER": {
    type_1: "PAGER",
    type_2: null
  }},
  "_edsPrimaryPhone": { "E_CONTACT_PHONE_PRIMARY": {
    type_1: "PREF",
    type_2: null
  }},
  "_edsRadioNumber": { "E_CONTACT_PHONE_RADIO": {
    type_1: ebook.EVC_X_RADIO,
    type_2: null
  }},
  "_edsTelexNumber": { "E_CONTACT_PHONE_TELEX": {
    type_1: ebook.EVC_X_TELEX,
    type_2: null
  }},
  "_edsTTYNumber": { "E_CONTACT_PHONE_TTYTDD": {
    type_1: ebook.EVC_X_TTYTDD,
    type_2: null
  }}
};

var gTbFieldsFromEDSField = {}; // Map of EDS fields to Thunderbird fields (only for properties that have direct equivalents)
var gEDSFieldFromTbField = {}; // Map of Thunderbird fields to EDS fields (only for properties that have direct equivalents)

var gTbFieldTypes = {}; // Map of Thunderbird fields to types

var gTbFieldFromEDSPhoneType = {}; // Map of EDS phone types to Thunderbird fields

var gPhoneVCardMap = {}; // Map of Thunderbird fields to vcard types for phone numbers

var gEDSIMTypeFromTbField = { // Map of Thunderbird fields to EDS IM types
  "_AimScreenName": "E_CONTACT_IM_AIM",
  "_edsGroupwise": "E_CONTACT_IM_GROUPWISE",
  "_JabberId": "E_CONTACT_IM_JABBER",
  "_Yahoo": "E_CONTACT_IM_YAHOO",
  "_MSN": "E_CONTACT_IM_MSN",
  "_ICQ": "E_CONTACT_IM_ICQ",
  "_edsGaduGadu": "E_CONTACT_IM_GADUGADU",
  "_Skype": "E_CONTACT_IM_SKYPE",
  "_GoogleTalk": "E_CONTACT_IM_GOOGLE_TALK"
};
var gTbFieldFromEDSIMType = {}; // Map of EDS IM types to Thunderbird fields

if (ebook.ABI >= 14) {
  gEDSIMTypeFromTbField["_edsTwitter"] = "E_CONTACT_IM_TWITTER";
}

var gVCardPropFromUnsupportedTbField = { // Map of fields in Thunderbird that aren't supported in EDS to vCard properties
  "Custom1": "X-THUNDERBIRD-CUSTOM-1",
  "Custom2": "X-THUNDERBIRD-CUSTOM-2",
  "Custom3": "X-THUNDERBIRD-CUSTOM-3",
  "Custom4": "X-THUNDERBIRD-CUSTOM-4"
};
var gUnsupportedTbFieldFromVCardProp = {}; // Map of vCard properties to fields in Thunderbird that aren't supported in EDS

function edsMapEntryString(aEDSKey) {
  return { "edskey": aEDSKey, "type": "string" };
}

function edsMapEntryNumber(aEDSKey) {
  return { "edskey": aEDSKey, "type": "number" };
}

function edsBooleanKey(aEDSKey, aTrue, aFalse) {
  return { "edskey": aEDSKey, "true": aTrue, "false": aFalse };
}

function registerMapper(aMapper) {
  gMapperConstructors.push(function(aCard) {
    return new aMapper(aCard);
  });
}

function registerStringMapper(aMap) {
  gMapperConstructors.push(function(aCard) {
    return new stringMapper(aCard, Object.keys(aMap));
  });

  Object.keys(aMap).forEach(function(key) {
    gMap[key] = edsMapEntryString(aMap[key]);
  });
}

function registerNameMapper() {
  gMapperConstructors.push(function(aCard) {
    let mapper = new nameMapper(aCard);
    mapper._init();
    return mapper;
  });

  ["FirstName",
   "LastName"].forEach(function(key) {
    gMap[key] = edsMapEntryString("E_CONTACT_NAME");
  });
}

function registerBooleanMapper(aMap) {
  gMapperConstructors.push(function(aCard) {
    return new booleanMapper(aCard, aMap);
  });

  Object.keys(aMap).forEach(function(key) {
    gMap[key] = edsMapEntryString(aMap[key].edskey);
  });
}

function registerAddressMapper() {
  let args = Array.prototype.slice.call(arguments, 0);

  gMapperConstructors.push(function(aCard) {
    let mapper = new addressMapper(aCard);
    mapper._init.apply(mapper, args);
    return mapper;
  });

  let edsKey = args[0];

  args.slice(1).forEach(function(key) {
    gMap[key] = edsMapEntryString(edsKey);
  });
}

function registerDateMapper() {
  let args = Array.prototype.slice.call(arguments, 0);

  gMapperConstructors.push(function(aCard) {
    let mapper = new dateMapper(aCard);
    mapper._init.apply(mapper, args);
    return mapper;
  });

  let edsKey = args[0];

  args.slice(1).forEach(function(key) {
    gMap[key] = edsMapEntryNumber(edsKey);
  });
}

function registerPhotoMapper() {
  gMapperConstructors.push(function(aCard) {
    return new photoMapper(aCard);
  });

  ["PhotoName",
   "PhotoURI",
   "RawData",
   "MimeType",
   "PhotoType"].forEach(function(key) {
    gMap[key] = edsMapEntryString("E_CONTACT_PHOTO");
  });

  gMap["RawDataLength"] = edsMapEntryNumber("E_CONTACT_PHOTO");
}

function registerUnsupportedStringMapper() {
  gMapperConstructors.push(function(aCard) {
    return new unsupportedStringMapper(aCard);
  });
}

function buildEarlyMaps() {
  Object.keys(gPhoneMap).forEach(function(key) {
    gTbFieldFromEDSPhoneType[Object.keys(gPhoneMap[key])[0]] = key;
    gPhoneVCardMap[key] = gPhoneMap[key][Object.keys(gPhoneMap[key])[0]];
  });

  Object.keys(gEDSIMTypeFromTbField).forEach(function(key) {
    gTbFieldFromEDSIMType[gEDSIMTypeFromTbField[key]] = key;
  });

  Object.keys(gVCardPropFromUnsupportedTbField).forEach(function(key) {
    gUnsupportedTbFieldFromVCardProp[gVCardPropFromUnsupportedTbField[key]] = key;
  });
}

function buildMaps() {
  Object.keys(gMap).forEach(function(key) {
    gEDSFieldFromTbField[key] = gMap[key].edskey;
    gTbFieldTypes[key] = gMap[key].type;
    if (!(gMap[key].edskey in gTbFieldsFromEDSField)) {
      gTbFieldsFromEDSField[gMap[key].edskey] = [key];
    } else {
      gTbFieldsFromEDSField[gMap[key].edskey].push(key);
    }
  });
}

buildEarlyMaps();
registerStringMapper({
  "DisplayName": "E_CONTACT_FILE_AS",
  "NickName": "E_CONTACT_NICKNAME",
  "SpouseName": "E_CONTACT_SPOUSE",
  "FamilyName": "E_CONTACT_FAMILY_NAME",

  "WebPage1": "E_CONTACT_HOMEPAGE_URL",
  "JobTitle": "E_CONTACT_TITLE",
  "Department": "E_CONTACT_ORG_UNIT",
  "Company": "E_CONTACT_ORG",
  "Notes": "E_CONTACT_NOTE",

  "WorkOffice": "E_CONTACT_OFFICE",
  "AssistantPhone": "E_CONTACT_PHONE_ASSISTANT",
  "HomePage": "E_CONTACT_HOMEPAGE_URL",
  "Blog": "E_CONTACT_BLOG_URL",
  "Calendar": "E_CONTACT_CALENDAR_URI",
  "FreeBusy": "E_CONTACT_FREEBUSY_URL",
  "VideoChat": "E_CONTACT_VIDEO_URL",
  "Spouse": "E_CONTACT_SPOUSE",
  "Profession": "E_CONTACT_ROLE",
  "Manager": "E_CONTACT_MANAGER",
  "Assistant": "E_CONTACT_ASSISTANT"
});
registerNameMapper();
registerBooleanMapper({
  "PreferMailFormat": edsBooleanKey("E_CONTACT_WANTS_HTML",
                                    Ci.nsIAbPreferMailFormat.html.toString(),
                                    [Ci.nsIAbPreferMailFormat.plaintext.toString(),
                                     Ci.nsIAbPreferMailFormat.unknown.toString()])
});
registerAddressMapper("E_CONTACT_ADDRESS_HOME", "HomeAddress", "HomeAddress2",
                      "HomeCity", "HomeState", "HomeZipCode", "HomeCountry",
                      "HomePOBox");
registerAddressMapper("E_CONTACT_ADDRESS_WORK", "WorkAddress", "WorkAddress2",
                      "WorkCity", "WorkState", "WorkZipCode", "WorkCountry",
                      "WorkPOBox");
registerAddressMapper("E_CONTACT_ADDRESS_OTHER", "OtherAddress",
                      "OtherAddress2", "OtherCity", "OtherState",
                      "OtherZipCode", "OtherCountry", "OtherPOBox");
registerDateMapper("E_CONTACT_BIRTH_DATE", "BirthYear", "BirthMonth",
                   "BirthDay");
registerDateMapper("E_CONTACT_ANNIVERSARY", "AnniversaryYear",
                   "AnniversaryMonth", "AnniversaryDay");
registerPhotoMapper();
registerUnsupportedStringMapper();
registerMapper(emailMapper);
registerMapper(phoneMapper);
registerMapper(imMapper);
buildMaps();

// The base of all mapper classes
var baseMapper = {
  get keys() {
    if (this._keys) {
      var keys = this._keys;
    } else {
      if (!this._map) {
        throw Error("No keys defined");
      }      

      var keys = Object.keys(this._map);
    }

    return keys.filter(function(key) {
      return (key.indexOf("_eds") != 0);
    });
  },

  readsKey: function BM_readsKey(aKey) {
    return this.keys.indexOf(aKey) != -1;
  },

  cloneMap: function BM_cloneMap() {
    let result = {};
    this.keys.forEach(function(key) {
      result[key] = this.read(key);
    }, this);

    return result;
  }
};

["read",
 "write",
 "clear",
 "flush"].forEach(function(key) {
  baseMapper[key] = function() {
    throw Error(key + " must be implemented by a derived class");
  };
});

function emailMapper(aCard) {
  this._card = aCard;
}

emailMapper.prototype = Object.create(baseMapper, {
  _keys: { value: [
    "PrimaryEmail",
    "SecondEmail",
  ]},

  read: { value: function EM_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let addrs = this._card.getEmailAddrs({});

    if (!addrs) {
      return null;
    }

    switch(aKey) {
      case "PrimaryEmail":
        if (addrs.length > 0) {
          return addrs[0].address;
        }
        break;
      case "SecondEmail":
        if (addrs.length > 1) {
          return addrs[1].address;
        }
        break;
    }

    return null;
  }},

  write: { value: function EM_write(aKey, aValue) {}},

  clear: { value: function EM_clear(aKey) {}},

  flush: { value: function EM_flush() {}}
});

function phoneMapper(aCard) {
  this._card = aCard;
}

phoneMapper.prototype = Object.create(baseMapper, {
  _keys: { value: Object.keys(gPhoneMap) },

  read: { value: function PM_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let numbers = this._card.getPhoneNumbers({});

    if (!numbers) {
      return null;
    }

    numbers = numbers.filter(function(elem) {
      return elem.type == aKey;
    });

    if (numbers.length == 0) {
      return null;
    }

    return numbers[0].number;
  }},

  write: { value: function PM_write(aKey, aValue) {}},

  clear: { value: function PM_clear(aKey) {}},

  flush: { value: function PM_flush() {}}
});

function imMapper(aCard) {
  this._card = aCard;
}

imMapper.prototype = Object.create(baseMapper, {
  _keys: { value: Object.keys(gEDSIMTypeFromTbField) },

  read: { value: function IM_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let accounts = this._card.getIMAccounts({});

    if (!accounts) {
      return null;
    }

    accounts = accounts.filter(function(elem) {
      return elem.type == aKey;
    });

    if (accounts.length == 0) {
      return null;
    }

    return accounts[0].username;
  }},

  write: { value: function IM_write(aKey, aValue) {}},

  clear: { value: function IM_clear(aKey) {}},

  flush: { value: function IM_flush() {}}
});

function unsupportedStringMapper(aCard) {
  this.edsContact = aCard.edsContact;
}

unsupportedStringMapper.prototype = Object.create(baseMapper, {
  _keys: { value: Object.keys(gVCardPropFromUnsupportedTbField) },

  read: { value: function USM_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let vcardName = gVCardPropFromUnsupportedTbField[aKey];

    let attr = ebook.e_vcard_get_attribute(ctypes.cast(this.edsContact,
                                                       ebook.EVCard.ptr),
                                           vcardName);
    if (attr.isNull()) {
      return null;
    }

    return ebook.e_vcard_attribute_get_value(attr);
  }},

  write: { value: function USM_write(aKey, aValue) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    if (aValue === null || aValue === undefined) {
      this.clear(aKey);
      return;
    }

    this.clear(aKey);

    let vcardName = gVCardPropFromUnsupportedTbField[aKey];
    let attr = ebook.e_vcard_attribute_new("", vcardName);

    ebook.e_vcard_attribute_add_value(attr, aValue);

    LOG("Writing vcard property \"" + vcardName + "\" as \"" + aValue + "\" for contact "
        + this.edsContact);
    ebook.e_vcard_append_attribute(ctypes.cast(this.edsContact,
                                               ebook.EVCard.ptr),
                                   attr);
  }},

  clear: { value: function USM_clear(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let vcardName = gVCardPropFromUnsupportedTbField[aKey];

    LOG("Erasing vcard property \"" + vcardName + "\" for contact " + this.edsContact);
    ebook.e_vcard_remove_attributes(ctypes.cast(this.edsContact,
                                                ebook.EVCard.ptr),
                                    null, vcardName);
  }},

  flush: { value: function USM_flush() {}}
});

// Mapper for string fields
function stringMapper(aCard, aKeys) {
  this.edsContact = aCard.edsContact;
  this._keys = aKeys;
}

stringMapper.prototype = Object.create(baseMapper, {
  read: { value: function SM_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let propKey = gEDSFieldFromTbField[aKey];
    let res = ebook.e_contact_get_const(this.edsContact,
                                        ebook.EContactFieldEnums[propKey]);
    if (res.isNull()) {
      LOG("Key \"" + propKey + "\" does not exist in " + this.edsContact);
      return null;
    }

    let value = ctypes.cast(res, glib.gchar.ptr).readString();
    LOG("Read key \"" + propKey + "\" as \"" + value + "\" for contact "
        + this.edsContact);

    return value;
  }},

  write: { value: function SM_write(aKey, aValue) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    if (aValue === null || aValue === undefined) {
      this.clear(aKey);
      return;
    }

    let propKey = gEDSFieldFromTbField[aKey];
    let propString = glib.gchar.array()(aValue.toString());

    LOG("Writing key \"" + propKey + "\" as \"" + aValue + "\" for contact "
        + this.edsContact);
    ebook.e_contact_set(this.edsContact, ebook.EContactFieldEnums[propKey],
                        propString.address());
  }},

  clear: { value: function SM_clear(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let propKey = gEDSFieldFromTbField[aKey];

    LOG("Erasing key \"" + propKey + "\" for contact " + this.edsContact);
    ebook.e_contact_set(this.edsContact, ebook.EContactFieldEnums[propKey],
                        null);
  }},

  flush: {value: function SM_flush() {}}
});

// Base class for structure fields
var structMapper = Object.create(baseMapper, {
  _init: { value: function SM__init() {
    let args = Array.prototype.slice.call(arguments, 0);

    let expectedArgLength = this._edsMembers.length + 1;
    if (args.length != expectedArgLength) {
      throw Error("Wrong number of arguments. Expected " + expectedArgLength
                  + ", got " + args.length);
    }

    this._edsKey = args[0];

    let i = 0;
    this._map = {};
    args.slice(1).forEach(function(arg) {
      this._map[arg] = this._edsMembers[i++];
    }, this);
  }},

  _load: { value: function SM__load() {
    if (this._cache) {
      return;
    }

    try {
      var prop = ctypes.cast(ebook.e_contact_get(this.edsContact,
                                                 ebook.EContactFieldEnums[this._edsKey]),
                             this._edsType.ptr);

      this._cache = {};

      if (prop.isNull()) {
        LOG("No \"" + this._edsKey + "\" property for " + this.edsContact);
        return; 
      }

      LOG("Loading \"" + this._edsKey + "\" property for " + this.edsContact);

      let msg = "";
      this.keys.forEach(function(key) {
        switch(gTbFieldTypes[key]) {
          case "string":
            this._cache[key] = prop.contents[this._map[key]].readString();
            break;
          default:
            this._cache[key] = prop.contents[this._map[key]];
            break;
        };

        msg += this._map[key] + "=\"" + this._cache[key] + "\", ";
      }, this);

      LOG(msg);
    } finally {
      if (prop && !prop.isNull()) {
        this._edsFree(prop);
      }
    }
  }},

  read: { value: function SM_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    this._load();

    return this._cache[aKey];
  }},

  write: { value: function SM_write(aKey, aValue) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    if (aValue === null || aValue === undefined) {
      this.clear(aKey);
      return;
    }

    this._load();

    switch(gTbFieldTypes[aKey]) {
      case "string":
        this._cache[aKey] = aValue.toString();
        break;

      case "number":
        this._cache[aKey] = parseInt(aValue, 10);
        break;

      default:
        throw Error("Unable to write value of unknown type \"" + gTbFieldTypes[aKey] + "\"");
        break;
    };
  }},

  clear: { value: function SM_clear(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    this._load();

    delete this._cache[aKey];
  }},

  flush: { value: function SM_flush() {
    if (!this._cache) {
      LOG("Nothing to flush to " + this.edsContact);
      return;
    }

    LOG("Flushing updated values for " + this._edsType.name + " to "
        + this.edsContact);

    let arr = new this._edsType;
    let msg = "";
    this.keys.forEach(function(key) {
      if (key in this._cache) {
        switch(gTbFieldTypes[key]) {
          case "string":
            arr[this._map[key]] = arr[this._map[key]].constructor.targetType.array()(this._cache[key]);
            break;
          default:
            if (isNaN(this._cache[key])) {
              delete this._cache[key];
            } else {
              arr[this._map[key]] = this._cache[key];
            }
            break;        
        };

        msg += this._map[key] + "=\"" + this._cache[key] + "\", ";
      }
    }, this);

    if (Object.keys(this._cache).length > 0) {
      LOG(msg);
      var toWrite = arr.address();
    } else {
      LOG("Deleting property");
      var toWrite = null;
    }

    ebook.e_contact_set(this.edsContact,
                        ebook.EContactFieldEnums[this._edsKey],
                        toWrite);

    this._cache = null;
  }},

  edsContact: { get: function SM_edsContact_get() {
    return this._edsContact;
  }, set: function SVM_edsContact_set(aContact) {
    this._edsContact = aContact;
    this._cache = null;
  }}
});

function addressMapper(aCard) {
  this.edsContact = aCard.edsContact;
}

addressMapper.prototype = Object.create(structMapper, {
  _edsType: { value: ebook.EContactAddress },
  _edsFree: { value: ebook.e_contact_address_free },
  _edsMembers: { value: ["street", "ext", "locality", "region", "code",
                         "country", "po"] }
});

function dateMapper(aCard) {
  this.edsContact = aCard.edsContact;
}

dateMapper.prototype = Object.create(structMapper, {
  _edsType: { value: ebook.EContactDate },
  _edsFree: { value: ebook.e_contact_date_free },
  _edsMembers: { value: ["year", "month", "day"] }
});

function nameMapper(aCard) {
  this.edsContact = aCard.edsContact;
}

nameMapper.prototype = Object.create(structMapper, {
  _edsType: { value: ebook.EContactName },
  _edsFree: { value: ebook.e_contact_name_free },
  _edsMembers: { value: ["family", "given"] },

  _init: { value: function NM__init() {
    Object.getPrototypeOf(Object.getPrototypeOf(this))._init.call(this,
                                                                  "E_CONTACT_NAME",
                                                                  "LastName",
                                                                  "FirstName");
  }},

  flush: { value: function NM_flush() {
    if (!this._cache) {
      LOG("Nothing to flush to " + this.edsContact);
      return;
    }

    let full = "";
    if (this._cache["given"]) {
      full += this._cache["given"];
    }
    if (this._cache["family"]) {
      if (full != "") {
        full += " ";
      }
      full += this._cache["family"];
    }

    Object.getPrototypeOf(Object.getPrototypeOf(this)).flush.call(this);
    
    ebook.e_contact_set(this.edsContact,
                        ebook.EContactFieldEnums.E_CONTACT_FULL_NAME,
                        full == "" ? null : glib.gchar.array()(full));
  }}
});

function photoMapper(aCard) {
  this.edsContact = aCard.edsContact;
  this._cache = null;
  this._newPhotoCache = null;
}

photoMapper.prototype = Object.create(baseMapper, {
  _keys: { value: ["PhotoName", "PhotoURI", "RawData",
                   "RawDataLength", "MimeType", "PhotoType"] },

  _load: { value: function PM__load() {
    if (this._cache) {
      return;
    }

    try {
      var res = ctypes.cast(ebook.e_contact_get(this.edsContact,
                                                ebook.EContactFieldEnums.E_CONTACT_PHOTO),
                            ebook.EContactPhoto.ptr);

      this._cache = {};

      if (res.isNull()) {
        LOG("No photo for contact " + this.edsContact);
        return;
      }

      LOG("Loading photo for contact " + this.edsContact);

      let inlined = res.contents.type ==
                    ebook.EContactPhotoTypeEnums.E_CONTACT_PHOTO_TYPE_INLINED ? true : false;

      if (!inlined) {
        WARN("Non-inlined photos are not currently supported");
      }

      // XXX: No support for non-inlined yet
      this._cache["PhotoName"] = "";
      this._cache["PhotoURI"] = "";
      this._cache["MimeType"] = inlined ? res.contents.data.inlined.mime_type.readString() : "";
      this._cache["RawDataLength"] = inlined ? res.contents.data.inlined.length : 0;
      this._cache["RawData"] = inlined ?
                                 String.fromCharCode.apply(null,
                                                           ctypes.cast(res.contents.data.inlined.data,
                                                                       glib.guchar.array(this._cache["RawDataLength"]).ptr).contents) : "";
      this._cache["PhotoType"] = this._cache["RawDataLength"] == 0 ? "generic" : "eds";

      LOG("PhotoName=\"" + this._cache["PhotoName"] +
          "\", PhotoURI=\"" + this._cache["PhotoURI"] +
          "\", MimeType=\"" + this._cache["MimeType"] +
          "\", RawDataLength=" + this._cache["RawDataLength"] +
          ", PhotoType=\"" + this._cache["PhotoType"] + "\"");
    } finally {
      if (res && !res.isNull()) {
        ebook.e_contact_photo_free(res);
      }
    }
  }},

  read: { value: function PR_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    this._load();

    return this._cache[aKey];
  }},

  write: { value: function PR_write(aKey, aValue) {
    // We can only write to RawData - all other writes are ignored.
    if (aKey != "RawData") {
      WARN("Can only write the RawData value");
      return;
    }

    if (!aValue) {
      this.clear(aKey);
      return;
    }

    LOG("Writing photo for contact " + this.edsContact);

    this._cache = null;

    let photo = new ebook.EContactPhoto;

    photo.type = ebook.EContactPhotoTypeEnums.E_CONTACT_PHOTO_TYPE_INLINED;
    photo.data.inlined.mime_type = null;
    photo.data.inlined.data = glib.guchar.array()(aValue);
    photo.data.inlined.length = aValue.length;

    ebook.e_contact_set(this.edsContact,
                        ebook.EContactFieldEnums.E_CONTACT_PHOTO,
                        photo.address());
  }},

  clear: { value: function PM_clear(aKey) {
    // We can only write to RawData - all other writes are ignored.
    if (aKey != "RawData") {
      return;
    }

    this._load();

    if (!("PhotoType" in this._cache)) {
      LOG("Not erasing photo from contact " + this.edsContact +
          " which didn't previously have a photo");
      return;
    }

    this._cache = null;

    ebook.e_contact_set(this.edsContact,
                        ebook.EContactFieldEnums.E_CONTACT_PHOTO,
                        null);
  }},

  cloneMap: { value: function PM_cloneMap() {
    let result = {};
    let mime = this.read("MimeType");
    let mimeService = Cc["@mozilla.org/mime;1"].getService(Ci.nsIMIMEService);
    try {
      var fileExt = mimeService.getPrimaryExtension(mimeType, fileExt);
    } catch(e) {}
    let data = this.read("RawData");
    let dataLength = this.read("RawDataLength");

    if (!data) {
      result["PhotoType"] = "generic";
      return result;
    }

    let fileName = "edsContact" + "." + fileExt;

    let file = FileUtils.getFile("ProfD", ["Photos", fileName]);
    file.createUnique(Ci.nsIFile.NORMAL_FILE_TYPE, 0666);
    let ostream = FileUtils.openSafeFileOutputStream(file);
    let istream = Cc["@mozilla.org/io/string-input-stream;1"].createInstance(Ci.nsIStringInputStream);
    istream.setData(data, dataLength);
    NetUtil.asyncCopy(istream, ostream, function(status) {});

    let photoURI = Services.io.newFileURI(file).spec;

    result["PhotoType"] = "file";
    result["PhotoName"] = file.leafName;
    result["PhotoURI"] = photoURI;

    return result;
  }},

  flush: { value: function PM_flush(aCard) {}},

  edsContact: { get: function PM_edsContact_get() {
    return this._edsContact;
  }, set: function PM_edsContact_get(aContact) {
    this._edsContact = aContact;
    this._cache = null;
  }}
});

function booleanMapper(aCard, aMap) {
  this.edsContact = aCard.edsContact;

  this._trueMap = {};
  this._falseMap = {};

  this._keys = Object.keys(aMap);
  this.keys.forEach(function(key) {
    if (typeof(aMap[key].true) != "object") {
      aMap[key].true = [aMap[key].true];
    }
    if (typeof(aMap[key].false) != "object") {
      aMap[key].false = [aMap[key].false];
    }
    this._trueMap[key] = aMap[key].true;
    this._falseMap[key] = aMap[key].false;
  }, this);
}

booleanMapper.prototype = Object.create(baseMapper, {
  read: { value: function BM_read(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    let propKey = gEDSFieldFromTbField[aKey];

    let res = ebook.e_contact_get(this.edsContact,
                                  ebook.EContactFieldEnums[propKey]);
    LOG("Read \"" + propKey + "\" for " + this.edsContact + " as "
        + (res.isNull() ? "\"false\"" : "\"true\""));

    if (res.isNull()) {
      return this._falseMap[aKey][0];
    } else {
      return this._trueMap[aKey][0];
    }
  }},

  write: { value: function BM_write(aKey, aValue) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    aValue = aValue.toString();

    if (this._trueMap[aKey].indexOf(aValue) != -1) {
      var writeVal = glib.TRUE;
    } else if (this._falseMap[aKey].indexOf(aValue) != -1) {
      var writeVal = glib.FALSE;
    } else {
      throw Error("Boolean value \"" + aValue + "\" is not recognized for key \"" + aKey + "\"");
    }

    let propKey = gEDSFieldFromTbField[aKey];

    LOG("Writing \"" + propKey + "\" for " + this.edsContact + " as \""
        + writeVal + "\"");
    ebook.e_contact_set(this.edsContact,
                        ebook.EContactFieldEnums[propKey],
                        glib.GINT_TO_POINTER(writeVal));
  }},

  clear: { value: function BM_clear(aKey) {
    if (!this.readsKey(aKey)) {
      throw Error("Key \"" + aKey + "\" is not recognized");
    }

    this.write(aKey, this._falseMap[aKey]);
  }},

  flush: { value: function BM_flush(aCard) {}}
});

function constructEDSFieldMappers(aCard) {
  aCard._mappers = [];
  try {
    gMapperConstructors.forEach(function(mapperConstructor) {
      aCard._mappers.push(mapperConstructor(aCard));
    });
  } catch(e) {
    aCard._mappers = [];
    ERROR("Failed to construct mappers", e);
    throw e;
  }
}
