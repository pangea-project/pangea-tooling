const TEST_MATRIX = {
//  Locale      Amazon?   Baidu?    DDG?    Google?
    "en-US":  [ true,     false,    true,   true ],
    "af":     [ true,     false,    true,   true ],
    "ar":     [ true,     false,    true,   true ],
    "as":     [ true,     false,    true,   true ],
    "ast":    [ false,    false,    true,   true ],
    "be":     [ false,    false,    true,   true ],
    "bg":     [ true,     false,    true,   true ],
    "bn-BD":  [ false,    false,    true,   true ],
    "bn-IN":  [ true,     false,    true,   true ],
    "br":     [ true,     false,    true,   true ],
    "bs":     [ false,    false,    true,   true ],
    "ca":     [ false,    false,    true,   true ],
    "cs":     [ false,    false,    true,   true ],
    "csb":    [ false,    false,    true,   true ],
    "cy":     [ true,     false,    true,   true ],
    "da":     [ true,     false,    true,   true ],
    "de":     [ true,     false,    true,   true ],
    "el":     [ true,     false,    true,   true ],
    "en-GB":  [ true,     false,    true,   true ],
    "en-ZA":  [ true,     false,    true,   true ],
    "eo":     [ true,     false,    true,   true ],
    "es-AR":  [ true,     false,    true,   true ],
    "es-CL":  [ false,    false,    true,   true ],
    "es-ES":  [ false,    false,    true,   true ],
    "es-MX":  [ false,    false,    true,   true ],
    "et":     [ false,    false,    true,   true ],
    "eu":     [ true,     false,    true,   true ],
    "fa":     [ true,     false,    true,   true ],
    "fi":     [ false,    false,    true,   true ],
    "fr":     [ true,     false,    true,   true ],
    "fy-NL":  [ false,    false,    true,   true ],
    "ga-IE":  [ true,     false,    true,   true ],
    "gd":     [ true,     false,    true,   true ],
    "gl":     [ true,     false,    true,   true ],
    "gu-IN":  [ false,    false,    true,   true ],
    "he":     [ false,    false,    true,   true ],
    "hi-IN":  [ false,    false,    true,   true ],
    "hr":     [ true,     false,    true,   true ],
    "hu":     [ false,    false,    true,   true ],
    "hy-AM":  [ true,     false,    true,   true ],
    "id":     [ false,    false,    true,   true ],
    "is":     [ true,     false,    true,   true ],
    "it":     [ true,     false,    true,   true ],
    "ja":     [ true,     false,    true,   true ],
    "kk":     [ false,    false,    true,   true ],
    "km":     [ true,     false,    true,   true ],
    "kn":     [ true,     false,    true,   true ],
    "ko":     [ false,    false,    true,   true ],
    "ku":     [ true,     false,    true,   true ],
    "lg":     [ true,     false,    true,   true ],
    "lt":     [ true,     false,    true,   true ],
    "lv":     [ false,    false,    true,   true ],
    "mai":    [ false,    false,    true,   true ],
    "mk":     [ true,     false,    true,   true ],
    "ml":     [ false,    false,    true,   true ],
    "mn":     [ false,    false,    true,   true ],
    "mr":     [ true,     false,    true,   true ],
    "nb-NO":  [ true,     false,    true,   true ],
    "nl":     [ false,    false,    true,   true ],
    "nn-NO":  [ true,     false,    true,   true ],
    "nso":    [ true,     false,    true,   true ],
    "or":     [ true,     false,    true,   true ],
    "pa-IN":  [ false,    false,    true,   true ],
    "pl":     [ false,    false,    true,   true ],
    "pt-BR":  [ false,    false,    true,   true ],
    "pt-PT":  [ true,     false,    true,   true ],
    "ro":     [ true,     false,    true,   true ],
    "ru":     [ false,    false,    true,   true ],
    "si":     [ true,     false,    true,   true ],
    "sk":     [ false,    false,    true,   true ],
    "sl":     [ false,    false,    true,   true ],
    "sq":     [ true,     false,    true,   true ],
    "sr":     [ true,     false,    true,   true ],
    "sv-SE":  [ false,    false,    true,   true ],
    "sw":     [ true,     false,    true,   true ],
    "ta":     [ false,    false,    true,   true ],
    "te":     [ true,     false,    true,   true ],
    "th":     [ true,     false,    true,   true ],
    "tr":     [ true,     false,    true,   true ],
    "uk":     [ false,    false,    true,   true ],
    "vi":     [ false,    false,    true,   true ],
    "zh-CN":  [ true,     true,     true,   true ],
    "zh-TW":  [ false,    false,    true,   true ],
    "zu":     [ true,     false,    true,   true ]
};

const PLUGIN_AMAZON = 0;
const PLUGIN_BAIDU = 1;
const PLUGIN_DDG = 2;
const PLUGIN_GOOGLE = 3;

if (Services.prefs.getCharPref("app.update.channel") == "nightly") {
  TEST_MATRIX["bs"][PLUGIN_AMAZON] = true;
}

function get_query_params(aURL)
{
  let params = {};
  aURL.query.split('&').forEach(function(query) {
    let parts = query.split('=');
    do_check_eq(parts.length, 2);
    params[parts[0]] = parts[1];
  });

  return params;
}

function test_baidu(aEngine)
{
  let url = aEngine.getSubmission("foo").uri.QueryInterface(Ci.nsIURL);

  // We ship the upstream plugin for this one
  if (url.host == "zhidao.baidu.com") {
    return false;
  }

  let params = get_query_params(url);

  let ubuntu = "tn" in params && params["tn"] == "ubuntuu_cb" && "cl" in params && params["cl"] == 3;

  // We only expect to see our Baidu searchplugin
  do_check_true(ubuntu);

  return ubuntu;
}

function test_duckduckgo(aEngine)
{
  let url = aEngine.getSubmission("foo").uri.QueryInterface(Ci.nsIURL);

  let params = get_query_params(url);
  let ubuntu = "t" in params && params["t"] == "canonical";

  // We only expect to see our DDG searchplugin
  do_check_true(ubuntu);

  return ubuntu;
}

function test_amazon(aEngine)
{
  let url = aEngine.getSubmission("foo").uri.QueryInterface(Ci.nsIURL);

  let params = get_query_params(url);
  let ubuntu = "tag" in params && params["tag"] == "wwwcanoniccom-20";

  // We only expect to see our Amazon searchplugin
  do_check_true(ubuntu);

  return ubuntu;
}

function test_google(aEngine)
{
  let wanted = {
    "gl": {
      "en-GB": "uk",
      "en-ZA": "za"
    },
    "hl": {
      "ku": "en",
      "ja": "ja"
    }    
  };

  function check_extra_params() {
    for (let param in wanted) {
      do_check_eq(params[param], wanted[param][_SEARCHPLUGIN_TEST_LOCALE]);
    }
  }

  do_check_eq(Services.io.newURI(aEngine.searchForm, null, null).scheme, "https");

  let url = aEngine.getSubmission("foo").uri.QueryInterface(Ci.nsIURL);
  // Verify we are using a secure URL
  do_check_eq(url.scheme, "https");

  let params = get_query_params(url);

  let ubuntu = "client" in params && params["client"] == "ubuntu" && "channel" in params && params["channel"] == "fs";

  // We only expect to see our Google searchplugin
  do_check_true(ubuntu);

  check_extra_params();

  url = aEngine.getSubmission("foo", "application/x-suggestions+json").uri.QueryInterface(Ci.nsIURL);
  // Verify we are using a secure URL for suggestions
  do_check_eq(url.scheme, "https");

  params = get_query_params(url);

  // "client=ubuntu" fails for suggestions
  do_check_eq(params["client"], "firefox");

  check_extra_params();

  return ubuntu;
}

function run_test()
{
  do_check_true(!!_SEARCHPLUGIN_TEST_LOCALE);
  _XPCSHELL_PROCESS = "child-" + _SEARCHPLUGIN_TEST_LOCALE;

  //Services.prefs.setBoolPref("browser.search.log", true);
  Services.prefs.setCharPref("general.useragent.locale", _SEARCHPLUGIN_TEST_LOCALE);
  createAppInfo({id: "xpcshell@tests.mozilla.org", version: "1", platformVersion: "1"});

  let found_Google = false;
  let found_Amazon = false;
  let found_DDG = false;
  let found_Baidu = false;

  do_check_true(_SEARCHPLUGIN_TEST_LOCALE in TEST_MATRIX);

  let want_Amazon = TEST_MATRIX[_SEARCHPLUGIN_TEST_LOCALE][PLUGIN_AMAZON];
  let want_Baidu = TEST_MATRIX[_SEARCHPLUGIN_TEST_LOCALE][PLUGIN_BAIDU];
  let want_DDG = TEST_MATRIX[_SEARCHPLUGIN_TEST_LOCALE][PLUGIN_DDG];
  let want_Google = TEST_MATRIX[_SEARCHPLUGIN_TEST_LOCALE][PLUGIN_GOOGLE];

  do_test_pending();

  Services.search.init({
    onInitComplete: function(aStatus) {
      do_check_true(Components.isSuccessCode(aStatus));

      Services.search.getEngines().forEach(function(engine) {
        let host = engine.getSubmission("foo").uri.host;
        if (host.match(/\.google\./)) {
          let is_ours = test_google(engine);
          do_check_true(!(is_ours && found_Google));
          found_Google = is_ours || found_Google;
        } else if (host.match(/\.amazon\./)) {
          let is_ours = test_amazon(engine);
          do_check_true(!(is_ours && found_Amazon));
          found_Amazon = is_ours || found_Amazon;
        } else if (host.match(/duckduckgo\./)) {
          let is_ours = test_duckduckgo(engine);
          do_check_true(!(is_ours && found_DDG));
          found_DDG = is_ours || found_DDG;
        } else if (host.match(/baidu\./)) {
          let is_ours = test_baidu(engine);
          do_check_true(!(is_ours && found_Baidu));
          found_Baidu = is_ours || found_Baidu;
        }
      });

      do_check_true(!((found_Amazon && !want_Amazon) || (!found_Amazon && want_Amazon)));
      do_check_true(!((found_Baidu && !want_Baidu) || (!found_Baidu && want_Baidu)));
      do_check_true(!((found_DDG && !want_DDG) || (!found_DDG && want_DDG)));
      do_check_true(!((found_Google && !want_Google) || (!found_Google && want_Google)));

      do_test_finished();
    }
  });
}
