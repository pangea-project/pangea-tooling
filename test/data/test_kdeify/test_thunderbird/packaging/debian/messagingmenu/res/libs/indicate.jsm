/* -*- Mode: javascript; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
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
 * The Original Code is messagingmenu-extension
 *
 * The Initial Developer of the Original Code is
 * Mozilla Messaging, Ltd.
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *    Mike Conley <mconley@mozillamessaging.com>
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

var EXPORTED_SYMBOLS = [ "indicate" ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://messagingmenu/modules/utils.jsm");
Cu.import("resource://messagingmenu/libs/glib.jsm");
Cu.import("resource://messagingmenu/libs/gobject.jsm");
Cu.import("resource://messagingmenu/libs/dbusmenu.jsm");

const INDICATE_LIBNAME = "indicate";
const INDICATE_ABIS    = [ 5 ];

function indicate_defines(lib) {
  CTypesUtils.defineSimple(this, "INDICATOR_MESSAGES_SERVER_TYPE", "message");
  CTypesUtils.defineSimple(this, "INDICATOR_MESSAGES_PROP_NAME", "name");
  CTypesUtils.defineSimple(this, "INDICATOR_MESSAGES_PROP_ICON", "icon");
  CTypesUtils.defineSimple(this, "INDICATOR_MESSAGES_PROP_COUNT", "count");
  CTypesUtils.defineSimple(this, "INDICATOR_MESSAGES_PROP_TIME", "time");
  CTypesUtils.defineSimple(this, "INDICATOR_MESSAGES_PROP_ATTENTION",
                           "draw-attention");

  CTypesUtils.defineSimple(this, "IndicateServer",
                           ctypes.StructType("IndicateServer"));
  CTypesUtils.defineSimple(this, "Indicator", ctypes.StructType("Indicator"));

  lib.lazy_bind("indicate_server_ref_default", this.IndicateServer.ptr);
  lib.lazy_bind("indicate_server_set_type", ctypes.void_t,
                [this.IndicateServer.ptr, glib.gchar.ptr]);
  lib.lazy_bind("indicate_server_set_desktop_file", ctypes.void_t,
                [this.IndicateServer.ptr, glib.gchar.ptr]);
  lib.lazy_bind("indicate_server_show", ctypes.void_t,
                [this.IndicateServer.ptr]);
  lib.lazy_bind("indicate_server_hide", ctypes.void_t,
                [this.IndicateServer.ptr]);
  lib.lazy_bind("indicate_server_set_menu", ctypes.void_t,
                [this.IndicateServer.ptr, dbusmenu.DbusmenuServer.ptr]);
  lib.lazy_bind("indicate_indicator_new", this.Indicator.ptr);
  lib.lazy_bind("indicate_indicator_set_property", ctypes.void_t,
                [this.Indicator.ptr, glib.gchar.ptr, glib.gchar.ptr]);
  lib.lazy_bind("indicate_indicator_get_property", glib.gchar.ptr,
                [this.Indicator.ptr, glib.gchar.ptr]);
  lib.lazy_bind("indicate_indicator_show", ctypes.void_t,
                [this.Indicator.ptr]);
  lib.lazy_bind("indicate_indicator_hide", ctypes.void_t,
                [this.Indicator.ptr]);
  lib.lazy_bind("indicate_indicator_is_visible", glib.gboolean,
                [this.Indicator.ptr]);

  gobject.createSignal(this.IndicateServer, "server-display", ctypes.void_t,
                       [this.IndicateServer.ptr, glib.guint, glib.gpointer]);
  gobject.createSignal(this.Indicator, "user-display", ctypes.void_t,
                       [this.Indicator.ptr, glib.guint, glib.gpointer]);
}

var indicate = CTypesUtils.newLibrary(INDICATE_LIBNAME, INDICATE_ABIS, indicate_defines);
