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

var EXPORTED_SYMBOLS = [ "glib" ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");

const GLIB_LIBNAME = "glib-2.0";
const GLIB_ABIS = [ 0 ];

function glib_defines(lib) {
  // Enums

  // Constants
  CTypesUtils.defineSimple(this, "TRUE", 1);
  CTypesUtils.defineSimple(this, "FALSE", 0);

  // Types
  CTypesUtils.defineSimple(this, "gpointer", ctypes.voidptr_t);
  CTypesUtils.defineSimple(this, "gint", ctypes.int);
  CTypesUtils.defineSimple(this, "gboolean", this.gint);
  CTypesUtils.defineSimple(this, "gchar", ctypes.char);
  CTypesUtils.defineSimple(this, "guchar", ctypes.unsigned_char);
  CTypesUtils.defineSimple(this, "glong", ctypes.long);
  CTypesUtils.defineSimple(this, "guint", ctypes.unsigned_int);
  CTypesUtils.defineSimple(this, "gsize", ctypes.unsigned_long);
  CTypesUtils.defineSimple(this, "gconstpointer", ctypes.voidptr_t);
  CTypesUtils.defineSimple(this, "gulong", ctypes.unsigned_long);
  CTypesUtils.defineSimple(this, "guint32", ctypes.unsigned_int);
  CTypesUtils.defineSimple(this, "GSList", ctypes.StructType("GSList"));
  this.GSList.define([{"data": this.gpointer},
                      {"next": this.GSList.ptr}]);
  CTypesUtils.defineSimple(this, "GList", ctypes.StructType("GList"));
  this.GList.define([{"data": this.gpointer},
                     {"next": this.GList.ptr},
                     {"prev": this.GList.ptr}]);
  CTypesUtils.defineSimple(this, "GQuark", this.guint32);
  CTypesUtils.defineSimple(this, "GError",
                           ctypes.StructType("GError",
                                             [{'domain': this.GQuark},
                                              {'code': this.gint},
                                              {'message': this.gchar.ptr}]));

  // Templates
  CTypesUtils.defineSimple(this, "GFunc",
                           ctypes.FunctionType(ctypes.default_abi,
                                               ctypes.void_t,
                                               [this.gpointer,
                                                this.gpointer]).ptr);

  // Functions
  lib.lazy_bind("g_error_copy", this.GError.ptr, [this.GError.ptr]);
  lib.lazy_bind("g_error_free", ctypes.void_t, [this.GError.ptr]);
  lib.lazy_bind("g_error_matches", this.gboolean, [this.GError.ptr,
                this.GQuark, this.gint]);
  lib.lazy_bind("g_list_append", this.GList.ptr, [this.GList.ptr,
                this.gpointer]);
  lib.lazy_bind("g_list_concat", this.GList.ptr, [this.GList.ptr,
                this.GList.ptr]);
  lib.lazy_bind("g_list_delete_link", this.GList.ptr, [this.GList.ptr,
                this.GList.ptr]);
  lib.lazy_bind("g_list_free", ctypes.void_t, [this.GList.ptr]);
  lib.lazy_bind_with_wrapper("g_list_foreach", function(aWrapped, aList,
                                                        aFunc) {
    aWrapped(aList, this.GFunc(aFunc), null);
  }, ctypes.void_t, [this.GList.ptr, this.GFunc, this.gpointer]);
  lib.lazy_bind("g_list_length", this.guint, [this.GList.ptr]);
  lib.lazy_bind("g_slist_free", ctypes.void_t, [this.GSList.ptr]);
  lib.lazy_bind_with_wrapper("g_slist_foreach", function(aWrapped, aList,
                                                         aFunc) {
    aWrapped(aList, this.GFunc(aFunc), null);
  }, ctypes.void_t, [this.GSList.ptr, this.GFunc, this.gpointer]);
  lib.lazy_bind("g_free", ctypes.void_t, [this.gpointer]);

  /**
   * Helper to cast a ctypes int to a ctypes pointer
   *
   * @param  aInt
   *         An integer
   * @return A pointer
   */
  CTypesUtils.defineSimple(this, "GINT_TO_POINTER", function(aInt) {
    return ctypes.cast(this.glong(aInt) , this.gpointer);
  });

  /**
   * Create an iterator from a GLib list
   *
   * @param  aList
   *         A pointer to a list (must be instance of GList.ptr
   *         or GSList.ptr)
   * @param  aType
   *         The C type of each list element
   * @param  aConsume (optional)
   *         Whether the list should be freed when done
   * @param  aDestroyFunc (optional)
   *         Function to free each list element (must be a C function)
   * @return An iterable object on which you can use |for..in|
   */
  CTypesUtils.defineSimple(this, "listIterator",
                           function glib_listIterator(aList, aType, aConsume,
                                                      aDestroyFunc) {
    if (aList) {
      if (!(aList instanceof this.GList.ptr) &&
          !(aList instanceof this.GSList.ptr)) {
        throw Error("Invalid GLib list");
      }
    }

    var ns = { "GList": "g_list",
               "GSList": "g_slist" }[aList.constructor.targetType.name];

    return { __iterator__: function() {
      for (let a = aList; a && !a.isNull(); a = a.contents.next) {
        yield ctypes.cast(a.contents.data, aType);
      }

      if (!aList) {
        return;
      }

      if (aConsume) {
        if (aDestroyFunc) {
          let list = aList;
          while (!list.isNull()) {
            aDestroyFunc(ctypes.cast(list.contents.data, aType));
            list = list.contents.next;
          }
        }
        glib[ns + "_free"](aList);
      }
    } };
  });
}

var glib = CTypesUtils.newLibrary(GLIB_LIBNAME, GLIB_ABIS, glib_defines);
