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

var EXPORTED_SYMBOLS = [ "AuthHelper" ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://gre/modules/XPCOMUtils.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");
Cu.import("resource://edsintegration/libs/gio.jsm");
Cu.import("resource://edsintegration/libs/eds.jsm");
Cu.import("resource://edsintegration/libs/ebook.jsm");

addLogger(this);

var AuthHelper = {
  openAndAuthESource: function AH_openAndAuthESource(aSource,
                                                     aAuthHandler,
                                                     aCallback,
                                                     aURI) {
    if (!aSource || aSource.isNull()) {
      ERROR("Tried to openAndAuth an ESource that was null for URI " + aURI + "!");
      throw Cr.NS_ERROR_INVALID_ARG;
    }

    let error = new glib.GError.ptr();
    var client = ctypes.cast(ebook.e_book_client_new(aSource, error.address()),
                             eds.EClient.ptr);
    if (!error.isNull()) {
      ERROR("Could not create EBookClient for URI " + aURI + ": " 
            + error.contents.message.readString());
      glib.g_error_free(error);
      throw Cr.NS_ERROR_FAILURE;
    }

    var usedCreds;
    var openFinished = false;
    var openedCbError;
    var authSigId;
    var openedSigId;

    function finishOrRetryOpen(aError) {
      if (aError && !aError.isNull()) {
        if (glib.g_error_matches(aError, eds.e_client_error_quark(),
                                 eds.EClientErrorEnums.E_CLIENT_ERROR_AUTHENTICATION_FAILED)) {
          if (usedCreds && !usedCreds.isNull()) {
            // TODO: Password remembering? Forgetting?
            eds.e_credentials_set(usedCreds, eds.E_CREDENTIALS_KEY_PROMPT_FLAGS,
                                  eds.E_CREDENTIALS_USED);
            eds.e_credentials_set(usedCreds, eds.E_CREDENTIALS_KEY_PROMPT_REASON,
                                  aError.contents.message.readString());
            LOG("Old credentials have been used.");
          }
          LOG("Calling LibEClient.processAuth");
          eds.e_client_process_authentication(client, usedCreds);
          return;
        } else if (glib.g_error_matches(aError, eds.e_client_error_quark(),
                                        eds.EClientErrorEnums.E_CLIENT_ERROR_BUSY)) {
          let timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
          timer.initWithCallback(function(aTimer) {
            AuthHelper.openAndAuthESource(aSource, aAuthHandler, aCallback, aURI);
          }, 500, Ci.nsITimer.TYPE_ONE_SHOT);
        } else {
          LOG("Calling asyncCb");
          aCallback(client, aError.contents.message.readString());
        }
      } else {
        LOG("Calling openNewDone");
        aCallback(client);
      }

      if (usedCreds && !usedCreds.isNull()) {
        eds.e_credentials_free(usedCreds);
      }
      if (authSigId) {
        gobject.g_signal_handler_disconnect(client, authSigId);
      }
      if (openedSigId) {
        gobject.g_signal_handler_disconnect(client, openedSigId);
      }
    }

    // Register the authentication callback if one exists
    if (aAuthHandler && eds.ABI < 17) {
      authSigId = gobject.g_signal_connect(client, "authenticate",
                                           function(aClient, aCred) {
        LOG("Within openNewAuthCb");

        if (!aCred || aCred.isNull()) {
          ERROR("The ECredentials passed to openNewAuthCb was null.");
          return glib.FALSE;
        }

        if (usedCreds) {
          let reason = eds.e_credentials_peek(usedCreds,
                                              eds.E_CREDENTIALS_KEY_PROMPT_REASON);
          if (reason) {
            eds.e_credentials_set(aCred, eds.E_CREDENTIALS_KEY_PROMPT_TEXT, null);
            eds.e_credentials_set(aCred, eds.E_CREDENTIALS_KEY_PROMPT_REASON, reason);
          }
        }

        let handled = aAuthHandler(aClient, aCred);

        if (handled ) {
          if (usedCreds) {
            eds.e_credentials_free(usedCreds);
          }
          usedCreds = eds.e_credentials_new_clone(aCred);
        }

        return handled;
      });
    }

    openedSigId = gobject.g_signal_connect(client, "opened",
                                           function(aClient, aError) {
      if (!openFinished) {
        if (!aError.isNull()) {
          openedCbError = glib.g_error_copy(aError);
        }
      } else { 
        LOG("Calling finishOrRetryOpen from openedCb");
        finishOrRetryOpen(aError);
      }
      LOG("OpenedCb exited");
    });

    eds.e_client_open(client, false, null,
                      function(aObject, aRes) {
      LOG("Entered openNewAsyncCb");

      openFinished = true;

      let client = ctypes.cast(aObject, eds.EClient.ptr);
      let error = new glib.GError.ptr();

      if (!eds.e_client_open_finish(client, aRes, error.address())) {
        LOG("Calling finishOrRetryOpen from openNewAsyncCb");
        finishOrRetryOpen(error);
        glib.g_error_free(error);
        return;
      }

      if (openedCbError) {
        finishOrRetryOpen(openedCbError);
        glib.g_error_free(openedCbError);
        openedCbError = null;
        return;
      }

      if (eds.e_client_is_opened(client)) {
        LOG("Huzzah!  Apparently an EClient has been opened (uri: " + aURI + ")");
        finishOrRetryOpen();
      }
    });
  }
}
