#!/bin/bash
set -e
set -o pipefail

if [[ -z "$PAGES_BRANCH" ]]; then
    echo "Set the PAGES_BRANCH env variable."
    exit 1
fi

if [[ -z "$TARGET_REPOSITORY" ]]; then
    echo "Set the TARGET_REPOSITORY env variable."
    exit 1
fi

if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="."
fi

if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="public"
fi

if [[ -z "$BUILD_ONLY" ]]; then
    BUILD_ONLY=false
fi

if [[ -z "$BUILD_THEMES" ]]; then
    BUILD_THEMES=true
fi

if [[ -z "$CHECK_LINKS" ]]; then
    CHECK_LINKS=false
fi

if [[ -z "$GITHUB_TOKEN" ]] && [[ "$BUILD_ONLY" == false ]]; then
    echo "Set the GITHUB_TOKEN or TOKEN env variables."
    exit 1
fi

if [[ -z "$GITHUB_HOSTNAME" ]]; then
    GITHUB_HOSTNAME="github.com"
fi

main() {
    echo "Installing zola"
    wget -q -O - "https://github.com/getzola/zola/releases/download/v0.16.1/zola-v0.16.1-x86_64-unknown-linux-gnu.tar.gz" | tar xzf - -C /usr/local/bin
    echo "Starting deploy..."

    echo "GITHUB_SERVER_URL: $GITHUB_SERVER_URL"
    echo "GITHUB_HOSTNAME: $GITHUB_HOSTNAME"
    echo "TARGET_REPOSITORY: $TARGET_REPOSITORY"


    git config --global url."https://".insteadOf git://
    git config --global url."$GITHUB_SERVER_URL/".insteadOf "git@${GITHUB_HOSTNAME}":
    if [[ "$BUILD_THEMES" ]]; then
        echo "Fetching themes"
        git submodule update --init --recursive
    fi

    version=$(zola --version)
    remote_repo="https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@${GITHUB_HOSTNAME}/${TARGET_REPOSITORY}.git"
    remote_branch=$PAGES_BRANCH

    echo "Using $version"

    echo "Building in $BUILD_DIR directory"
    cd "$BUILD_DIR"

    echo Building with flags: ${BUILD_FLAGS:+"$BUILD_FLAGS"}
    zola build ${BUILD_FLAGS:+$BUILD_FLAGS}

    if ${CHECK_LINKS}; then
        echo "Checking links with flags: ${CHECK_FLAGS:+$CHECK_FLAGS}"
        zola check ${CHECK_FLAGS:+$CHECK_FLAGS}
    fi

    if ${BUILD_ONLY}; then
        echo "Build complete. Deployment skipped by request"
        exit 0
    else
        echo "Pushing artifacts to ${TARGET_REPOSITORY}:$remote_branch"

        cd "${OUT_DIR}"
        git init
        git config user.name "GitHub Actions"
        git config user.email "github-actions-bot@users.noreply.${GITHUB_HOSTNAME}"
        git add .

        git commit -m "Deploy ${TARGET_REPOSITORY} to ${TARGET_REPOSITORY}:$remote_branch"
        git push --force "${remote_repo}" master:"${remote_branch}"

        echo "Deploy complete"
    fi
}

main "$@"
