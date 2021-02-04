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

var EXPORTED_SYMBOLS = [ "nsAbEDSDirectory", "nsAbEDSDirFactory" ];

const kDirType = "moz-abedsdirectory";
const kDirScheme = kDirType + "://";
const kDirPrefId = "ldap_2.servers.eds";
const kFactoryContractID =  "@mozilla.org/addressbook/directory-factory;1?name=" + kDirType
const kDirContractID = "@mozilla.org/addressbook/directory;1?type=" + kDirType;

const kAuthDialogURI = "chrome://edsintegration/content/authDialog.xul";

var gMailListCount = 0;

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource:///modules/mailServices.js");
Cu.import("resource:///modules/iteratorUtils.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");
Cu.import("resource://edsintegration/libs/gio.jsm");
Cu.import("resource://edsintegration/libs/eds.jsm");
Cu.import("resource://edsintegration/libs/ebook.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");
Cu.import("resource://edsintegration/modules/AuthHelper.jsm");
Cu.import("resource://edsintegration/modules/ESourceProvider.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSPhone.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSEmailAddress.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSIMAccount.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSCard.jsm");
Cu.import("resource://edsintegration/modules/EDSFieldMappers.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSMailingList.jsm");

addLogger(this);

var gDeleteWarned = false;

/* The nsAbEDSDirectory Factory, which implements nsIAbDirFactory.
 */
function nsAbEDSDirFactory() {};

nsAbEDSDirFactory.prototype = {
  classDescription: "EDS Address Book Factory Factory",
  classID: Components.ID("{d44d17c2-70a6-4c0c-8b5f-de4b7d478275}"),
  contractID: kFactoryContractID,
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIAbDirFactory]),

  getDirectories: function AbEDSDF_getDirectories(aDirName, aURI, aPrefName) {
    LOG("Getting EDS addressbook directories");
    let result = [];
    for (let source in ESourceProvider.sources) {
      // FIXME: Should check if the source is enabled
      let abUri = kDirScheme + eds.e_source_get_uid(source);
      LOG("Found source " + abUri);
      try {
        let dir = MailServices.ab.getDirectory(abUri);
        result.push(dir);
      } catch(e) {
        ERROR("Could not properly create directory with uri: " + abUri + " - skipping", e);
      }
    }
    return CreateSimpleEnumerator(result);
  },

  deleteDirectory: function AbEDSDF_deleteDirectory(aDirectory) {
    // Currently unsupported.  Alert the user and bail out.
    ERROR("Attempted to delete an EDS directory, which is currently"
          + " an unsupported action.");
    if (!gDeleteWarned) {
      Services.prompt.alert(null, _("CannotDeleteDirectoryTitle"),
                            _("CannotDeleteDirectory"));
      gDeleteWarned = true;
    }
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },
};

/* nsAbEDSDirectory, implements nsIAbEDSDirectory, nsIAbDirectory,
 * nsIAbDirSearchListener and nsIAbDirectorySearch.
 */
function nsAbEDSDirectory() {
  this._initialized = false;
  this._openInProgress = false;
  this._open = false;
  this._proxy = null;
  this._uri = "";
  this._childCards = {}; // Cards indexed by EDS UID
  this._childNodes = {}; // Mailing lists indexed by local directory URI
  this._childContacts = {}; // All children indexed by EDS UID
  this.__edsSourceUid = null;
  this.__edsSource = null; // ESource
  this.__edsClient = null; // EClient
  this._edsBookClientView = null; // EBookClientView
  this.__supportedFields = null;
  this.__supportedPhoneTypes = null;
  this.__supportedIMTypes = null;
  this._query = "";
  this._searchCache = [];
  this._view_sigids = [];
}

nsAbEDSDirectory.prototype = {
  classDescription: "Evolution Data Server Address Book Type",
  classID: Components.ID("{9bb88c4e-2498-4bc0-95b7-a80f3809ba04}"),
  contractID: kDirContractID,
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIAbEDSDirectory,
                                         Ci.nsIAbDirectory,
                                         Ci.nsIAbCollection,
                                         Ci.nsIAbItem,
                                         Ci.nsIAbDirSearchListener,
                                         Ci.nsIAbDirectorySearch]),

  _xpcom_factory: {
    createInstance: function(aOuter, aIID) {
      if (aOuter != null) {
        throw Cr.NS_ERROR_NO_AGGREGATION;
      }

      return (new nsAbEDSTransformer()).QueryInterface(aIID);
    }
  },

  /* If this nsAbEDSDirectory proxies to another nsAbEDSDirectory,
   * get the proxy.
   */
  get proxy() {
    if (this._proxy)
      return this._proxy.proxy;
    return this;
  },

  get _supportedFields() {
    return this.proxy.__supportedFields;
  },

  get _supportedPhoneTypes() {
    return this.proxy.__supportedPhoneTypes;
  },

  get _supportedIMTypes() {
    return this.proxy.__supportedIMTypes;
  },

  /* Return the EBook associated with this nsAbEDSDirectory.  If we're
   * a proxy, get the EBook from the nsAbEDSDirectory that we proxy to.
   */
  get _edsBookClient() {
    return ctypes.cast(this._edsClient, ebook.EBookClient.ptr);
  },

  get _edsClient() {
    return this.proxy.__edsClient;
  },

  /* Return the ESource associated with this nsAbEDSDirectory.  If we're
   * a proxy, get the ESource from the nsAbEDSDirectory that we proxy to.
   */
  get _edsSource() {
    return this.proxy.__edsSource;
  },

  /* Return the UID for the ESource associated with this nsAbEDSDirectory.
   * If we're a proxy, get the UID for the ESource from the nsAbEDSDirectory
   * that we proxy to.
   */
  get _edsSourceUid() {
    return this.proxy.__edsSourceUid;
  },

  _deleteContactFinish: function AbEDSD__deleteContactFinish(aObject, aRes, aId) {
    let error = new glib.GError.ptr;
    if (!ebook.e_book_client_remove_contact_finish(ctypes.cast(aObject,
                                                               ebook.EBookClient.ptr),
                                                   aRes, error.address())) {
      ERROR("Failed to delete contact " + aId + " from " + this.URI + ": "
            + error.contents.message.readString());
      glib.g_error_free(error);
    }
  },

  _disappearDirectories: function AbEDSD__disappearDirectories(aDirectories) {
    for (let aDirectory in fixIterator(aDirectories)) {
      let uri = aDirectory.URI;

      if (!this._childNodes[uri]) {
        WARN("No mailing list with URI " + uri + " found in directory " + this.URI);
        continue;
      }

      LOG("Handling removal of mailing list " + uri + " from directory " + this.URI);

      delete this._childNodes[uri];
      delete this._childContacts[aDirectory.edsID];

      MailServices.ab.notifyDirectoryItemDeleted(this, aDirectory);
      aDirectory.dispose();
    }
  },

  _disappearCards: function AbEDSD__disappearCards(aCards) {
    for (let card in fixIterator(aCards)) {
      let uri = card.localId;

      if (!(uri in this._childCards)) {
        WARN("No card with URI " + uri + " found in directory " + this.URI);
        continue;
      }

      LOG("Handling removal of card " + uri + " from directory " + this.URI);

      delete this._childCards[uri];
      delete this._childContacts[uri];

      MailServices.ab.notifyDirectoryItemDeleted(this, card);
      card.dispose();
    }
  },

  /* Attempt to retrieve cards for this EBookClient.
   */
  _initCards: function AbEDSD__initCards() {
    LOG("Initializing cards for directory " + this.URI);

    if (this._edsBookClientView) {
      throw Error("Cards already initialized for directory " + this.URI);
    }

    // Construct the EBookQuery
    let query = ebook.e_book_query_any_field_contains("");
    let queryString = ebook.e_book_query_to_string(query);

    let self = this;
    ebook.e_book_client_get_view(this._edsBookClient, queryString, null,
                                 function(aSource, aRes) {
      try {
        let client = ctypes.cast(aSource, ebook.EBookClient.ptr);
        let view = new ebook.EBookClientView.ptr();
        var error = new glib.GError.ptr();

        if (!ebook.e_book_client_get_view_finish(client, aRes,
                                                 view.address(), error.address())) {
          ERROR("Problem retrieving directory view for " + self.URI + ": " +
                error.contents.message.readString());
          return;
        }

        self._edsBookClientView = view;
      } finally {
        if (error && !error.isNull()) {
          glib.g_error_free(error);
        }
      }

      LOG("Got directory view for " + self.URI);

      self._view_sigids.push(
        gobject.g_signal_connect(self._edsBookClientView, "objects-added",
                                 function(aEDSBookView, aArg1) {
          LOG("Objects added to directory " + self.URI);
          for (let contact in glib.listIterator(ctypes.cast(aArg1, glib.GList.ptr),
                                                ebook.EContact.ptr, false)) {
            let isMailList = ebook.e_contact_get(contact,
                                                 ebook.EContactFieldEnums.E_CONTACT_IS_LIST);
            try {
              if (!isMailList.isNull())
                self._createMailList(contact);
              else
                self._createCard(contact);
            }
            catch(e) {
              ERROR("Failed to add object to directory " + self.URI, e);
            }
          }
        })
      );

      self._view_sigids.push(
        gobject.g_signal_connect(self._edsBookClientView, "objects-modified",
                                 function(aEDSBookView, aArg1) {
          LOG("Objects modified in directory " + self.URI);
          for (let contact in glib.listIterator(ctypes.cast(aArg1, glib.GList.ptr),
                                                ebook.EContact.ptr, false)) {
            // Get the uid for this EContact, and use that
            // to look up the right nsAbEDSCard
            let cstr = ctypes.cast(ebook.e_contact_get_const(contact,
                                                             ebook.EContactFieldEnums.E_CONTACT_UID),
                                   glib.gchar.ptr);
            if (cstr.isNull()) {
              ERROR("Contact has no UID");
              continue;
            }

            let uid = cstr.readString();
            // if we can't find the nsAbEDSCard, then that means
            // that the cards haven't been retrieved yet. That's
            // ok, just skip it.
            if (uid in self._childContacts) {
              self._childContacts[uid].edsContact = contact;
            } else {
              WARN("No card with uid " + uid + " found in directory " + self.URI);
            }
          }
        })
      );

      self._view_sigids.push(
        gobject.g_signal_connect(self._edsBookClientView, "objects-removed",
                                 function(aEDSBookView, aArg1) {
          LOG("Objects removed from directory " + self.URI);
          let cardRemoval = [];
          let listRemoval = [];
          for (let uidc in glib.listIterator(ctypes.cast(aArg1, glib.GList.ptr),
                                             glib.gchar.ptr, false)) {
            uid = uidc.readString();

            // if we can't find the nsAbEDSCard, then that means
            // that the cards haven't been retrieved yet. That's
            // ok, just skip it.
            if (uid in self._childContacts) {
              let edsContact = self._childContacts[uid];
              if (edsContact.isMailList) {
                listRemoval.push(edsContact);
              }
              else {
                cardRemoval.push(edsContact);
              }
            } else {
              WARN("No card with uid " + uid + " found in directory " + self.URI);
            }
          }

          if (cardRemoval.length > 0)
            self._disappearCards(cardRemoval);

          if (listRemoval.length > 0)
            self._disappearDirectories(listRemoval);
        })
      );
          
      // Start the view
      let error = new glib.GError.ptr();
      ebook.e_book_client_view_start(self._edsBookClientView, error.address());
      if (!error.isNull()) {
        ERROR("Could not start directory view for " + this.URI + ": "
              + error.contents.message.readString());
        glib.g_error_free(error);
        return;
      }

      LOG("Directory view for " + self.URI + " was successfully started!");
    });
  },

  _createCard: function AbEDSD__createCard(aContact) {
    let cstr = ctypes.cast(ebook.e_contact_get_const(aContact,
                                                     ebook.EContactFieldEnums.E_CONTACT_UID),
                           glib.gchar.ptr);
    if (cstr.isNull()) {
      WARN("Cannot create card for contact with no UID");
      return;
    }

    let uid = cstr.readString();

    if (uid in this._childContacts) {
      LOG("Card with UID " + uid + " already exists in directory " + this.URI);
      return;
    }

    LOG("Creating card for contact with UID=" + uid + " in directory " + this.URI);

    let card = new nsAbEDSCard(this, aContact);

    this._childCards[uid] = card;
    this._childContacts[uid] = card;

    MailServices.ab.notifyDirectoryItemAdded(this, card);
  },

  _createMailList: function AbEDSD__createMailList(aContact) {
    let cstr = ctypes.cast(ebook.e_contact_get_const(aContact,
                                                     ebook.EContactFieldEnums.E_CONTACT_UID),
                           glib.gchar.ptr);
    if (cstr.isNull()) {
      WARN("Cannot create mailing list for contact with no UID");
      return;
    }

    let uid = cstr.readString();

    if (uid in this._childContacts) {
      LOG("Mail list with UID " + uid + " already exists in directory " + this.URI);
      return;
    }

    LOG("Creating mailing list for contact with UID=" + uid + " in directory " + this.URI);

    let uri = this.URI + "/MailList-" + ++gMailListCount;

    let mailingList = MailServices.ab.getDirectory(uri).wrappedJSObject;

    mailingList.edsContact = aContact;
    mailingList.edsClient = this._edsClient;

    this._childNodes[uri] = mailingList;
    this._childContacts[uid] = mailingList;
    MailServices.ab.notifyDirectoryItemAdded(this, mailingList);
  },

  _initSupportedFields: function AbEDSD__initSupportedFields() {
    if (!this._edsClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    LOG("Attempting to init supported fields for directory " + this.URI);

    let self = this;
    eds.e_client_get_backend_property(this._edsClient, "supported-fields", null,
                                      function(aObject, aResult) {
      try {
        LOG("Supported fields for " + self.URI + " received");

        let client = ctypes.cast(aObject, eds.EClient.ptr);
        var prop = new glib.gchar.ptr();
        var error = new glib.GError.ptr();

        if (!eds.e_client_get_backend_property_finish(client, aResult,
                                                      prop.address(),
                                                      error.address())) {
          ERROR("Problem retrieving supported fields for " + self.URI + ": " +
                error.contents.message.readString());
          return;
        }

        var fieldString = prop.readString();
      } finally {
        if (error && !error.isNull()) {
          glib.g_error_free(error);
        }
        if (prop && !prop.isNull()) {
          glib.g_free(prop);
        }
      }

      let fieldArray = fieldString.split(',');
      fieldArray = fieldArray.map(function(elem) {
        return ebook.EContactFieldEnums.toEnum(ebook.e_contact_field_id(elem));
      });

      LOG("Supported fields from EDS:\n" + fieldArray.join("\n"));

      // Iterate through the EList, grab the field name, pop it into
      // an Array, and strap it to the nsAbEDSDirectory.

      let fields = [];
      let phoneTypes = [];
      let iMTypes = [];
      let unsupported = fieldArray.filter(function(field) {

        let tbFields = gTbFieldsFromEDSField[field];
        if (tbFields && tbFields.length > 0) {
          tbFields.forEach(function(tbField) {
            fields.push(tbField);
          });
          return false;
        }

        let phoneType = gTbFieldFromEDSPhoneType[field];
        if (phoneType) {
          phoneTypes.push(phoneType);
          return false;
        }

        let iMType = gTbFieldFromEDSIMType[field];
        if (iMType) {
          iMTypes.push(iMType);
          return false;
        }

        return true;
      });

      LOG("Supported Thunderbird fields:\n" + fields.join("\n"));
      LOG("Supported phone types:\n" + phoneTypes.join("\n"));
      LOG("Supported IM types:\n" + iMTypes.join("\n"));
      //if (unsupported.length > 0) {
      //  WARN("These EDS fields are currently not supported:\n" + unsupported.join("\n"));
      //}
      self.__supportedFields = fields;
      self.__supportedPhoneTypes = phoneTypes;
      self.__supportedIMTypes = iMTypes;
    });
  },

  _doOpen: function AbEDSD__doOpen() {
    if (!this._edsSource) {
      throw Cr.NS_ERROR_FAILURE;
    }

    if (this._openInProgress) {
      return;
    }

    LOG("Opening directory " + this.URI);

    let self = this;

    AuthHelper.openAndAuthESource(this._edsSource, function(aClient, aCred) {
      if (self._open) {
        return glib.FALSE;
      }

      LOG("Directory " + self.URI + " requires authorization");

      /* Ok, we need to authenticate.  Let's get the important pieces:
       * 1)  The auth-domain
       * 2)  The component name
       * 3)  The username
       * 4)  The password
       *
       * 4 *might* be in the LoginManager, and if so, we'll try that.
       * Failing that, we'll prompt the user.
       */

      let source = eds.e_client_get_source(aClient);
      let authMethod = eds.e_source_get_property(source, "auth");
      LOG("The authorization mechanism for this directory is: " + authMethod);

      // Maybe we don't even need to authenticate.
      if (!authMethod || authMethod == "none") {
        LOG("No need to authenticate for address book named " + self.dirName);
        self._open = true;
        return glib.FALSE;
      }

      let username = null;

      switch(authMethod) {
        case "ldap/simple-binddn":
          username = eds.e_source_get_property(source, "binddn");
          break;
        case "plain/password":
          username = eds.e_source_get_property(source, "user");
          if (!username)
            username = eds.e_source_get_property(source, "username");
          break;
        default:
          username = eds.e_source_get_property(source, "email_addr");
          break;
      }

      if (!username)
        username = "";

      LOG("Retrieving any stored passwords for this address book...");
      let password = null;
      let uri = eds.e_client_get_uri(aClient);
      let strippedUri = stripUriParameters(uri);
      let authDomain = eds.e_source_get_property(source, "auth-domain");
      let componentName = authDomain ? authDomain : eds.E_CREDENTIALS_AUTH_DOMAIN_ADDRESSBOOK;

      // If these credentials haven't been used before, let's use the LoginManager
      // to try to find the password.
      let logins = Services.logins.findLogins({}, kExtensionChromeID, null, strippedUri);
      if (eds.e_credentials_peek(aCred, eds.E_CREDENTIALS_KEY_PROMPT_FLAGS) ==
          eds.E_CREDENTIALS_USED) {
        // We've used these credentials before, and since we're here, they were
        // no good.  Let's forget these credentials.
        for (let i = 0; i < logins.length; i++) {
          let login = logins[i];
          if (login.username == username) {
            LOG("Removing stored login for username " + username);
            Services.logins.removeLogin(login);
            break;
          }
        }
      } else {
        // Ok, let's see if the password for this username is in
        // the LoginManager
        for (let i = 0; i < logins.length; i++) {
          let login = logins[i];
          if (login.username == username) {
            LOG("Found login for username " + username);
            password = login.password;
            break;
          }
        }
      }

      if (!password) {
        // Prompt for the username and password
        let title = _("AuthenticationTitle");
        let reason = eds.e_credentials_peek(aCred,
                                            eds.E_CREDENTIALS_KEY_PROMPT_REASON);
        var body;
        if (reason)
          body = _("AuthenticationBodyReason", [self.dirName, reason]);
        else
          body = _("AuthenticationBodyBasic", [self.dirName]);

        let checkboxBody = _("AuthenticationRememberPassword");
        let userObj = {value: username};
        let passwordObj = {value: ""};
        let checkObj = {value: true};

        let win = Services.wm.getMostRecentWindow("mail:addressbook");
        if (!win)
          win = Services.wm.getMostRecentWindow("mail:3pane");

        let answer = Services.prompt.promptUsernameAndPassword(win, title, body,
                                                               userObj, passwordObj,
                                                               checkboxBody, checkObj);
        username = userObj.value;
        password = passwordObj.value;

        if (checkObj.value && username && password) {
          let nsLoginInfo = Components.Constructor("@mozilla.org/login-manager/loginInfo;1",
                                                   Ci.nsILoginInfo,
                                                   "init");
          // Try to store password for next time
          let loginInfo = new nsLoginInfo(kExtensionChromeID, null, strippedUri, username,
                                          password, "", "");

          Services.logins.addLogin(loginInfo);
        }
      }

      eds.e_credentials_set(aCred, eds.E_CREDENTIALS_KEY_USERNAME,
                            username);
      eds.e_credentials_set(aCred, eds.E_CREDENTIALS_KEY_PASSWORD,
                            password);
      eds.e_credentials_set(aCred, eds.E_CREDENTIALS_KEY_AUTH_METHOD,
                            authMethod);
      //eds.e_credentials_set(aCred, eds.E_CREDENTIALS_KEY_AUTH_DOMAIN,
      //                      authDomain);
      eds.e_credentials_set(aCred, eds.E_CREDENTIALS_KEY_PROMPT_KEY,
                            uri);

      return glib.TRUE;

    }, function(aClient, aError) {
      self._openInProgress = false;

      if (aError) {
        // Alert the user that there was a problem
        ERROR("There was a problem opening the directory " + self.URI + ": " + aError);
        Services.prompt.alert(null, _("ProblemOpeningEClientDialogTitle"),
                              _("ProblemOpeningEClient", [self.dirName, aError]));
        return;
      }

      LOG("Opened directory with URI: " + self.URI);
 
      self.__edsClient = ctypes.cast(gobject.g_object_ref(aClient),
                                     eds.EClient.ptr);

      // TODO: Connect auth-handler to "authorize" signal directly,
      // in case we're disconnected and need to reauthenticate.

      self._initSupportedFields();
      self._initCards();
      self._open = true;
    }, this.URI);

    this._openInProgress = true;
  },

  // nsIAbEDSDirectory

  /* Close down the nsAbEDSDirectory.  Stop any async operations.
   */
  shutdown: function AbEDSD_shutdown() {
    if (this._edsBookClientView && !this._edsBookClientView.isNull()) {
      this._view_sigids.forEach(function(id) {
        gobject.g_signal_handler_disconnect(this._edsBookClientView, id);
      }, this);
    }

    // Dispose of all child cards and mailing lists.
    for (let card in fixIterator(this.childCards)) {
      if (!(card instanceof Ci.nsIAbEDSCard)) {
        continue;
      }
      card.dispose();
    }
    for (let list in fixIterator(this.childNodes)) {
      if (!(list instanceof Ci.nsIAbEDSMailingList)) {
        continue;
      }
      list.dispose();
    }

    // free all resources
    ["__edsClient",
     "__edsSource",
     "_edsBookClientView"].forEach(function(aKey) {
       let aPtr = this[aKey];
       if (aPtr && !aPtr.isNull()) {
         gobject.g_object_unref(aPtr);
       }
       this[aKey] = null;
    }, this);

    this._open = false;
  },

  /* Returns the supported fields for this nsAbEDSDirectory in the
   * form of EContactFields. See the EContact documentation for
   * further details.
   */
  getSupportedFields: function AbEDSD_getSupportedFields(aCount) {
    if (!this._supportedFields) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }
    aCount.value = this._supportedFields.length;
    return this._supportedFields;
  },

  getSupportedPhoneTypes: function AbEDSD_getSupportedPhoneTypes(aCount) {
    if (!this._supportedPhoneTypes) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }
    aCount.value = this._supportedPhoneTypes.length;
    return this._supportedPhoneTypes;
  },

  getSupportedIMTypes: function AbEDSD_getSupportedIMTypes(aCount) {
    if (!this._supportedIMTypes) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }
    aCount.value = this._supportedIMTypes.length;
    return this._supportedIMTypes;
  },

  // nsIAbDirectory

  /* The following is some boiler-plate nsIAbDirectory implementation
   * work.
   */
  get propertiesChromeURI() {
    return kPropertiesChromeURI;
  },

  get dirName() {
    if (!this._edsSource) {
      throw Cr.NS_ERROR_FAILURE;
    }

    return eds.e_source_get_display_name(this._edsSource);
  },

  set dirName(aDirName) {
    if (!this._edsSource) {
      throw Cr.NS_ERROR_FAILURE;
    }

    let oldName = this.dirName;
    eds.e_source_set_display_name(this._edsSource, aDirName);

    if (oldName != aDirName) {
      MailServices.ab.notifyItemPropertyChanged("DirName", oldName, aDirName);
    }
  },

  get dirType() {
    return 0;
  },

  get fileName() {
    return null;
  },

  get URI() {
    return this._uri;
  },

  get position() {
    return 1;
  },

  get lastModifiedData() {
    return 0;
  },

  set lastModifiedData(aLastModified) {},

  get isMailList() {
    return false;
  },

  set isMailList(val) {},

  get childNodes() {
    if (this.isQuery) {
      return CreateSimpleObjectEnumerator({});
    }

    if (!this._open) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    return CreateSimpleObjectEnumerator(this._childNodes);
  },

  get childCards() {
    if (this.isQuery) {
      this.startSearch();
      return CreateSimpleEnumerator(this._searchCache);
    }

    if (!this._open) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    return CreateSimpleObjectEnumerator(this._childCards);
  },

  get isQuery() {
    return !!this._query;
  },

  /* Called automatically by nsAbManager to boot up the nsIAbDirectory.
   * @param aURI the URI associated with this nsIAbDirectory
   */
  init: function(aURI) {
    if (this._initialized)
      return;

    LOG("Initializing directory with URI: " + aURI);

    // Chop off any queries, and just take the root URI
    let queryPoint = aURI.indexOf("?");
    if (queryPoint != -1) {
      this._query = aURI.substr(queryPoint + 1);
      aURI = aURI.substr(0, queryPoint);
    }

    if (gAbLookup[aURI]) {
      if (!this.isQuery) {
        ERROR("URI " + aURI + " already exists");
        throw Cr.NS_ERROR_UNEXPECTED;
      }
      this._proxy = gAbLookup[aURI];
      return;
    } else {
      gAbLookup[aURI] = this;
    }

    this._uri = aURI;

    this.__edsSourceUid = aURI.substring(kDirScheme.length);

    // Get the ESource for this address book
    this.__edsSource = ESourceProvider.sourceForUid(this._edsSourceUid);

    this._doOpen();
    this._initialized = true;
  },

  deleteDirectory: function AbEDSD_deleteDirectory(aDirectory) {
    if (!this._edsBookClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (this.isQuery) {
      throw Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    if (!(aDirectory instanceof Ci.nsIAbEDSMailingList)) {
      WARN("Could not delete mailing list - not instance of nsIAbEDSMailingList");
      throw Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    if (!this._childNodes[aDirectory.URI]) {
      WARN("Cannot delete mailing list " + aDirectory.URI + " that doesn't"
           + "belong to directory " + this.URI);
      throw Cr.NS_ERROR_FAILURE;
    }

    LOG("Requesting deletion of mailing list " + aDirectory.URI
        + " from directory " + this.URI);
    let aDirectory = this._childNodes[aDirectory.URI];

    let self = this;
    ebook.e_book_client_remove_contact(this._edsBookClient,
                                       aDirectory.edsContact,
                                       null,
                                       function(aObject, aRes) {
      self._deleteContactFinish(aObject, aRes, aDirectory.URI);
    });
  },

  hasCard: function AbEDSD_hasCard(aCard) {
    if (this.isQuery) {
      throw Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    if (!this._open) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (this._childCards[aCard.localId]) {
      return true;
    }

    return false;
  },

  hasDirectory: function AbEDSD_hasDirectory(aDirectory) {
    return false;
  },

  addCard: function AbEDSD_addCard(aCard) {
    if (!this._edsBookClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (this.isQuery) {
      throw Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    if (aCard.isMailList) {
      ERROR("We don't handle adding a mailing list yet");
      throw Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    try {
      LOG("Adding a card to directory " + this.URI);

      // 1) Create an empty EContact
      var contact = ebook.e_contact_new();

      // 2) Populate EContact with the properties of the card
      //    passed to this function
      var tmpCard = new nsAbEDSCard(this, contact);
      tmpCard.copy(aCard);
      tmpCard.flush();

      // 3) Add EContact to address book
      var error = new glib.GError.ptr;
      var uidc = new glib.gchar.ptr;
      ebook.e_book_client_add_contact_sync(this._edsBookClient, contact,
                                           uidc.address(),
                                           null, error.address());

      if (!error.isNull()) {
        ERROR("Could not add contact to directory " + this.URI + ": "
              + error.contents.message.readString());
        throw Cr.NS_ERROR_FAILURE;
      }

      if (uidc.isNull()) {
        ERROR("Null UID");
        throw Cr.NS_ERROR_FAILURE;
      }

      let uid = uidc.readString();

      // At the moment, this check always evaluates true as we don't process the
      // "objects-added" signal until we return to the mainloop. This is odd, as
      // sync API's in gdbus run a recursive main loop, which must mean that the
      // EDS API is not really synchronous. For now, create the new card here
      if (!this._childCards[uid]) {
        ebook.e_contact_set(contact, ebook.EContactFieldEnums.E_CONTACT_UID,
                            uidc);

        this._createCard(contact);
      }

      return this._childCards[uid];
    } finally {
      if (contact && !contact.isNull()) {
        gobject.g_object_unref(contact);
      }
      if (error && !error.isNull()) {
        glib.g_error_free(error);
      }
      if (uidc && !uidc.isNull()) {
        glib.g_free(uidc);
      }
      if (tmpCard) {
        tmpCard.dispose();
      }
    }
  },

  modifyCard: function AbEDSD_modifyCard(aModifiedCard) {
    if (!this._open) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (!(aModifiedCard instanceof Ci.nsIAbEDSCard)) {
      throw Cr.NS_ERROR_INVALID_ARG;
    }

    // We need to do this because the card passed to us might be
    // wrapped by xpconnect, in which case we wouldn't be able to
    // access its commit method
    let child = this._childCards[aModifiedCard.localId];
    if (!child) {
      throw Cr.NS_ERROR_FAILURE;
    }

    child.commit();
  },

  deleteCards: function AbEDSD_deleteCards(aCards) {
    if (!this._edsBookClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (this.isQuery) {
      throw Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    let cards = [];
    for (let i = 0; i < aCards.length; i++) {
      let card = aCards.queryElementAt(i, Ci.nsIAbEDSCard);

      if (!this._childCards[card.localId]) {
      WARN("Cannot delete card " + card.localId + " that doesn't"
           + "belong to directory " + this.URI);
        throw Cr.NS_ERROR_UNEXPECTED;
      }

      cards.push(this._childCards[card.localId]);
    }

    cards.forEach(function(card) {
      let self = this;
      ebook.e_book_client_remove_contact(this._edsBookClient,
                                         card.edsContact, null,
                                         function(aObject, aRes) {
        self._deleteContactFinish(aObject, aRes, card.localId);
      });
    }, this);
  },

  dropCard: function AbEDSD_dropCard(aCard, aNeedToCopyCard) {
    let newCard = this.addCard(aCard);
  },

  // XXX: Can we get this from EDS?
  // FIXME: Should probably look at mail.enable_autocomplete
  useForAutocomplete: function AbEDSD_useForAutocomplete(aIdentity) {
    return true;
  },

  // XXX: Are there any EDS addressbook implementations that don't support this>
  get supportsMailingLists() {
    return true;
  },

  get addressLists() {
    return [];
  },

  set addressLists(val) {},

  addMailList: function AbEDSD_addMailList(aList) {
    if (!this._edsBookClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    if (this.isQuery) {
      throw Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    try {
      LOG("Trying to add mailing list to directory " + this.URI);

      var contact = ebook.e_contact_new();
      ebook.e_contact_set(contact, ebook.EContactFieldEnums.E_CONTACT_IS_LIST,
                          glib.GINT_TO_POINTER(glib.TRUE));

      var tmpList = new nsAbEDSMailingList(this, contact);

      tmpList.copyMailList(aList);
      tmpList.flush();

      var error = new glib.GError.ptr();
      var uidc = new glib.gchar.ptr();
      ebook.e_book_client_add_contact_sync(this._edsBookClient, contact,
                                           uidc.address(),
                                           null, error.address());

      if (!error.isNull()) {
        ERROR("Could not add mailing list to directory " + this.URI + ": "
              + error.contents.message.readString());
        throw Cr.NS_ERROR_FAILURE;
      }

      if (uidc.isNull()) {
        ERROR("Null UID");
        throw Cr.NS_ERROR_FAILURE;
      }

      let uid = uidc.readString();

      if (!(uid in this._childContacts)) {
        ebook.e_contact_set(contact,
                            ebook.EContactFieldEnums.E_CONTACT_UID,
                            uidc);

        this._createMailList(contact);
      }

      return this._childContacts[uid];
    } finally {
      if (contact && !contact.isNull()) {
        gobject.g_object_unref(contact);
      }
      if (error && !error.isNull()) {
        glib.g_error_free(error);
      }
      if (uidc && !uidc.isNull()) {
        glib.g_free(uidc);
      }
      if (tmpList) {
        tmpList.dispose();
      }
    }
  },

  get listNickName() {
    return null;
  },

  set listNickName(val) {},

  get description() {
    return null;
  },

  set description(val) {},

  editMailListToDatabase: function AbEDSD_editMailListToDatabase(aListCard) {
    throw Cr.NS_ERROR_UNEXPECTED;
  },

  copyMailList: function AbEDSD_copyMailList(aSrcList) {
    throw Cr.NS_ERROR_UNEXPECTED;
  },

  createNewDirectory: function AbEDSD_createNewDirectory(aDirName, aURI, aType,
                                                         aPrefName) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  createDirectoryByURI: function AbEDSD_createDirectoryByURI(aDisplayName,
                                                             aURI) {
    throw Cr.NS_ERROR_NOT_IMPLEMENTED;
  },

  get dirPrefId() {
    // FIXME: Should be directory specific. But, is it actually used?
    return kDirPrefId;
  },

  set dirPrefId(val) {},

  getIntValue: function AbEDSD_getIntValue(aName, aDefaultValue){
    return aDefaultValue;
  },

  getBoolValue: function AbEDSD_getBoolValue(aName, aDefaultValue) {
    return aDefaultValue;
  },

  getStringValue: function AbEDSD_getStringValue(aName, aDefaultValue) {
    return aDefaultValue;
  },

  getLocalizedStringValue: function AbEDSD_getLocalizedStringValue(aName, aDefaultValue) {
    return aDefaultValue;
  },

  setIntValue: function AbEDSD_setIntValue(aName, aValue) {},
  setBoolValue: function AbEDSD_setBoolValue(aName, aValue) {},
  setStringValue: function AbEDSD_setStringValue(aName, aValue) {},
  setLocalizedStringValue: function AbEDSD_setLocalizedStringValue(aName, aValue) {},

  // nsIAbCollection

  get readOnly() {
    if (!this._edsClient) {
      throw Cr.NS_ERROR_NOT_INITIALIZED;
    }

    return eds.e_client_is_readonly(this._edsClient);
  },

  get isRemote() {
    // XXX: Can we get this from EDS
    return false;
  },

  get isSecure() {
    // XXX: Can we get this from EDS
    return false;
  },

  cardForEmailAddress: function AbEDSD_cardForEmailAddress(aEmailAddress) {
    // FIXME: We should cache the results of this
    var cards = this.childCards;
    LOG("Checking for card with email address " + aEmailAddress
        + " in directory " + this.URI);
    while(cards.hasMoreElements()) {
      let card = cards.getNext();
      if (card.hasEmailAddress(aEmailAddress))
        return card; 
    }
    return null;
  },

  getCardFromProperty: function AbEDSD_getCardFromProperty(aProperty, aValue,
                                                           aCaseSensitive) {

    if (!aCaseSensitive)
      aValue = aValue.toLowerCase();

    for each (let card in fixIterator(this.childCards)) {
      let property = card.getProperty(aProperty)
      if (!aCaseSensitive)
        property = property.toLowerCase();
      if (property == aValue)
        return card;
    }
    return null;
  },

  getCardsFromProperty: function AbEDSD_getCardsFromProperty(aProperty, aValue,
                                                             aCaseSensitive) {
    let result = []
    if (!aCaseSensitive)
      aValue = aValue.toLowerCase();

    for each (let card in fixIterator(this.childCards)) {
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

  generateName: function AbEDSD_generateName(aGenerateFormat, aBundle) {
    return this.dirName;
  },

  // nsIAbDirectorySearch

  startSearch: function AbEDSD_startSearch() {
    if (!this.isQuery) {
      return Cr.NS_ERROR_NOT_IMPLEMENTED;
    }

    let args = Cc["@mozilla.org/addressbook/directory/query-arguments;1"]
               .createInstance(Ci.nsIAbDirectoryQueryArguments);

    let expression = MailServices.ab.convertQueryStringToExpression(this._query);
    args.expression = expression;
    args.querySubDirectories = false;

    let queryProxy = Cc["@mozilla.org/addressbook/directory-query/proxy;1"]
                     .createInstance(Ci.nsIAbDirectoryQueryProxy);
    queryProxy.initiate();
    queryProxy.doQuery(this.proxy, args, this, -1, 0);

 },

  stopSearch: function AbEDSD_stopSearch() {},

  // nsIAbDirSearchListener

  onSearchFinished: function AbEDSD_onSearchFinished(aResult, aErrorMsg) {},

  onSearchFoundCard: function AbEDSD_onSearchFoundCard(aCard) {
    this._searchCache.push(aCard);
  }
}

function stripUriParameters(aURI) {
  try {
    var euri = eds.e_uri_new(aURI);
    return eds.e_uri_to_string(euri, glib.FALSE);
  } finally { if (euri && !euri.isNull()) eds.e_uri_free(euri); }
}

/* So nsAbEDSTransformer is my way of avoiding having a lot of
 * if (this.isMailList) clauses within my nsAbEDSDirectory.  The
 * way TB defines mailing lists is really quite unfortunate, and
 * can result in some pretty horrific code (see the OSX address
 * book implementation, for example).  The transformer is what
 * is instantiated by the nsIAbManager with getDirectory.  On
 * the init call, the URI is analyzed to determine whether or
 * not a mailing list is being requested.  If we're requesting
 * a mailing list, the nsAbEDSTransformer "transforms" itself
 * to become an nsAbEDSMailingList.  Otherwise, it "transforms"
 * itself to become an nsAbEDSDirectory.
 */
function nsAbEDSTransformer() {}

nsAbEDSTransformer.prototype = {
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIAbDirectory]),

  init: function (aURI) {
    // Determine if we're creating a mailing list
    // or a regular directory.
    if (aURI.indexOf("MailList-") != -1) {
      this.__proto__ = nsAbEDSMailingList.prototype;
      this.constructor = nsAbEDSMailingList;
    } else {
      this.__proto__ = nsAbEDSDirectory.prototype;
      this.constructor = nsAbEDSDirectory;
    }

    this.constructor();
    this.init(aURI);
  },
}
