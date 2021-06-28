
# Definitive newline here ^. If the original script didn't have a terminal newline
# we'd otherwise append to another method call.

# SPDX-FileCopyrightText: 2018-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: BSD-2-Clause

function(kcrash_validator_get_subs output dir)
    # NB: the same function has the same scope if called recursively.
    get_property(_subs DIRECTORY ${dir} PROPERTY SUBDIRECTORIES)
    foreach(sub ${_subs})
        kcrash_validator_get_subs(${output} ${sub})
    endforeach()
    set(${output} ${${output}} ${_subs} PARENT_SCOPE)
endfunction()

function(kcrash_validator_check_all_targets)
    set(linked_types "MODULE_LIBRARY;EXECUTABLE;SHARED_LIBRARY")

    kcrash_validator_get_subs(subs .)
    foreach(sub ${subs})
        # List of all tests in this directory. Only available in cmake 3.12 (we always have that since 20.04).
        # These will generally (maybe even always?) have the same name as the target.
        get_property(_tests DIRECTORY ${sub} PROPERTY TESTS)
        # All targets in this directory.
        get_property(targets DIRECTORY ${sub} PROPERTY BUILDSYSTEM_TARGETS)
        foreach(target ${targets})
            # Is a linked type (executable/lib)
            get_target_property(target_type ${target} TYPE)
            list(FIND linked_types ${target_type} linked_type_index)
            if(${linked_type_index} LESS 0)
                continue()
            endif()

            # Filter tests
            # NB: cannot use IN_LIST condition because it is policy dependant
            #   and we do not want to change the policy configuration
            list(FIND _tests ${target} target_testlib_index)
            if(${target_testlib_index} GREATER -1)
                continue()
            endif()

            # Is part of all target
            get_target_property(target_exclude_all ${target} EXCLUDE_FROM_ALL)
            if(${target_exclude_all})
                continue()
            endif()

            set(_is_test OFF)
            set(_links_kcrash OFF)
            set(_versions ";5;6") # this must be a var or IN LISTS won't work. Unversioned is a valid option!
            foreach(_version IN LISTS _versions)
                # Wants KCrash
                # NB: cannot use IN_LIST condition because it is policy dependant
                #   and we do not want to change the policy configuration
                get_target_property(target_libs ${target} LINK_LIBRARIES)
                list(FIND target_libs "KF${_version}::Crash" target_lib_index)
                if(${target_lib_index} GREATER -1)
                    set(_links_kcrash ON)
                endif()
                # Filter tests... again.
                # This further approximates test detection. Unfortunately tests aren't always add_test() and don't
                # appear in the TESTS property. So we also check if the target at hand links qtest and if that is the
                # case skip it. Production targets oughtn't ever use qtest and that assumption is likely true 99% of
                # the time (and for the case when it is not true I'd consider it a bug that qtest is linked at all).
                list(FIND target_libs "Qt${_version}::Test" target_testlib_index)
                if(${target_testlib_index} GREATER -1)
                    set(_is_test ON)
                endif()
            endforeach()
            if(_is_test OR NOT _links_kcrash)
                continue()
            endif()

            message("KCrash validating: ${target}")
            add_custom_target(objdump-kcrash-${target} ALL
                COMMAND echo "  $<TARGET_FILE:${target}>"
                COMMAND objdump -p $<TARGET_FILE:${target}> | grep NEEDED | grep libKF5Crash.so
                DEPENDS ${target}
                COMMENT "Checking if target linked KCrash: ${target}")
        endforeach()
    endforeach()
endfunction()

kcrash_validator_check_all_targets()
