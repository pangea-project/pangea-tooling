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

var MODULE_NAME = "test-nsAbEDSDirectory";

var RELATIVE_ROOT = "../shared-modules";
var MODULE_REQUIRES = ["address-book-helpers", "folder-display-helpers"];

Cu.import("resource://gre/modules/Services.jsm");
Cu.import("resource://edsintegration/ESourceProvider.jsm");
Cu.import("resource://edsintegration/nsAbEDSDirectory.jsm");
Cu.import("resource://edsintegration/LibEBookClient.jsm");
Cu.import("resource://edsintegration/LibGLib.jsm");
Cu.import("resource://edsintegration/LibESource.jsm");
Cu.import("resource://edsintegration/LibESourceList.jsm");
Cu.import("resource://edsintegration/LibESourceGroup.jsm");
Cu.import("resource://edsintegration/LibEClient.jsm");
Cu.import("resource://gre/modules/ctypes.jsm");
Cu.import("resource:///modules/mailServices.js");

var abController;
var gTestBook;
var gESource;
var gESourceGroup;

function setupModule(module)
{
  gESource = LibESource.newWithAbsoluteUri("Test Book", "local:testbook");

  let uid = LibESource.peekUid(gESource).readString(); 
  let list = ESourceProvider.sourceListPtr;
  gESourceGroup = LibESourceList.peekGroupByBaseUri(list, "local:");
  let result = LibESourceGroup.addSource(gESourceGroup, gESource, 0);

  if (!result)
    throw("Problem adding test ESource - bailing out.");


  let errPtr = new LibGLib.GError.ptr();
  gEBookClient = LibEBookClient.newFromSource(gESource, errPtr.address());

  if (!errPtr.isNull()) {
    let msg = errPtr.contents.message.readString();
    LibGLib.g_error_free(errPtr);
    errPtr = null;
    throw("Could not construct an EBookClient form the ESource. Message"
          + " was: " + msg);
  }

  let sourceList = [uid];
  let uri = "moz-abedsdirectory://" + uid;

  ESourceProvider.ESourceUids = sourceList;

  let abh = collector.getModule("address-book-helpers");
  abh.installInto(module);
  let fdh = collector.getModule("folder-display-helpers");
  fdh.installInto(module);
  abController = open_address_book_window();
  gTestBook = MailServices.ab.getDirectory(uri);
  createTestEDSCards();
}

function createTestEDSCards() {

  const FIRST_NAMES = ["Alice", "Bob", "Connor", "Denise",
                       "Edward", "Freida"];

  const LAST_NAMES = ["Anway", "Baker", "Creevey", "Dell",
                      "Ecker", "Fanshawe"];

  const EMAIL = ["alice@anway.com", "bob@baker.net", "denise@dell.ca",
                 "Edward.Ecker@Ecker.on.ca", "freida+fanshawe@gmail.com"];

  for (let i = 0; i < FIRST_NAMES.length; i++) {
    let c = create_contact(EMAIL[i], FIRST_NAMES[i] + " " + LAST_NAMES[i]);
    c.setProperty("FirstName", FIRST_NAMES[i]);
    c.setProperty("LastName", LAST_NAMES[i]);

    let edsCard = gTestBook.addCard(c);
    if (!(edsCard instanceof Components.interfaces.nsIAbEDSCard))
      throw("Did not get back an EDS Card");

    edsCard.commit();
  }
}

function teardownModule(module) {
  let result = LibESourceGroup.removeSource(gESourceGroup, gESource);
  if (!result)
    dump("Could not destroy test address book!  You'll have to do it"
          + " manually.");


  let errPtr = new LibGLib.GError.ptr();
  let client = ctypes.cast(gEBookClient, LibEClient.EClient.ptr);
  result = LibEClient.removeSync(client, null, errPtr.address());

  if (!result) {
    let msg = errPtr.contents.message.readString();
    dump("\n\n\nCould not remove EBookClient - message was: " + msg + "\n\n");
  }

  LibGLib.g_object_unref(gEBookClient);
  gEBookClient = null;
}

function setupTest(test)
{
}

function teardownTest(test)
{
}

function testSomething() {
  gTestBook.dirName = "Changed Name";
  assert_true(true);
}
