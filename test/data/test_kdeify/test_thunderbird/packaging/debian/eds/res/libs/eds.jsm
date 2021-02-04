/* -*- Mode: javascript; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
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
 * The Original Code is ubufox.
 *
 * The Initial Developer of the Original Code is
 * Canonical Ltd.
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Chris Coulson <chris.coulson@canonical.com>
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

const { utils: Cu } = Components;

var EXPORTED_SYMBOLS = [ "eds" ];

const EDS_LIBNAME = "edataserver-1.2";
const EDS_ABIS = [ 17, 15 ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gio.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");

function getString(aWrappedFunc) {
  let res = aWrappedFunc.apply(null, Array.prototype.slice.call(arguments, 1));
  return res.isNull() ? null : res.readString();
}

function getOwnedString(aWrappedFunc) {
  let res;
  try {
    res = aWrappedFunc.apply(null, Array.prototype.slice.call(arguments, 1));
    return res.isNull() ? null : res.readString();
  } finally { glib.g_free(res); }
}

function eds_defines(lib) {
  // Enums
  CTypesUtils.defineEnums(this, "EClientError", 0, [
    "E_CLIENT_ERROR_INVALID_ARG",
    "E_CLIENT_ERROR_BUSY",
    "E_CLIENT_ERROR_SOURCE_NOT_LOADED",
    "E_CLIENT_ERROR_SOURCE_ALREADY_LOADED",
    "E_CLIENT_ERROR_AUTHENTICATION_FAILED",
    "E_CLIENT_ERROR_AUTHENTICATION_REQUIRED",
    "E_CLIENT_ERROR_REPOSITORY_OFFLINE",
    "E_CLIENT_ERROR_OFFLINE_UNAVAILABLE",
    "E_CLIENT_ERROR_PERMISSION_DENIED",
    "E_CLIENT_ERROR_CANCELLED",
    "E_CLIENT_ERROR_COULD_NOT_CANCEL",
    "E_CLIENT_ERROR_NOT_SUPPORTED",
    "E_CLIENT_ERROR_TLS_NOT_AVAILABLE",
    "E_CLIENT_ERROR_UNSUPPORTED_AUTHENTICATION_METHOD",
    "E_CLIENT_ERROR_SEARCH_SIZE_LIMIT_EXCEEDED",
    "E_CLIENT_ERROR_SEARCH_TIME_LIMIT_EXCEEDED",
    "E_CLIENT_ERROR_INVALID_QUERY",
    "E_CLIENT_ERROR_QUERY_REFUSED",
    "E_CLIENT_ERROR_DBUS_ERROR",
    "E_CLIENT_ERROR_OTHER_ERROR",
    "E_CLIENT_ERROR_NOT_OPENED"
  ]);

  // Constants
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_USERNAME", "username");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_PASSWORD", "password");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_AUTH_METHOD",
                           "auth-method");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_PROMPT_TITLE",
                           "prompt-title");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_PROMPT_TEXT",
                           "prompt-text");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_PROMPT_REASON",
                           "prompt-reason");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_PROMPT_KEY", "prompt-key");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_PROMPT_FLAGS",
                           "prompt-flags");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_KEY_FOREIGN_REQUEST",
                           "foreign-request");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_AUTH_DOMAIN_ADDRESSBOOK",
                           "Addressbook");
  CTypesUtils.defineSimple(this, "E_CREDENTIALS_USED", "used");

  CTypesUtils.defineSimple(this, "E_SOURCE_EXTENSION_ADDRESS_BOOK",
                           "Address Book");

  // Types
  CTypesUtils.defineSimple(this, "ESourceList",
                           ctypes.StructType("ESourceList"));
  CTypesUtils.defineSimple(this, "ESourceGroup",
                           ctypes.StructType("ESourceGroup"));
  CTypesUtils.defineSimple(this, "ESource", ctypes.StructType("ESource"));
  CTypesUtils.defineSimple(this, "EClient", ctypes.StructType("EClient"));
  CTypesUtils.defineSimple(this, "ECredentials",
                           ctypes.StructType("ECredentials"));
  CTypesUtils.defineSimple(this, "EList", ctypes.StructType("EList"));
  CTypesUtils.defineSimple(this, "EIterator", ctypes.StructType("EIterator"));
  CTypesUtils.defineSimple(this, "EUri", ctypes.StructType("EUri"));
  CTypesUtils.defineSimple(this, "ESourceRegistry",
                           ctypes.StructType("ESourceRegistry"));

  // Templates

  // Functions
  lib.lazy_bind("e_client_error_quark", glib.GQuark);
  lib.lazy_bind_with_wrapper("e_client_get_backend_property", function(aWrappee,
                                                                       aClient,
                                                                       aPropName,
                                                                       aCancellable,
                                                                       aCallback) {
    var ccw = CTypesUtils.wrapCallback(aCallback,
                                       {type: gio.GAsyncReadyCallback,
                                        root: true, singleshot: true});

    try {
      aWrappee(aClient, aPropName, aCancellable, ccw, null);
    } catch(e) {
      CTypesUtils.unrootCallback(aCallback);
      throw e;
    }
  }, ctypes.void_t, [this.EClient.ptr, glib.gchar.ptr, gio.GCancellable.ptr,
                     gio.GAsyncReadyCallback, glib.gpointer]);
  lib.lazy_bind("e_client_get_backend_property_finish", glib.gboolean,
                [this.EClient.ptr, gio.GAsyncResult.ptr, glib.gchar.ptr.ptr,
                glib.GError.ptr.ptr]);
  lib.lazy_bind("e_client_get_source", this.ESource.ptr, [this.EClient.ptr]);
  lib.lazy_bind("e_client_is_opened", glib.gboolean, [this.EClient.ptr]);
  lib.lazy_bind("e_client_is_readonly", glib.gboolean, [this.EClient.ptr]);
  lib.lazy_bind_with_wrapper("e_client_open", function(aWrappee, aClient,
                                                       aOnlyIfExists,
                                                       aCancellable,
                                                       aCallback) {
    var ccw = CTypesUtils.wrapCallback(aCallback,
                                       {type: gio.GAsyncReadyCallback,
                                        root: true, singleshot: true});

    try {
      aWrappee(aClient, aOnlyIfExists, aCancellable, ccw, null);
    } catch(e) {
      CTypesUtils.unrootCallback(aCallback);
      throw e;
    }
  }, ctypes.void_t, [this.EClient.ptr, glib.gboolean, gio.GCancellable.ptr,
                     gio.GAsyncReadyCallback, glib.gpointer]);
  lib.lazy_bind("e_client_open_finish", glib.gboolean, [this.EClient.ptr,
                gio.GAsyncResult.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind("e_client_remove_sync", glib.gboolean, [this.EClient.ptr,
                gio.GCancellable.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind("e_credentials_free", ctypes.void_t, [this.ECredentials.ptr]);
  lib.lazy_bind("e_credentials_new", this.ECredentials.ptr);
  lib.lazy_bind("e_credentials_new_clone", this.ECredentials.ptr,
                [this.ECredentials.ptr]);
  lib.lazy_bind_with_wrapper("e_credentials_peek", getString, glib.gchar.ptr,
                             [this.ECredentials.ptr, glib.gchar.ptr]);
  lib.lazy_bind("e_credentials_set", ctypes.void_t, [this.ECredentials.ptr,
                glib.gchar.ptr, glib.gchar.ptr]);
  lib.lazy_bind("e_list_get_iterator", this.EIterator.ptr, [this.EList.ptr]);
  lib.lazy_bind("e_iterator_is_valid", glib.gboolean, [this.EIterator.ptr]);
  lib.lazy_bind("e_iterator_next", glib.gboolean, [this.EIterator.ptr]);
  lib.lazy_bind("e_iterator_get", glib.gconstpointer, [this.EIterator.ptr]);
  lib.lazy_bind("e_uri_free", ctypes.void_t, [this.EUri.ptr]);
  lib.lazy_bind("e_uri_new", this.EUri.ptr, [glib.gchar.ptr]);
  lib.lazy_bind_with_wrapper("e_uri_to_string", getOwnedString, glib.gchar.ptr,
                             [this.EUri.ptr, glib.gboolean]);

  gobject.createSignal(this.EClient, "opened", ctypes.void_t,
                       [this.EClient.ptr, glib.GError.ptr, glib.gpointer]);

  // ABI < 17
  lib.lazy_bind_for_abis_with_wrapper("e_source_get_display_name", 15, getString,
                                      glib.gchar.ptr, [this.ESource.ptr],
                                      "e_source_peek_name");
  lib.lazy_bind_for_abis("e_source_set_display_name", 15, ctypes.void_t,
                         [this.ESource.ptr, glib.gchar.ptr],
                         "e_source_set_name");
  lib.lazy_bind_for_abis_with_wrapper("e_source_get_property", 15, getString,
                                      glib.gchar.ptr, [this.ESource.ptr,
                                      glib.gchar.ptr]);
  lib.lazy_bind_for_abis_with_wrapper("e_source_get_uid", 15, getString,
                                      glib.gchar.ptr, [this.ESource.ptr],
                                      "e_source_peek_uid");
  lib.lazy_bind_for_abis("e_source_group_peek_sources", 15, glib.GSList.ptr,
                         [this.ESourceGroup.ptr]);
  lib.lazy_bind_for_abis("e_source_list_peek_groups", 15, glib.GSList.ptr,
                         [this.ESourceList.ptr]);
  lib.lazy_bind_for_abis("e_source_list_peek_source_by_uid", 15,
                         this.ESource.ptr, [this.ESourceList.ptr,
                         glib.gchar.ptr]);
  lib.lazy_bind_for_abis("e_client_process_authentication", 15, ctypes.void_t,
                         [this.EClient.ptr, this.ECredentials.ptr]);
  lib.lazy_bind_for_abis_with_wrapper("e_client_get_uri", 15, getString,
                                      glib.gchar.ptr, [this.EClient.ptr]);

  if (this.ABI == 15) {
    gobject.createSignal(this.EClient, "authenticate", glib.gboolean,
                         [this.EClient.ptr, this.ECredentials.ptr,
                          glib.gpointer]);
  }

  // ABI >= 17
  lib.lazy_bind_for_abis("e_source_set_display_name", 17, ctypes.void_t,
                         [this.ESource.ptr, glib.gchar.ptr]);
  lib.lazy_bind_for_abis_with_wrapper("e_source_get_display_name", 17, getString,
                                      glib.gchar.ptr, [this.ESource.ptr]);
  lib.lazy_bind_for_abis_with_wrapper("e_source_get_uid", 17, getString,
                                      glib.gchar.ptr, [this.ESource.ptr]);
  lib.lazy_bind_for_abis("e_source_registry_new_sync", 17,
                         this.ESourceRegistry.ptr,
                         [gio.GCancellable.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind_for_abis("e_source_registry_list_sources", 17, glib.GList.ptr,
                         [this.ESourceRegistry.ptr, glib.gchar.ptr]);
  lib.lazy_bind_for_abis("e_source_registry_ref_source", 17, this.ESource.ptr,
                         [this.ESourceRegistry.ptr, glib.gchar.ptr]);
}

var eds = CTypesUtils.newLibrary(EDS_LIBNAME, EDS_ABIS, eds_defines);
