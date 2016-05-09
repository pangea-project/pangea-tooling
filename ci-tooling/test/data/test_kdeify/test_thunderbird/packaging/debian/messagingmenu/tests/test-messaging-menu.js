/* ***** BEGIN LICENSE BLOCK *****
 *   Version: MPL 1.1/GPL 2.0/LGPL 2.1
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
 * The Original Code is Messaging Menu Extension.
 *
 * The Initial Developer of the Original Code is
 * the Mozilla Foundation.
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Mike Conley <mconley@mozillamessaging.com>
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

/*
 * Test that message reloads happen properly when the message pane is hidden,
 * and then made visible again.
 */
var MODULE_NAME = "test-messaging-menu";

var RELATIVE_ROOT = "../shared-modules";
var MODULE_REQUIRES = ["folder-display-helpers"];

var Indicator = null;
var msg = null;
var folder = null;
var msgSets = [];

var IndicatorMock = function()
{
  this.doIndications = [];
  this.stopIndications = [];
};

var doIndication = function(folderURL, label, messageURL, count,
                            dateInSeconds)
{
  Indicator.doIndications.push({folderURL: folderURL,
                                label: label,
                                count: count,
                                messageURL: messageURL,
                                dateInSeconds: dateInSeconds});
};

var stopIndication = function(folderURL)
{
  Indicator.stopIndications.push({folderURL: folderURL});
}


function setupModule(module)
{
  let fdh = collector.getModule('folder-display-helpers');
  fdh.installInto(module);
  folder = create_folder("Test folder");
}

function setupTest(test)
{
  if(Indicator)
    delete Indicator;
  Indicator = new IndicatorMock();
  mc.window.uMessagingMenu._doIndicationHook = doIndication;
  mc.window.uMessagingMenu._stopIndicationHook = stopIndication;
  be_in_folder(inboxFolder);
}

function teardownTest(test)
{
  for each (let msgSet in msgSets) {
    delete_message_set(msgSet);
  }
  msgSets = [];
}

function add_message_set_to_folder(aFolder, aNumToAdd)
{
  let [msgSet] = make_new_sets_in_folder(aFolder, [{count:aNumToAdd}]);
  msgSets.push(msgSet);
  return msgSet;
}

function test_new_inbox_mail_causes_indicate()
{
  add_message_set_to_folder(inboxFolder, 1);
  assert_equals(1, Indicator.doIndications.length);
}

function test_uninteresting_folders_do_not_indicate()
{
  let uninteresting = [Ci.nsMsgFolderFlags.Trash, Ci.nsMsgFolderFlags.Junk,
                       Ci.nsMsgFolderFlags.SentMail, Ci.nsMsgFolderFlags.Drafts,
                       Ci.nsMsgFolderFlags.Templates, Ci.nsMsgFolderFlags.Queue];

  for each (let folder_type in uninteresting) {
    folder.setFlag(folder_type);
    add_message_set_to_folder(folder, 1);
    assert_equals(0, Indicator.doIndications.length);
    folder.clearFlag(folder_type);
  }

}

function test_clicking_new_message_hides_indicator()
{
  add_message_set_to_folder(inboxFolder, 1);
  let msgHdr = select_click_row(0);
  open_selected_message();
  wait_for_message_display_completion(mc);
  assert_equals(1, Indicator.stopIndications.length);
}

function test_show_oldest_new_unread_message()
{
  let firstMsgSet = add_message_set_to_folder(inboxFolder, 1);
  let firstMsgURL = firstMsgSet.getMsgURI(0);
  add_message_set_to_folder(inboxFolder, 2);
  assert_equals(3, Indicator.doIndications.length);
  assert_equals(firstMsgURL, Indicator.doIndications[2].messageURL);
}

function test_indicates_new_unread_after_previous_indication()
{
  add_message_set_to_folder(inboxFolder, 1);
  select_click_row(0);
  let secondMsgSet = add_message_set_to_folder(inboxFolder, 1);
  let secondMsgURL = secondMsgSet.getMsgURI(0);

  assert_equals(2, Indicator.doIndications.length);
  assert_equals(1, Indicator.stopIndications.length);
  assert_equals(secondMsgURL, Indicator.doIndications[1].messageURL);
}


