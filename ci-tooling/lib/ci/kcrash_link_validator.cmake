# Definitive newline here. If the original script didn't have a terminal newline
# we'd otherwise append to another method call.
function(kcrash_validator_get_subs output dir)
    # NB: the same function has the same scope if called recursively.
    get_property(_subs DIRECTORY ${dir} PROPERTY SUBDIRECTORIES)
    foreach(sub ${_subs})
        get_subs(${output} ${sub})
    endforeach()
    set(${output} ${${output}} ${_subs} PARENT_SCOPE)
endfunction()

function(kcrash_validator_check_all_targets)
    set(linked_types "MODULE_LIBRARY;EXECUTABLE;SHARED_LIBRARY")

    kcrash_validator_get_subs(subs .)
    foreach(sub ${subs})
        get_property(targets DIRECTORY ${sub} PROPERTY BUILDSYSTEM_TARGETS)
        foreach(target ${targets})
            # Is a linked type (exectuable/lib)
            get_target_property(target_type ${target} TYPE)
            list(FIND linked_types ${target_type} linked_type_index)
            if(${linked_type_index} LESS 0)
                continue()
            endif()

            # Wants KCrash
            get_target_property(target_libs ${target} LINK_LIBRARIES)
            list(FIND target_libs "KF5::Crash" target_lib_index)
            if(${target_lib_index} LESS 0)
                continue()
            endif()

            message("target: ${target}")
            add_custom_target(objdump-kcrash-${target} ALL
                COMMAND echo "  $<TARGET_FILE:${target}>"
                COMMAND objdump -p $<TARGET_FILE:${target}> | grep NEEDED | grep libKF5Crash.so
                DEPENDS ${target}
                COMMENT "Checking if target linked KCrash: ${target}")
        endforeach()
    endforeach()
endfunction()

kcrash_validator_check_all_targets()
