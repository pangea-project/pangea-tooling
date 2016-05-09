function run_test()
{
  do_check_true(!!_SEARCHPLUGIN_TEST_LOCALE);
  _XPCSHELL_PROCESS = "child-" + _SEARCHPLUGIN_TEST_LOCALE;

  //Services.prefs.setBoolPref("browser.search.log", true);
  Services.prefs.setCharPref("general.useragent.locale", _SEARCHPLUGIN_TEST_LOCALE);
  createAppInfo({id: "xpcshell@tests.mozilla.org", version: "1", platformVersion: "1"});

  let expected = 0;

  let locations = Services.dirsvc.get("SrchPluginsDL", Ci.nsISimpleEnumerator);

  while (locations.hasMoreElements()) {
    let location = locations.getNext().QueryInterface(Ci.nsIFile);
    let entries = location.directoryEntries;
    while (entries.hasMoreElements()) {
      entries.getNext();
      expected++;
    }
  }

  do_test_pending();

  Services.search.init({
    onInitComplete: function(aStatus) {
      do_check_true(Components.isSuccessCode(aStatus));

      // Check that all of the files in the searchplugin directories
      // are valid search plugins
      do_check_eq(Services.search.getEngines().length, expected);

      do_test_finished();
    }
  });
}
