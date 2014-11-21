#!/bin/sh

set -e

export PATH=/var/lib/jenkins/tooling:$PATH
export GIT_TARGET_BRANCH=kubuntu_unstable
export GIT_TARGET=origin/$GIT_TARGET_BRANCH

echo ":: triggered by ${GIT_BRANCH}"
echo ":: static target ${GIT_TARGET}"

cleanup() {
    rm -fv .gitattributes || true
    rm -fv $HOME/.gitconfig || true
    exit 1
}
trap cleanup 1 2 3 6

git_config=$HOME/.gitconfig
echo "writing .gitconfig to ${git_config}"
cat << EOF > $git_config
[merge "dpkg-mergechangelogs"]
    name = debian/changelog merge driver
    driver = dpkg-mergechangelogs -m %O %A %B %A
EOF

# Only do work on branches we care about. We do however merge all of them in order.
if [ "${GIT_BRANCH}" = "origin/master" ] || [ "${GIT_BRANCH}" = "origin/kubuntu_vivid_archive" ] || [ "${GIT_BRANCH}" = "origin/kubuntu_unstable" ]; then
    git fetch origin
    git clean -fd || true
    git checkout -f remotes/${GIT_TARGET}
    
    echo "debian/changelog merge=dpkg-mergechangelogs" > .gitattributes

    # We merge all inteneded merge origins. Point being that we need all branches merged
    # to get reliable nonesense.
    echo ":: merging master"
    git merge origin/master
    
    if [ ! -z $(git for-each-ref --format='%(refname)' refs/remotes/origin/kubuntu_vivid_archive) ]; then
        # only merge vivid if it exists on remote to prevent fail-on-merge for new repos etc.
        echo ":: merging vivid_archive"
        git merge origin/kubuntu_vivid_archive
    fi

    if [ -e debian/patches ]; then
        export QUILT_PATCHES=debian/patches
        for p in $(quilt series | grep -P "^debian/patches/upstream_.*"); do
            quilt delete -r ${p} # This should not fail really.
        done
        if [ "$(quilt series)" = "" ]; then
            git rm -r debian/patches
        fi
        git status
        if ! git diff-files --quiet; then
            git commit -a -m "Auto-removing upstream patches."
        fi
    fi

    git push origin HEAD:${GIT_TARGET_BRANCH}

    # Now merge us into descendents
    for descendent in $(git for-each-ref --format='%(refname)' refs/remotes/${GIT_TARGET}_\*); do
        echo ":: trying to merge into descendent: ${descendent}"
        git checkout ${descendent}
        git merge ${GIT_TARGET}
        git push origin HEAD:$(basename ${descendent})
    done
fi
