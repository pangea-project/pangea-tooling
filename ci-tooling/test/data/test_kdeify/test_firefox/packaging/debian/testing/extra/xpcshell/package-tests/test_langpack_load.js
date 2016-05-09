Cu.import("resource://gre/modules/AddonManager.jsm");

function run_test()
{
  createAppInfo();

  Cc["@mozilla.org/addons/integration;1"].getService(Ci.nsIObserver).observe(null, "addons-startup", null);
  do_test_pending();

  let istream = Services.io.newChannelFromURI(Services.io.newFileURI(do_get_file("data/locales.shipped"))).open();

  let line = { value: "" };
  let locales = {};
  while (istream.readLine(line)) {
    if (!line.value.match(/^\s*#.*/)) {
      locales[line.value.replace(/^([^:]*).*/, "$1")] = false;
    }
  }

  AddonManager.getAddonsByTypes(["locale"], function(addons) {
    let re = /langpack-([a-zA-Z\-]+)@firefox.mozilla.org/;

    addons.forEach(function(addon) {
      let m = addon.id.match(re);
      if (!m) {
        return;
      }

      if (m[1] in locales && !addon.appDisabled) {
        locales[m[1]] = true;
      }
    });

    Object.keys(locales).forEach(function(locale) {
      do_print("Checking if the addon manager found a language pack for " + locale);
      do_check_true(locales[locale]);
    });

    do_test_finished();
  });
}
