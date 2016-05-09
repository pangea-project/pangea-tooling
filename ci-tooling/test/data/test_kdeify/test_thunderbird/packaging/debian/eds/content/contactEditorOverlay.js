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
Components.utils.import("resource:///modules/iteratorUtils.jsm");

Components.utils.import("resource://edsintegration/modules/EDSPhotoHandlers.jsm");

Components.utils.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");
Components.utils.import("resource://edsintegration/modules/nsAbEDSEmailAddress.jsm");
Components.utils.import("resource://edsintegration/modules/nsAbEDSPhone.jsm");
Components.utils.import("resource://edsintegration/modules/nsAbEDSIMAccount.jsm");

var EDSContactEditor = {
  MAX_EMAILS: 4,
  EMAIL_DEFAULTS: [0, 1, 2, 2],
  EMAIL_TYPES: [
    "WORK",
    "HOME",
    "OTHER"
  ],

  MAX_PHONES: 8,
  PHONE_DEFAULTS: [1, 6, 9, 2, 7, 12, 10, 10],
  PHONE_TYPES: {
    "_edsAssistantPhone": "property_edsAssistantPhone",
    "WorkPhone": "propertyWorkPhone",
    "_edsWorkFax": "property_edsWorkFax",
    "_edsCallbackPhone": "property_edsCallbackPhone",
    "_edsCarPhone": "property_edsCarPhone",
    "_edsCompanyPhone": "property_edsCompanyPhone",
    "HomePhone": "propertyHomePhone",
    "FaxNumber": "propertyFaxNumber",
    "_edsISDNNumber": "property_edsISDNNumber",
    "CellularNumber": "propertyCellularNumber",
    "_edsOtherPhone": "property_edsOtherPhone",
    "_edsOtherFax": "property_edsOtherFax",
    "PagerNumber": "propertyPagerNumber",
    "_edsPrimaryPhone": "property_edsPrimaryPhone",
    "_edsRadioNumber": "property_edsRadioNumber",
    "_edsTelexNumber": "property_edsTelexNumber",
    "_edsTTYNumber": "property_edsTTYNumber",
  },

  MAX_IM_ACCOUNTS: 4,
  IM_DEFAULTS: [0, 2, 4, 5],
  IM_TYPES: {
    "_AimScreenName": "propertyAimScreenName",
    "_JabberId": "propertyJabberId",
    "_Yahoo": "propertyYahoo",
    "_edsGaduGadu": "property_edsGaduGadu",
    "_MSN": "propertyMSN",
    "_ICQ": "propertyICQ",
    "_edsGroupwise": "property_edsGroupwise",
    "_Skype": "propertySkype",
    "_GoogleTalk": "propertyGoogleTalk",
    "_QQ": "propertyQQ",
    "_edsTwitter": "property_edsTwitter"
  },

  NORMAL_ONLY_FIELDS: ["PrimaryEmailContainer",
                       "SecondaryEmailContainer",
                       "customFields",
                       "abIMAccounts",
                       "WebPage1Container",
                       "WebPage2Container",
                       "PreferDisplayNameContainer",
                       "PhoneNumbers",
                       "ScreenNameContainer",
                       "allowRemoteContent",
                      ],

  EDS_ONLY_FIELDS: ["telephoneTabButton",
                    "abTelephoneTab",
                    "EDSIMAccounts",
                    "webAddressesTabButton",
                    "abWebAddressesTab",
                    "HomePOBox-Label",
                    "HomePOBox",
                    "SpouseContainer",
                    "ProfessionContainer",
                    "ManagerAssistantContainer",
                    "WorkPOBox-Label",
                    "WorkPOBox",
                    "OtherAddressContainer",
                    "EDSPhotoContainer",
                    "emailAddresses",
                   ],

  ID_MAP: {
    "PreferMailFormat": [ "PreferMailFormatPopup" ],
    "BirthDay": [ "Birthday" ],
    "BirthYear": [ "BirthYear", "Age" ],
    "AnniversaryDay": [ "SpouseAnniversary" ]
  },

  SIMPLE_FIELDS: [
    "HomePOBox",
    "HomePage",
    "Blog",
    "Calendar",
    "FreeBusy",
    "VideoChat",
    "Spouse",
    "Profession",
    "Manager",
    "Assistant",
    "WorkPOBox",
    "WorkOffice",
    "OtherAddress",
    "OtherAddress2",
    "OtherCity",
    "OtherState",
    "OtherZipCode",
    "OtherCountry",
    "OtherPOBox",
  ],

  get bundle() {
    if (EDSContactEditor._bundle)
      return EDSContactEditor._bundle;

    EDSContactEditor._bundle = Services.strings.createBundle("chrome://edsintegration/locale/contactEditor.properties");
    return EDSContactEditor._bundle;
  },

  getString: function getString(aStringName) {
    try {
      return EDSContactEditor.bundle.GetStringFromName(aStringName);
    }
    catch (e) {
      Services.console.logStringMessage(e.message);
    }
    return "";
  },

  onLoad: function EDSCE_onLoad() {
    // RegisterLoadListener and RegisterSaveListener
    // are defined in abCardOverlay.js
    RegisterLoadListener(EDSContactEditor.onLoadCard);
  },

  onLoadCard: function EDSCE_onLoadCard(aCard, aDocument) {
    aDocument.getElementById("abChatTab").getElementsByTagName("vbox")[0]
                                         .setAttribute("id", "abIMAccounts");
    // If this isn't an EDS card...
    if (!(aCard instanceof Components.interfaces.nsIAbEDSCard)) {
      // Not an nsIAbEDSCard, bail out...
      EDSContactEditor.goInert(aDocument);
      return;
    }
    EDSContactEditor.goActive(aDocument, aCard.parentDirectory);
    EDSContactEditor.populateEDSFields(aCard, aDocument);
  },

  onSaveCard: function EDSCE_onSaveCard(aCard, aDocument) {
    if (!(aCard instanceof Components.interfaces.nsIAbEDSCard)) {
      return;
    }

    // Get basic string values
    EDSContactEditor.SIMPLE_FIELDS.forEach(function(field) {
      let id = field;
      if (field in EDSContactEditor.ID_MAP) {
        id = EDSContactEditor.ID_MAP[field][0];
      }

      aCard.setProperty(field, aDocument.getElementById(id).value);
    });

    // Get email address values
    let newEmails = [];
    for (let i = 0; i < EDSContactEditor.MAX_EMAILS; i++) {
      let address = aDocument.getElementById("emailField-" + (i+1)).value;
      if (address) {
        let email = new nsAbEDSEmailAddress();
        email.address = address;
        email.type = aDocument.getElementById("emailField-" + (i+1) + "-Type").value;
        newEmails.push(email);
      }
    }

    // Trim the first |MAX_EMAILS| items from the old list
    let oldEmails = aCard.getEmailAddrs({});
    for (let i = 0; oldEmails.length > 0 && i < EDSContactEditor.MAX_EMAILS; i++) {
      oldEmails.shift();
    }

    // Now splice the remainder on to the end of the new list
    newEmails = newEmails.concat(oldEmails);

    aCard.setEmailAddrs(newEmails.length, newEmails);

    // Get phone values
    let newPhones = [];
    for (let i = 0; i < EDSContactEditor.MAX_PHONES; i++) {
      let number = aDocument.getElementById("telephoneField-" + (i+1)).value;
      if (number) {
        let phone = new nsAbEDSPhone();
        phone.number = number;
        phone.type = aDocument.getElementById("telephoneField-" + (i+1) + "-Type").value;
        newPhones.push(phone);
      }
    }

    // Trim the first |MAX_PHONES| items from the old list
    let oldPhones = aCard.getPhoneNumbers({});
    for (let i = 0; oldPhones.length > 0 && i < EDSContactEditor.MAX_PHONES; i++) {
      oldPhones.shift();
    }

    // Now splice the remainder on to the end of the new list
    newPhones = newPhones.concat(oldPhones);

    aCard.setPhoneNumbers(newPhones.length, newPhones);

    // Get IM Account values
    let newIMAccounts = [];
    for (let i = 0; i < EDSContactEditor.MAX_IM_ACCOUNTS; i++) {
      let username = aDocument.getElementById("IM-" + (i+1)).value;
      if (username) {
        let account = new nsAbEDSIMAccount();
        account.username = username;
        account.type = aDocument.getElementById("IM-" + (i+1) + "-Type").value;
        newIMAccounts.push(account);
      }
    }

    // Trim the first |MAX_IM_ACCOUNTS| items from the old list
    let oldIMAccounts = aCard.getIMAccounts({});
    for (let i = 0; oldIMAccounts.length > 0 &&
         i < EDSContactEditor.MAX_IM_ACCOUNTS; i++) {
      oldIMAccounts.shift();
    }

    // Now splice the reaminder on to the end of the new list
    newIMAccounts = newIMAccounts.concat(oldIMAccounts);

    aCard.setIMAccounts(newIMAccounts.length, newIMAccounts);

    let annElem = aDocument.getElementById("SpouseAnniversary");
    let annMonth = annElem.monthField.value;
    let annDay = annElem.dateField.value;
    let annYear = aDocument.getElementById("AnniversaryYear").value;

    // set the birth day, month, and year properties
    aCard.setProperty("AnniversaryDay", annDay);
    aCard.setProperty("AnniversaryMonth", annMonth);
    aCard.setProperty("AnniversaryYear", annYear);
  },

  goInert: function EDSCE_goInert(aDocument) {
     // Unregister save listener
     UnregisterSaveListener(EDSContactEditor.onSaveCard);
     // Unregister photo handlers
     EDSContactEditor.appearAsNormalCard(aDocument);
     registerPhotoHandler("eds", function(aCard, aImg) { return false;});
     registerPhotoHandler("generic", genericPhotoHandler);
     registerPhotoHandler("file", filePhotoHandler);
     registerPhotoHandler("web", webPhotoHandler);

     EDSContactEditor.cardFieldsDisabled(aDocument, false);
     aDocument.defaultView.sizeToContent();
  },

  goActive: function EDSCE_goActive(aDocument, aDirectory) {

    EDSContactEditor.appearAsEDSCard(aDocument);

    RegisterSaveListener(EDSContactEditor.onSaveCard);
    registerPhotoHandler("eds", EDSPhotoHandler);
    registerPhotoHandler("generic", EDSGenericPhotoHandler);
    registerPhotoHandler("file", EDSFilePhotoHandler);
    registerPhotoHandler("web", EDSWebPhotoHandler);

    EDSContactEditor.cardFieldsDisabled(aDocument, true);

    // First, your basic text input fields
    aDirectory.getSupportedFields({}).forEach(function(field) {
      let ids = [field];
      if (field in EDSContactEditor.ID_MAP) {
        ids = EDSContactEditor.ID_MAP[field];
      }

      ids.forEach(function(id) {
        let element = aDocument.getElementById(id);
        if (element) {
          element.disabled = false;
        }
      });
    });

    // Then the email fields.

    // We want to clear out the PrimaryEmail field, because TB tries to
    // validate data in that field, and the user has no control of
    // it in this state.  Because TB auto-populates the PrimaryEmail
    // after the onLoadCard event, and checks it before the onSaveCard
    // event, here's a hack - any time the new email textboxes are
    // changed, we force a clearout of PrimaryEmail.
    let primaryEmail = aDocument.getElementById("PrimaryEmail");

    for (let i = 0; i < EDSContactEditor.MAX_EMAILS; i++) {
      let menulist = aDocument.getElementById("emailField-" + (i + 1) + "-Type");
      let saved = menulist.value;
      menulist.removeAllItems();

      let select;
      EDSContactEditor.EMAIL_TYPES.forEach(function(value) {
        let label = EDSContactEditor.getString("email" + value);
        let item = menulist.appendItem(label, value, null);
        if (value == saved) {
          select = item;
        }
      });

      if (select) {
        menulist.selectedItem = select;
      } else {
        menulist.value = EDSContactEditor.EMAIL_TYPES[EDSContactEditor
                                                      .EMAIL_DEFAULTS[i]];
      }

      if (menulist.itemCount > 0) {
        let emailField = aDocument.getElementById("emailField-" + (i+1));
        emailField.disabled = false;
        emailField.onchange = function(event) {
          primaryEmail.value = "";
        };
        menulist.disabled = false;
      }
    }

    // Then the phone fields
    for (let i = 0; i < EDSContactEditor.MAX_PHONES; i++) {
      let menulist = aDocument.getElementById("telephoneField-" + (i + 1) + "-Type");
      let saved = menulist.value;
      menulist.removeAllItems();

      let select;
      Object.keys(EDSContactEditor.PHONE_TYPES).forEach(function(value) {
        if (aDirectory.getSupportedPhoneTypes({}).indexOf(value) != -1) {
          let label = EDSContactEditor.getString(EDSContactEditor
                                                 .PHONE_TYPES[value]);
          let item = menulist.appendItem(label, value, null);
          if (value == saved) {
            select = item;
          }
        }
      });

      if (select) {
        menulist.selectedItem = select;
      } else {
        menulist.value = Object.keys(EDSContactEditor
                                     .PHONE_TYPES)[EDSContactEditor
                                                   .PHONE_DEFAULTS[i]];
      }

      if (menulist.itemCount > 0) {
        aDocument.getElementById("telephoneField-" + (i + 1)).disabled = false;
        menulist.disabled = false;
      }
    }

    // Then the IM fields
    for (let i = 0; i < EDSContactEditor.MAX_IM_ACCOUNTS; i++) {
      let menulist = aDocument.getElementById("IM-" + (i + 1) + "-Type");
      let saved = menulist.value;
      menulist.removeAllItems();

      let select;
      Object.keys(EDSContactEditor.IM_TYPES).forEach(function(value) {
        if (aDirectory.getSupportedIMTypes({}).indexOf(value) != -1) {
          let label = EDSContactEditor.getString(EDSContactEditor
                                                 .IM_TYPES[value]);
          let item = menulist.appendItem(label, value, null);
          if (value == saved) {
            select = item;
          }
        }
      });

      if (select) {
        menulist.selectedItem = select;
      } else {
        menulist.value = Object.keys(EDSContactEditor
                                     .IM_TYPES)[EDSContactEditor
                                                .IM_DEFAULTS[i]];
      }

      if (menulist.itemCount > 0) {
        aDocument.getElementById("IM-" + (i + 1)).disabled = false;
        menulist.disabled = false;
      }
    }

    // Then the photo fields
    if (aDirectory.getSupportedFields({}).indexOf("PhotoType") != -1) {
      let photoTab = aDocument.querySelector('#abPhotoTab');
      let photoFields = photoTab.querySelectorAll("textbox, menulist, radiogroup, button, fileField");
      for (let i = 0; i < photoFields.length; i++)
        photoFields[i].disabled = false;
    }

    aDocument.defaultView.sizeToContent();
  },

  cardFieldsDisabled: function EDSCE_cardFieldsDisabled(aDocument, aDisabled) {
     let editCard = aDocument.querySelector("#editcard");
     let inputs = editCard.querySelectorAll("textbox, datepicker, menulist,"
                                             + "radiogroup, button, filefield");

     for (let i = 0; i < inputs.length; i++) {
       inputs[i].disabled = aDisabled;
     }
  },

  appearAsNormalCard: function EDSCE_appearAsNormalCard(aDocument) {
    EDSContactEditor.NORMAL_ONLY_FIELDS.forEach(function(aID) {
      aDocument.getElementById(aID).collapsed = false;
    });

    EDSContactEditor.EDS_ONLY_FIELDS.forEach(function(aID) {
      aDocument.getElementById(aID).collapsed = true;
    });
  },

  appearAsEDSCard: function EDSCE_appearAsEDSCard(aDocument) {
    EDSContactEditor.NORMAL_ONLY_FIELDS.forEach(function(aID) {
      aDocument.getElementById(aID).collapsed = true;
    });

    EDSContactEditor.EDS_ONLY_FIELDS.forEach(function(aID) {
      aDocument.getElementById(aID).collapsed = false;
    });

    modifyDatepicker(aDocument.getElementById("SpouseAnniversary"));
  },

  populateEDSFields: function EDSCE_PopulateEDSFields(aCard, aDocument) {

    function fillEmailSlot(aSlot, aValue, aType) {
      aDocument.getElementById("emailField-" + (aSlot+1)).value = aValue;
      aDocument.getElementById("emailField-" + (aSlot+1) + "-Type").value = aType;
    }

    function fillPhoneSlot(aSlot, aValue, aType) {
      aDocument.getElementById("telephoneField-" + (aSlot+1)).value = aValue;
      aDocument.getElementById("telephoneField-" + (aSlot+1) + "-Type").value = aType;
    }

    function fillIMSlot(aSlot, aValue, aType) {
      aDocument.getElementById("IM-" + (aSlot+1)).value = aValue;
      aDocument.getElementById("IM-" + (aSlot+1) + "-Type").value = aType;
    }

    for (let i = 0; i < EDSContactEditor.MAX_EMAILS; i++) {
      fillEmailSlot(i, "", EDSContactEditor.EMAIL_TYPES[EDSContactEditor
                                                        .EMAIL_DEFAULTS[i]]);
    }

    for (let i = 0; i < EDSContactEditor.MAX_PHONES; i++) {
      fillPhoneSlot(i, "", Object.keys(EDSContactEditor
                                       .PHONE_TYPES)[EDSContactEditor
                                                     .PHONE_DEFAULTS[i]]);
    }

    for (let i = 0; i < EDSContactEditor.MAX_IM_ACCOUNTS; i++) {
      fillIMSlot(i, "", Object.keys(EDSContactEditor
                                    .IM_TYPES)[EDSContactEditor
                                               .IM_DEFAULTS[i]]);
    }

    // Get the email addresses
    let emailAddrs = aCard.getEmailAddrs({});
    for (let i = 0; i < emailAddrs.length && i < EDSContactEditor.MAX_EMAILS;
         i++) {
      let email = emailAddrs[i];
      fillEmailSlot(i, email.address, email.type);
    }

    // Get the phone numbers
    let phoneNumbers = aCard.getPhoneNumbers({});
    for (let i = 0; i < phoneNumbers.length && i < EDSContactEditor.MAX_PHONES;
         i++) {
      let phone = phoneNumbers[i];
      fillPhoneSlot(i, phone.number, phone.type);
    }

    // And the IM accounts
    let accounts = aCard.getIMAccounts({});
    for (let i = 0; i < accounts.length && i < EDSContactEditor.MAX_IM_ACCOUNTS;
         i++) {
      let account = accounts[i];
      fillIMSlot(i, account.username, account.type);
    }

    EDSContactEditor.SIMPLE_FIELDS.forEach(function(field) {
      let id = field;
      if (field in EDSContactEditor.ID_MAP) {
        id = EDSContactEditor.ID_MAP[field][0];
      }

      document.getElementById(id).value = aCard.getProperty(field, "");
    });

    let anniversaryField = aDocument.getElementById("SpouseAnniversary");
    // get the month of the year (1 - 12)
    let month = aCard.getProperty("AnniversaryMonth", null);
    if (month > 0 && month < 13) {
      anniversaryField.month = month - 1;
    } else {
      anniversaryField.monthField.value = null;
    }

    // get the date of the month (1 - 31)
    let date = aCard.getProperty("AnniversaryDay", null);
    if (date > 0 && date < 32) {
      anniversaryField.date = date;
    } else {
      anniversaryField.dateField.value = null;
    }

    // get the year
    let year = aCard.getProperty("AnniveraryYear", null);
    let annYear = aDocument.getElementById("AnniversaryYear");
    // set the year in the datepicker to the stored year
    // if the year isn't present, default to 2000 (a leap year)
    anniversaryField.year = year && year < 10000 && year > 0 ? year : kDefaultYear;
    annYear.value = year;

    // If the photo type is eds-generic, then make the "Keep the current photo"
    // radio option invisible.
    if (aCard.getProperty("PhotoType", "generic") == "generic") {
      aDocument.getElementById("EDSPhotoType").collapsed = true;
    }
  }
}

EDSContactEditor.onLoad();
