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
 *    Chris Coulson <chris.coulson@canonical.com>
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

var EXPORTED_SYMBOLS = [ "gdk" ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://messagingmenu/modules/utils.jsm");
Cu.import("resource://messagingmenu/libs/glib.jsm");
Cu.import("resource://messagingmenu/libs/gobject.jsm");

const GDK_LIBNAME = "gdk-x11-2.0";
const GDK_ABIS    = [ 0 ];

function gdk_defines(lib) {
  CTypesUtils.defineSimple(this, "GdkWindow", ctypes.StructType("GdkWindow"));
  CTypesUtils.defineSimple(this, "GdkVisual", ctypes.StructType("GdkVisual"));
  CTypesUtils.defineSimple(this, "GdkColormap",
                           ctypes.StructType("GdkColormap"));
  CTypesUtils.defineSimple(this, "GdkWindowType",
                           ctypes.StructType("GdkWindowType"));
  CTypesUtils.defineSimple(this, "GdkCursor", ctypes.StructType("GdkCursor"));
  CTypesUtils.defineSimple(this, "GdkWindowTypeHint",
                           ctypes.StructType("GdkWindowTypeHint"));
  CTypesUtils.defineSimple(this, "GdkWindowClass",
                           ctypes.StructType("GdkWindowClass"));
  CTypesUtils.defineSimple(this, "GdkWindowAttributes",
                           ctypes.StructType("GdkWindowAttributes",
                                             [{ "title": glib.gchar },
                                              { "event_mask": glib.gint },
                                              { "x": glib.gint },
                                              { "y": glib.gint },
                                              { "width": glib.gint },
                                              { "height": glib.gint },
                                              { "wclass": glib.gint },
                                              { "visual": this.GdkVisual.ptr },
                                              { "colormap": this.GdkColormap.ptr },
                                              { "window_type": glib.gint },
                                              { "cursor": this.GdkCursor.ptr },
                                              { "wmclass_name": glib.gchar },
                                              { "wmclass_class": glib.gchar },
                                              { "override_redirect": glib.gboolean },
                                              { "type_hint": glib.gint }]));

  lib.lazy_bind("gdk_window_new", this.GdkWindow.ptr, [this.GdkWindow.ptr,
                this.GdkWindowAttributes.ptr, glib.gint]);
  lib.lazy_bind("gdk_window_destroy", ctypes.void_t, [this.GdkWindow.ptr]);
  lib.lazy_bind("gdk_x11_window_set_user_time", ctypes.void_t,
                [this.GdkWindow.ptr, glib.guint32]);
}

var gdk = CTypesUtils.newLibrary(GDK_LIBNAME, GDK_ABIS, gdk_defines);
