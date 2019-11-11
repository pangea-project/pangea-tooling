# General

|Variable|Description|
|--------|-----------|
|DEBFULLNAME|Standard for packager name (changelogs, control etc.)|
|DEBEMAIL|Standard for packager email (see DEBFULLNAME)|
|NOMANGLE_MAINTAINER|Do not adjust control file to show DEBFULLNAME as maintainer|
|TYPE|Build permutation (unstable, stable etc.). Often also used to derive repository names.|
|DIST|Distribution codename (e.g. xenial)|
|PANGEA_TEST_EXECUTION|Set by test suite to switch some code paths into simulation mode|
|PANGEA_DOCKER_NO_FLATTEN|Prevents docker maintenance from flattening the created image. This is faster but consumes more disk AND there is a limit to how much history docker can keep on an image, if it is exceeded image creation fails.|
|DOCKER_ENV_WHITELIST|Whitelists environment variables for automatic forwarding into Docker containers.|
|PANGEA_PROVISION_AUTOINST|Enables os-autoinst provisioning in docker images.|
|SSH_KEY_FILE|Standard variable to pass key file paths into tooling (not suported by everything). This is used to pass Jenkins secrets around, the variable is then used by the tooling to adjust SSH/GIT to pick the correct key file|
|PANGEA_MAIL_CONFIG_PATH|Path to mail config yaml for pangea/mail.rb|
|PANGEA_UNDER_TEST|Set during test runs. Only should used if code paths need disabling during tests. Check with Harald before using it.|
|PANGEA_DOCKER_IMAGE|NCI only. Allows forcing a specific docker image (by name) to be used by contain.rb
|PANGEA_ARCH_BIN_ONLY|true/false. Default: true. Controls whether to perform bin_only builds on !arch:all architecutres (i.e. !amd64)|

# Job (aka Project) updates

|Variable|Description|
|--------|-----------|
|UPDATE_INCLUDE|Limits jenkins jobs getting updated during updater runs. Useful to speed things up when only a specific job needs pushing to jenkins. Values is a string that is checked with `.include?` against all jobs.|
|NO_UPDATE|Disables `git fetch`, `bzr update` etc.. New projects are still cloned, but existing ones will not get updated. This must be used with care as it can revert jobs to an early config for example WRT dependency linking. Useful to speed things up when running a job update within a short time frame.|
|PANGEA_FACTORY_THREADS|Overrides maximum thread count for project factorization. Can potentially improve `git fetch` speed by spreading IO-waiting across multiple threads. Note that Ruby's GIL can get in the way and more threads aren't necessarily faster! Careful with KDE servers, they reject connections from the same host exceeding a certain limit.|
|PANGEA_FACTORIZE_ONLY|Partial string of projects to factorize, this can be used to only git update a selected repo. Best not use, there's lots of caveats you have to be aware of.|
