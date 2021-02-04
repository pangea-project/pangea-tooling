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

const { results: Cr, utils: Cu } = Components;

var EXPORTED_SYMBOLS = [ "ESourceProvider" ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");
Cu.import("resource://edsintegration/libs/eds.jsm");
Cu.import("resource://edsintegration/libs/ebook.jsm");
Cu.import("resource://edsintegration/modules/nsAbEDSCommon.jsm");

addLogger(this);

var gSourceProvider = null;

var ESourceProviderOldPrivate = {
  __source_list: null,
  get _source_list() {
    if (!this.__source_list) {
      this.__source_list = new eds.ESourceList.ptr;
      // XXX: We leak the source list
      ebook.e_book_client_get_sources(this.__source_list.address(), null);
    }

    return this.__source_list;
  },

  get sources() {
    return { __iterator__: function() {
      for (let group = eds.e_source_list_peek_groups(ESourceProviderOldPrivate._source_list);
           !group.isNull(); group = group.contents.next) {
        for (let source = eds.e_source_group_peek_sources(ctypes.cast(group.contents.data,
                                                                      eds.ESourceGroup.ptr));
             !source.isNull(); source = source.contents.next) {
          yield ctypes.cast(source.contents.data, eds.ESource.ptr);
        }
      }
    }};
  },

  sourceForUid: function ESPOP_sourceForUid(aUid) {
    return ctypes.cast(gobject.g_object_ref(eds.e_source_list_peek_source_by_uid(this._source_list,
                                                                                 aUid)),
                       eds.ESource.ptr);
  }
};

var ESourceProviderPrivate = {
  __registry: null,
  get _registry() {
    if (!this.__registry) {
      try {
        var error = new glib.GError.ptr;
        // XXX: We leak this
        this.__registry = eds.e_source_registry_new_sync(null, error.address());
        if (this.__registry.isNull()) {
          ERROR("Failed to create source registry instance: "
                + error.contents.message.readString());
          throw Cr.NS_ERROR_FAILURE;
        }
      } finally {
        if (error && !error.isNull()) {
          glib.g_error_free(error);
        }
      }
    }

    return this.__registry;
  },

  get sources() {
    return glib.listIterator(eds.e_source_registry_list_sources(this._registry,
                                                                eds.E_SOURCE_EXTENSION_ADDRESS_BOOK),
                             eds.ESource.ptr, true, gobject.g_object_unref);
  },

  sourceForUid: function ESPP_sourceForUid(aUid) {
    return eds.e_source_registry_ref_source(this._registry, aUid);
  }
};

var ESourceProvider = {
  get sources() {
    return gSourceProvider.sources;
  },

  sourceForUid: function ESP_sourceForUid(aUid) {
    return gSourceProvider.sourceForUid(aUid);
  }
};

LOG("Found evolution-data-server ABI " + eds.ABI);
if (eds.ABI >= 17) {
  gSourceProvider = ESourceProviderPrivate;
} else {
  gSourceProvider = ESourceProviderOldPrivate;
}
