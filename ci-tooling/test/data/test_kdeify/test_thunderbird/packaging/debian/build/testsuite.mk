#!/usr/bin/make -f

MOZ_TEST_LOCALE ?= en_US.UTF-8

MOZ_TESTS ?= check xpcshell-tests-build
#ifneq (,$(filter amd64 i386,$(DEB_HOST_ARCH)))
#MOZ_TEST_FAILURES_FATAL ?= 1
#endif

MOZ_TEST_X_WRAPPER ?= xvfb-run -a -s "-screen 0 1024x768x24" dbus-launch --exit-with-session
MOZ_TESTS_NEED_X ?= xpcshell-tests xpcshell-tests-build jstestbrowser reftest crashtest mochitest

MOZ_TESTS_TZ_ENV ?= TZ=:/usr/share/zoneinfo/posix/US/Pacific
MOZ_TESTS_NEED_TZ ?= check jstestbrowser

MOZ_TESTS_NEED_LOCALE ?= xpcshell-tests jstestbrowser reftest

TEST_LOCALES = $(CURDIR)/$(MOZ_OBJDIR)/_ubuntu_build_test_tmp/locales
TEST_HOME = $(CURDIR)/$(MOZ_OBJDIR)/_ubuntu_build_test_tmp/home

GET_WRAPPER = $(if $(filter $(1),$(MOZ_TESTS_NEED_X)),$(MOZ_TEST_X_WRAPPER))
GET_TZ = $(if $(filter $(1),$(MOZ_TESTS_NEED_TZ)),$(MOZ_TESTS_TZ_ENV))

DOIF_NEEDS_LOCALE = $(if $(filter $(1),$(MOZ_TESTS_NEED_LOCALE)),$(call $(2)))
MAKE_LOCALE = $(TEST_LOCALES)/$(MOZ_TEST_LOCALE)
GET_LOCALE_ENV = LOCPATH=$(TEST_LOCALES) LC_ALL=$(MOZ_TEST_LOCALE)

ifneq (1,$(MOZ_TEST_FAILURES_FATAL))
CMD_APPEND = || true
endif

ifneq (1,$(MOZ_WANT_UNIT_TESTS))
MOZ_TESTS =
endif

$(TEST_LOCALES) $(TEST_HOME)::
	mkdir -p $@

$(TEST_LOCALES)/$(MOZ_TEST_LOCALE): $(TEST_LOCALES)
	localedef -f $(shell echo $(notdir $@) | cut -d '.' -f 2) -i $(shell echo $(notdir $@) | cut -d '.' -f 1) $@

run-tests: $(MOZ_TESTS)

$(MOZ_TESTS):: %: debian/stamp-test-%

$(patsubst %,debian/stamp-test-%,$(MOZ_TESTS)):: TZ=$(call GET_TZ,$*)
$(patsubst %,debian/stamp-test-%,$(MOZ_TESTS)):: WRAPPER=$(call GET_WRAPPER,$*)
$(patsubst %,debian/stamp-test-%,$(MOZ_TESTS)):: $(call DOIF_NEEDS_LOCALE,$*,MAKE_LOCALE)
$(patsubst %,debian/stamp-test-%,$(MOZ_TESTS)):: LOCALE_ENV=$(call DOIF_NEEDS_LOCALE,$*,GET_LOCALE_ENV)
$(patsubst %,debian/stamp-test-%,$(MOZ_TESTS)):: $(TEST_HOME)
$(patsubst %,debian/stamp-test-%,$(MOZ_TESTS)):: TEST_CMD=HOME=$(TEST_HOME) $(LOCALE_ENV) $(TZ) $(WRAPPER) $(if $(findstring -build,$*),debian/rules run-$*,$(MAKE) -C $(CURDIR)/$(MOZ_OBJDIR) $*)
$(patsubst %,debian/stamp-test-%,$(MOZ_TESTS)):: debian/stamp-test-%: debian/stamp-makefile-build
	@echo "\nRunning $(TEST_CMD)\n"
	$(TEST_CMD) $(CMD_APPEND)
	touch $@

$(CURDIR)/$(MOZ_OBJDIR)/$(MOZ_MOZDIR)/_tests/xpcshell/xpcshell-build.ini:
	cp $(CURDIR)/debian/testing/xpcshell-build.ini $@

run-xpcshell-tests-build: $(CURDIR)/$(MOZ_OBJDIR)/$(MOZ_MOZDIR)/_tests/xpcshell/xpcshell-build.ini
	cd $(CURDIR)/$(MOZ_OBJDIR)/$(MOZ_MOZDIR); \
	PYTHONDONTWRITEBYTECODE=1 $(MOZ_PYTHON) -u $(CURDIR)/$(MOZ_MOZDIR)/config/pythonpath.py \
	  -I./build \
	  -I$(CURDIR)/$(MOZ_MOZDIR)/build \
	  -I./_tests/mozbase/mozinfo \
	  $(CURDIR)/$(MOZ_MOZDIR)/testing/xpcshell/runxpcshelltests.py \
	  --manifest=$(CURDIR)/$(MOZ_OBJDIR)/$(MOZ_MOZDIR)/_tests/xpcshell/xpcshell-build.ini \
	  --build-info-json=./mozinfo.json \
	  --no-logfiles \
	  --tests-root-dir=$(CURDIR)/$(MOZ_OBJDIR)/$(MOZ_MOZDIR)/_tests/xpcshell \
	  --testing-modules-dir=$(CURDIR)/$(MOZ_OBJDIR)/$(MOZ_MOZDIR)/_tests/modules \
	  $(CURDIR)/$(MOZ_DISTDIR)/bin/xpcshell

.PHONY: run-tests $(MOZ_TESTS) run-xpcshell-tests-build
