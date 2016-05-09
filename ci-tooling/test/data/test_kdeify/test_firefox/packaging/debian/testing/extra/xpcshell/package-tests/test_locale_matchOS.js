gLocales = {
  "en_US.UTF-8": "en-US",
  "fr_FR.UTF-8": "fr",
  "fr_BE.UTF-8": "fr",
  "pt_BR.UTF-8": "pt-BR",
  "en_GB.UTF-8": "en-GB",
  "en_ZM.UTF-8": "en-[A-Z][A-Z]",
  "es_ES.UTF-8": "es-ES",
  "es_MX.UTF-8": "es-MX",
  "es_PY.UTF-8": "es-[A-Z][A-Z]"
};

function do_test(aLocale, aCallback)
{
  do_test_pending();
  do_print("Starting test for " + aLocale);
  do_run_test_in_subprocess_with_params("test_locale_matchOS_real.js",
                                        { "_TEST_SELECTED_LOCALE": gLocales[aLocale] },
                                        { "LC_ALL": aLocale },
                                        function(aSuccess) {
    do_check_true(aSuccess);
    do_print("Finished test for " + aLocale);
    aCallback();
    do_test_finished();
  });
}

function run_test()
{
  _XPCSHELL_PROCESS = "parent";

  try {
    do_check_true(Services.prefs.getBoolPref("intl.locale.matchOS"));
  } catch(e) {
    do_check_true(false);
  }

  run_tests_async(Object.keys(gLocales), do_test);
}
