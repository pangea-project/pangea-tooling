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

var EXPORTED_SYMBOLS = [ "ebook" ];

const EBOOK_LIBNAME = "ebook-1.2";
const EBOOK_ABIS = [ 14, 12 ];

Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource://edsintegration/modules/utils.jsm");
Cu.import("resource://edsintegration/libs/glib.jsm");
Cu.import("resource://edsintegration/libs/gobject.jsm");
Cu.import("resource://edsintegration/libs/gio.jsm");
Cu.import("resource://edsintegration/libs/eds.jsm");

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

function ebook_defines(lib) {
  // Enums
  CTypesUtils.defineEnums(this, "EContactPhotoType", 0, [
    "E_CONTACT_PHOTO_TYPE_INLINED",
    "E_CONTACT_PHOTO_TYPE_URI"
  ]);

  CTypesUtils.defineEnums(this, "EContactField", 1, [
  	"E_CONTACT_UID",	 /* string field */
	  "E_CONTACT_FILE_AS",	 /* string field */
	  "E_CONTACT_BOOK_UID",      /* string field */

  	/* Name fields */
  	"E_CONTACT_FULL_NAME",	 /* string field */
  	"E_CONTACT_GIVEN_NAME",	 /* synthetic string field */
  	"E_CONTACT_FAMILY_NAME",	 /* synthetic string field */
  	"E_CONTACT_NICKNAME",	 /* string field */

  	/* Email fields */
  	"E_CONTACT_EMAIL_1",	 /* synthetic string field */
  	"E_CONTACT_EMAIL_2",	 /* synthetic string field */
  	"E_CONTACT_EMAIL_3",	 /* synthetic string field */
  	"E_CONTACT_EMAIL_4",       /* synthetic string field */

  	"E_CONTACT_MAILER",        /* string field */

  	/* Address Labels */
  	"E_CONTACT_ADDRESS_LABEL_HOME",  /* synthetic string field */
  	"E_CONTACT_ADDRESS_LABEL_WORK",  /* synthetic string field */
  	"E_CONTACT_ADDRESS_LABEL_OTHER", /* synthetic string field */

  	/* Phone fields */
  	"E_CONTACT_PHONE_ASSISTANT",
  	"E_CONTACT_PHONE_BUSINESS",
  	"E_CONTACT_PHONE_BUSINESS_2",
  	"E_CONTACT_PHONE_BUSINESS_FAX",
  	"E_CONTACT_PHONE_CALLBACK",
  	"E_CONTACT_PHONE_CAR",
  	"E_CONTACT_PHONE_COMPANY",
  	"E_CONTACT_PHONE_HOME",
  	"E_CONTACT_PHONE_HOME_2",
  	"E_CONTACT_PHONE_HOME_FAX",
  	"E_CONTACT_PHONE_ISDN",
  	"E_CONTACT_PHONE_MOBILE",
  	"E_CONTACT_PHONE_OTHER",
  	"E_CONTACT_PHONE_OTHER_FAX",
  	"E_CONTACT_PHONE_PAGER",
  	"E_CONTACT_PHONE_PRIMARY",
  	"E_CONTACT_PHONE_RADIO",
  	"E_CONTACT_PHONE_TELEX",
  	"E_CONTACT_PHONE_TTYTDD",

  	/* Organizational fields */
  	"E_CONTACT_ORG",		 /* string field */
  	"E_CONTACT_ORG_UNIT",	 /* string field */
  	"E_CONTACT_OFFICE",	 /* string field */
  	"E_CONTACT_TITLE",	 /* string field */
  	"E_CONTACT_ROLE",	 /* string field */
  	"E_CONTACT_MANAGER",	 /* string field */
  	"E_CONTACT_ASSISTANT",	 /* string field */

  	/* Web fields */
  	"E_CONTACT_HOMEPAGE_URL",  /* string field */
  	"E_CONTACT_BLOG_URL",      /* string field */

  	/* Contact categories */
  	"E_CONTACT_CATEGORIES",    /* string field */

  	/* Collaboration fields */
  	"E_CONTACT_CALENDAR_URI",  /* string field */
  	"E_CONTACT_FREEBUSY_URL",  /* string field */
  	"E_CONTACT_ICS_CALENDAR",  /* string field */
  	"E_CONTACT_VIDEO_URL",      /* string field */

  	/* misc fields */
  	"E_CONTACT_SPOUSE",        /* string field */
  	"E_CONTACT_NOTE",          /* string field */

  	"E_CONTACT_IM_AIM_HOME_1",       /* Synthetic string field */
  	"E_CONTACT_IM_AIM_HOME_2",       /* Synthetic string field */
  	"E_CONTACT_IM_AIM_HOME_3",       /* Synthetic string field */
  	"E_CONTACT_IM_AIM_WORK_1",       /* Synthetic string field */
  	"E_CONTACT_IM_AIM_WORK_2",       /* Synthetic string field */
  	"E_CONTACT_IM_AIM_WORK_3",       /* Synthetic string field */
  	"E_CONTACT_IM_GROUPWISE_HOME_1", /* Synthetic string field */
  	"E_CONTACT_IM_GROUPWISE_HOME_2", /* Synthetic string field */
  	"E_CONTACT_IM_GROUPWISE_HOME_3", /* Synthetic string field */
  	"E_CONTACT_IM_GROUPWISE_WORK_1", /* Synthetic string field */
  	"E_CONTACT_IM_GROUPWISE_WORK_2", /* Synthetic string field */
  	"E_CONTACT_IM_GROUPWISE_WORK_3", /* Synthetic string field */
  	"E_CONTACT_IM_JABBER_HOME_1",    /* Synthetic string field */
  	"E_CONTACT_IM_JABBER_HOME_2",    /* Synthetic string field */
  	"E_CONTACT_IM_JABBER_HOME_3",    /* Synthetic string field */
  	"E_CONTACT_IM_JABBER_WORK_1",    /* Synthetic string field */
  	"E_CONTACT_IM_JABBER_WORK_2",    /* Synthetic string field */
  	"E_CONTACT_IM_JABBER_WORK_3",    /* Synthetic string field */
  	"E_CONTACT_IM_YAHOO_HOME_1",     /* Synthetic string field */
  	"E_CONTACT_IM_YAHOO_HOME_2",     /* Synthetic string field */
  	"E_CONTACT_IM_YAHOO_HOME_3",     /* Synthetic string field */
  	"E_CONTACT_IM_YAHOO_WORK_1",     /* Synthetic string field */
  	"E_CONTACT_IM_YAHOO_WORK_2",     /* Synthetic string field */
  	"E_CONTACT_IM_YAHOO_WORK_3",     /* Synthetic string field */
  	"E_CONTACT_IM_MSN_HOME_1",       /* Synthetic string field */
  	"E_CONTACT_IM_MSN_HOME_2",       /* Synthetic string field */
  	"E_CONTACT_IM_MSN_HOME_3",       /* Synthetic string field */
  	"E_CONTACT_IM_MSN_WORK_1",       /* Synthetic string field */
  	"E_CONTACT_IM_MSN_WORK_2",       /* Synthetic string field */
  	"E_CONTACT_IM_MSN_WORK_3",       /* Synthetic string field */
  	"E_CONTACT_IM_ICQ_HOME_1",       /* Synthetic string field */
  	"E_CONTACT_IM_ICQ_HOME_2",       /* Synthetic string field */
  	"E_CONTACT_IM_ICQ_HOME_3",       /* Synthetic string field */
  	"E_CONTACT_IM_ICQ_WORK_1",       /* Synthetic string field */
  	"E_CONTACT_IM_ICQ_WORK_2",       /* Synthetic string field */
  	"E_CONTACT_IM_ICQ_WORK_3",       /* Synthetic string field */

  	/* Convenience field for getting a name from the contact.
  	 * Returns the first one of[File-As, Full Name, Org, Email1]
  	 * to be set */
  	"E_CONTACT_REV",     /* string field to hold  time of last update to this vcard */
  	"E_CONTACT_NAME_OR_ORG",

  	/* Address fields */
  	"E_CONTACT_ADDRESS",       /* Multi-valued structured (EContactAddress) */
  	"E_CONTACT_ADDRESS_HOME",  /* synthetic structured field (EContactAddress) */
  	"E_CONTACT_ADDRESS_WORK",  /* synthetic structured field (EContactAddress) */
  	"E_CONTACT_ADDRESS_OTHER", /* synthetic structured field (EContactAddress) */

  	"E_CONTACT_CATEGORY_LIST", /* multi-valued */

  	/* Photo/Logo */
  	"E_CONTACT_PHOTO",	 /* structured field (EContactPhoto) */
  	"E_CONTACT_LOGO",	 /* structured field (EContactPhoto) */

  	"E_CONTACT_NAME",		 /* structured field (EContactName) */
  	"E_CONTACT_EMAIL",	 /* Multi-valued */

  	/* Instant Messaging fields */
  	"E_CONTACT_IM_AIM",	 /* Multi-valued */
  	"E_CONTACT_IM_GROUPWISE",  /* Multi-valued */
  	"E_CONTACT_IM_JABBER",	 /* Multi-valued */
  	"E_CONTACT_IM_YAHOO",	 /* Multi-valued */
  	"E_CONTACT_IM_MSN",	 /* Multi-valued */
  	"E_CONTACT_IM_ICQ",	 /* Multi-valued */

  	"E_CONTACT_WANTS_HTML",    /* boolean field */

  	/* fields used for describing contact lists.  a contact list
  	 * is just a contact with _IS_LIST set to true.  the members
  	 * are listed in the _EMAIL field. */
  	"E_CONTACT_IS_LIST",             /* boolean field */
  	"E_CONTACT_LIST_SHOW_ADDRESSES", /* boolean field */

  	"E_CONTACT_BIRTH_DATE",    /* structured field (EContactDate) */
  	"E_CONTACT_ANNIVERSARY",   /* structured field (EContactDate) */

  	/* Security Fields */
  	"E_CONTACT_X509_CERT",     /* structured field (EContactCert) */

  	"E_CONTACT_IM_GADUGADU_HOME_1",  /* Synthetic string field */
  	"E_CONTACT_IM_GADUGADU_HOME_2",  /* Synthetic string field */
  	"E_CONTACT_IM_GADUGADU_HOME_3",  /* Synthetic string field */
  	"E_CONTACT_IM_GADUGADU_WORK_1",  /* Synthetic string field */
  	"E_CONTACT_IM_GADUGADU_WORK_2",  /* Synthetic string field */
  	"E_CONTACT_IM_GADUGADU_WORK_3",  /* Synthetic string field */

  	"E_CONTACT_IM_GADUGADU",   /* Multi-valued */

  	"E_CONTACT_GEO",	/* structured field (EContactGeo) */

  	"E_CONTACT_TEL", /* list of strings */

  	"E_CONTACT_IM_SKYPE_HOME_1",     /* Synthetic string field */
  	"E_CONTACT_IM_SKYPE_HOME_2",     /* Synthetic string field */
  	"E_CONTACT_IM_SKYPE_HOME_3",     /* Synthetic string field */
  	"E_CONTACT_IM_SKYPE_WORK_1",     /* Synthetic string field */
  	"E_CONTACT_IM_SKYPE_WORK_2",     /* Synthetic string field */
  	"E_CONTACT_IM_SKYPE_WORK_3",     /* Synthetic string field */
  	"E_CONTACT_IM_SKYPE",		/* Multi-valued */

  	"E_CONTACT_SIP",

  	"E_CONTACT_IM_GOOGLE_TALK_HOME_1",     /* Synthetic string field */
  	"E_CONTACT_IM_GOOGLE_TALK_HOME_2",     /* Synthetic string field */
  	"E_CONTACT_IM_GOOGLE_TALK_HOME_3",     /* Synthetic string field */
  	"E_CONTACT_IM_GOOGLE_TALK_WORK_1",     /* Synthetic string field */
  	"E_CONTACT_IM_GOOGLE_TALK_WORK_2",     /* Synthetic string field */
  	"E_CONTACT_IM_GOOGLE_TALK_WORK_3",     /* Synthetic string field */
  	"E_CONTACT_IM_GOOGLE_TALK",		/* Multi-valued */

     // This one only exists in libebook14 - don't use E_CONTACT_FIELD_LAST anywhere!
  	"E_CONTACT_IM_TWITTER",		/* Multi-valued */

  	"E_CONTACT_FIELD_LAST"
  ]);

  // Constants
  CTypesUtils.defineSimple(this.EContactFieldEnums, "E_CONTACT_FIELD_FIRST",
                           this.EContactFieldEnums.E_CONTACT_UID);

  CTypesUtils.defineSimple(this.EContactFieldEnums,
                           "E_CONTACT_LAST_SIMPLE_STRING",
                           this.EContactFieldEnums.E_CONTACT_NAME_OR_ORG);
  CTypesUtils.defineSimple(this.EContactFieldEnums, "E_CONTACT_FIRST_PHONE_ID",
                           this.EContactFieldEnums.E_CONTACT_PHONE_ASSISTANT);
  CTypesUtils.defineSimple(this.EContactFieldEnums, "E_CONTACT_LAST_PHONE_ID",
                           this.EContactFieldEnums.E_CONTACT_PHONE_TTYTDD);
  CTypesUtils.defineSimple(this.EContactFieldEnums, "E_CONTACT_FIRST_EMAIL_ID",
                           this.EContactFieldEnums.E_CONTACT_EMAIL_1);
  CTypesUtils.defineSimple(this.EContactFieldEnums, "E_CONTACT_LAST_EMAIL_ID",
                           this.EContactFieldEnums.E_CONTACT_EMAIL_4);
  CTypesUtils.defineSimple(this.EContactFieldEnums,
                           "E_CONTACT_FIRST_ADDRESS_ID",
                           this.EContactFieldEnums.E_CONTACT_ADDRESS_HOME);
  CTypesUtils.defineSimple(this.EContactFieldEnums,
                           "E_CONTACT_LAST_ADDRESS_ID",
                           this.EContactFieldEnums.E_CONTACT_ADDRESS_OTHER);
  CTypesUtils.defineSimple(this.EContactFieldEnums, "E_CONTACT_FIRST_LABEL_ID",
                           this.EContactFieldEnums.E_CONTACT_ADDRESS_LABEL_HOME);
  CTypesUtils.defineSimple(this.EContactFieldEnums, "E_CONTACT_LAST_LABEL_ID",
                           this.EContactFieldEnums.E_CONTACT_ADDRESS_LABEL_OTHER);

  CTypesUtils.defineSimple(this, "EVC_EMAIL", "EMAIL");
  CTypesUtils.defineSimple(this, "EVC_TEL", "TEL");
  CTypesUtils.defineSimple(this, "EVC_TYPE", "TYPE");
  CTypesUtils.defineSimple(this, "EVC_X_ASSISTANT", "X-EVOLUTION-ASSISTANT");
  CTypesUtils.defineSimple(this, "EVC_X_CALLBACK", "X-EVOLUTION-CALLBACK");
  CTypesUtils.defineSimple(this, "EVC_X_RADIO", "X-EVOLUTION-RADIO");
  CTypesUtils.defineSimple(this, "EVC_X_TELEX", "X-EVOLUTION-TELEX");
  CTypesUtils.defineSimple(this, "EVC_X_TTYTDD", "X-EVOLUTION-TTYTDD");
  CTypesUtils.defineSimple(this, "WORK", "WORK");
  CTypesUtils.defineSimple(this, "HOME", "HOME");
  CTypesUtils.defineSimple(this, "OTHER", "OTHER");

  // Types
  CTypesUtils.defineSimple(this, "EBookClient", ctypes.StructType("EBookClient"));
  CTypesUtils.defineSimple(this, "EBookClientView", ctypes.StructType("EBookClientView"));
  CTypesUtils.defineSimple(this, "EBook", ctypes.StructType("EBook"));
  CTypesUtils.defineSimple(this, "EContact", ctypes.StructType("EContact"));
  CTypesUtils.defineSimple(this, "EBookQuery", ctypes.StructType("EBookQuery"));
  CTypesUtils.defineSimple(this, "EBookView", ctypes.StructType("EBookView"));
  CTypesUtils.defineSimple(this, "EContactAddress",
                           ctypes.StructType("EContactAddress",
                                             [{"address_format": glib.gchar.ptr},
                                              {"po": glib.gchar.ptr},
                                              {"ext": glib.gchar.ptr},
                                              {"street": glib.gchar.ptr},
                                              {"locality": glib.gchar.ptr},
                                              {"region": glib.gchar.ptr},
                                              {"code": glib.gchar.ptr},
                                              {"country": glib.gchar.ptr}]));
  CTypesUtils.defineSimple(this, "EContactDate",
                           ctypes.StructType("EContactDate",
                                             [{"year": glib.guint},
                                              {"month": glib.guint},
                                              {"day": glib.guint}]));
  CTypesUtils.defineSimple(this, "EContactName",
                           ctypes.StructType("EContactName",
                                             [{"family": glib.gchar.ptr},
                                              {"given": glib.gchar.ptr},
                                              {"additional": glib.gchar.ptr},
                                              {"prefixes": glib.gchar.ptr},
                                              {"suffixes": glib.gchar.ptr}]));
  CTypesUtils.defineSimple(this, "EContactPhoto",
                           ctypes.StructType("EContactPhoto",
                                             [{"type": this.EContactPhotoType},
                                              {"data": ctypes.StructType("anon1",
                                                                         [{"inlined": ctypes.StructType("anon2",
                                                                                                        [{"mime_type": glib.gchar.ptr},
                                                                                                         {"length": glib.gsize},
                                                                                                         {"data": glib.guchar.ptr}])}])}]));
  CTypesUtils.defineSimple(this, "EVCard", ctypes.StructType("EVCard"));
  CTypesUtils.defineSimple(this, "EVCardAttribute",
                           ctypes.StructType("EVCardAttribute"));
  CTypesUtils.defineSimple(this, "EVCardAttributeParam",
                           ctypes.StructType("EVCardAttributeParam"));

  // Functions
  lib.lazy_bind("e_book_add_contact", glib.gboolean, [this.EBook.ptr,
                this.EContact.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind("e_book_commit_contact", glib.gboolean, [this.EBook.ptr,
                this.EContact.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind("e_book_client_add_contact_sync", glib.gboolean,
                [this.EBookClient.ptr, this.EContact.ptr, glib.gchar.ptr.ptr,
                gio.GCancellable.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind_with_wrapper("e_book_client_get_view", function(aWrappee,
                                                                aClient,
                                                                aSexp,
                                                                aCancellable,
                                                                aCallback) {
    var ccw = CTypesUtils.wrapCallback(aCallback,
                                       {type: gio.GAsyncReadyCallback,
                                        root: true, singleshot: true});

    try {
      aWrappee(aClient, aSexp, aCancellable, ccw, null);
    } catch(e) {
      CTypesUtils.unrootCallback(aCallback);
      throw e;
    }
  }, ctypes.void_t, [this.EBookClient.ptr, glib.gchar.ptr,
                     gio.GCancellable.ptr, gio.GAsyncReadyCallback,
                     glib.gpointer]);
  lib.lazy_bind("e_book_client_get_view_finish", glib.gboolean,
                [this.EBookClient.ptr, gio.GAsyncResult.ptr,
                this.EBookClientView.ptr.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind_with_wrapper("e_book_client_modify_contact", function(aWrappee,
                                                                      aClient,
                                                                      aContact,
                                                                      aCancellable,
                                                                      aCallback) {
    var ccw = CTypesUtils.wrapCallback(aCallback,
                                       {type: gio.GAsyncReadyCallback,
                                        root: true, singleshot: true});

    try {
      aWrappee(aClient, aContact, aCancellable, ccw, null);
    } catch(e) {
      CTypesUtils.unrootCallback(aCallback);
      throw e;
    }
  }, ctypes.void_t, [this.EBookClient.ptr, this.EContact.ptr,
                     gio.GCancellable.ptr, gio.GAsyncReadyCallback,
                     glib.gpointer]);
  lib.lazy_bind("e_book_client_modify_contact_finish", glib.gboolean,
                [this.EBookClient.ptr, gio.GAsyncResult.ptr,
                glib.GError.ptr.ptr]);
  lib.lazy_bind("e_book_client_modify_contact_sync", glib.gboolean,
                [this.EBookClient.ptr, this.EContact.ptr, gio.GCancellable.ptr,
                glib.GError.ptr.ptr]);
  lib.lazy_bind("e_book_client_new", this.EBookClient.ptr, [eds.ESource.ptr,
                glib.GError.ptr.ptr]);
  lib.lazy_bind_with_wrapper("e_book_client_remove_contact", function(aWrappee,
                                                                      aClient,
                                                                      aContact,
                                                                      aCancellable,
                                                                      aCallback) {
    var ccw = CTypesUtils.wrapCallback(aCallback,
                                       {type: gio.GAsyncReadyCallback,
                                        root: true, singleshot: true});

    try {
      aWrappee(aClient, aContact, aCancellable, ccw, null);
    } catch(e) {
      CTypesUtils.unrootCallback(aCallback);
      throw e;
    }
  }, ctypes.void_t, [this.EBookClient.ptr, this.EContact.ptr,
                     gio.GCancellable.ptr, gio.GAsyncReadyCallback,
                     glib.gpointer]);
  lib.lazy_bind("e_book_client_remove_contact_finish", glib.gboolean,
                [this.EBookClient.ptr, gio.GAsyncResult.ptr,
                glib.GError.ptr.ptr]);
  lib.lazy_bind("e_book_client_view_start", ctypes.void_t,
                [this.EBookClientView.ptr, glib.GError.ptr.ptr]);
  lib.lazy_bind("e_book_query_any_field_contains", this.EBookQuery.ptr,
                [glib.gchar.ptr]);
  lib.lazy_bind_with_wrapper("e_book_query_to_string", getString,
                             glib.gchar.ptr, [this.EBookQuery.ptr]);
  lib.lazy_bind("e_contact_address_new", this.EContactAddress.ptr);
  lib.lazy_bind("e_contact_address_free", ctypes.void_t,
                [this.EContactAddress.ptr]);
  lib.lazy_bind("e_contact_address_get_type", gobject.GType);
  lib.lazy_bind("e_contact_date_free", ctypes.void_t, [this.EContactDate.ptr]);
  lib.lazy_bind("e_contact_duplicate", this.EContact.ptr, [this.EContact.ptr]);
  lib.lazy_bind_with_wrapper("e_contact_field_name", getString, glib.gchar.ptr,
                             [this.EContactField]);
  lib.lazy_bind("e_contact_field_id", this.EContactField, [glib.gchar.ptr]);
  lib.lazy_bind("e_contact_photo_free", ctypes.void_t, [this.EContactPhoto.ptr]);
  lib.lazy_bind_with_wrapper("e_contact_pretty_name", getString,
                             glib.gchar.ptr, [this.EContactField]);
  lib.lazy_bind("e_contact_get", glib.gpointer, [this.EContact.ptr,
                this.EContactField]);
  lib.lazy_bind("e_contact_get_attributes", glib.GList.ptr, [this.EContact.ptr,
                this.EContactField]);
  lib.lazy_bind("e_contact_get_const", glib.gconstpointer, [this.EContact.ptr,
                this.EContactField]);
  lib.lazy_bind("e_contact_name_free", ctypes.void_t, [this.EContactName.ptr]);
  lib.lazy_bind("e_contact_name_from_string", this.EContactName.ptr,
                [glib.gchar.ptr]);
  lib.lazy_bind("e_contact_name_new", this.EContactName.ptr);
  lib.lazy_bind("e_contact_new", this.EContact.ptr);
  lib.lazy_bind("e_contact_set", ctypes.void_t, [this.EContact.ptr,
                this.EContactField, glib.gconstpointer]);
  lib.lazy_bind("e_contact_set_attributes", ctypes.void_t, [this.EContact.ptr,
                this.EContactField, glib.GList.ptr]);
  lib.lazy_bind_with_wrapper("e_contact_vcard_attribute", getString,
                             glib.gchar.ptr, [this.EContactField]);
  lib.lazy_bind("e_vcard_add_attribute", ctypes.void_t, [this.EVCard.ptr,
                this.EVCardAttribute.ptr]);
  lib.lazy_bind("e_vcard_append_attribute", ctypes.void_t, [this.EVCard.ptr,
                this.EVCardAttribute.ptr]);
  lib.lazy_bind("e_vcard_attribute_add_param_with_value", ctypes.void_t,
                [this.EVCardAttribute.ptr, this.EVCardAttributeParam.ptr,
                glib.gchar.ptr]);
  lib.lazy_bind("e_vcard_get_attribute", this.EVCardAttribute.ptr,
                [this.EVCard.ptr, glib.gchar.ptr]);
  lib.lazy_bind("e_vcard_get_attributes", glib.GList.ptr, [this.EVCard.ptr]);
  lib.lazy_bind("e_vcard_attribute_add_value", ctypes.void_t,
                [this.EVCardAttribute.ptr, glib.gchar.ptr]);
  lib.lazy_bind("e_vcard_attribute_free", ctypes.void_t,
                [this.EVCardAttribute.ptr]);
  lib.lazy_bind_with_wrapper("e_vcard_attribute_get_name", getString,
                             glib.gchar.ptr, [this.EVCardAttribute.ptr]);
  lib.lazy_bind_with_wrapper("e_vcard_attribute_get_value", getOwnedString,
                             glib.gchar.ptr, [this.EVCardAttribute.ptr]);
  lib.lazy_bind("e_vcard_attribute_has_type", glib.gboolean,
                [this.EVCardAttribute.ptr, glib.gchar.ptr]);
  lib.lazy_bind("e_vcard_attribute_copy", this.EVCardAttribute.ptr,
                [this.EVCardAttribute.ptr]);
  lib.lazy_bind("e_vcard_attribute_new", this.EVCardAttribute.ptr,
                [glib.gchar.ptr, glib.gchar.ptr]);
  lib.lazy_bind("e_vcard_attribute_param_new", this.EVCardAttributeParam.ptr,
                [glib.gchar.ptr]);
  lib.lazy_bind("e_vcard_remove_attributes", ctypes.void_t, [this.EVCard.ptr,
                glib.gchar.ptr, glib.gchar.ptr]);

  gobject.createSignal(this.EBookClientView, "objects-added", ctypes.void_t,
                       [this.EBookClientView.ptr, glib.gpointer,
                        glib.gpointer]);
  gobject.createSignal(this.EBookClientView, "objects-modified", ctypes.void_t,
                       [this.EBookClientView.ptr, glib.gpointer,
                        glib.gpointer]);
  gobject.createSignal(this.EBookClientView, "objects-removed", ctypes.void_t,
                       [this.EBookClientView.ptr, glib.gpointer,
                        glib.gpointer]);

  // ABI < 14
  lib.lazy_bind_for_abis("e_book_client_get_sources", 12, glib.gboolean,
                         [eds.ESourceList.ptr.ptr, glib.GError.ptr.ptr]);
}

var ebook = CTypesUtils.newLibrary(EBOOK_LIBNAME, EBOOK_ABIS, ebook_defines, this);
