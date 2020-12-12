#!/bin/bash

USERNAME=${1:-vscode}

if [ -z $HOME ]; then
    HOME="/root"
fi

FAILED=()

check() {
    LABEL=$1
    shift
    echo -e "\n🧪 Testing $LABEL"
    if "$@"; then 
        echo "✅  Passed!"
        return 0
    else
        echo "❌ $LABEL check failed."
        FAILED+=("$LABEL")
        return 1
    fi
}

checkMultiple() {
    PASSED=0
    LABEL="$1"
    echo -e "\n🧪 Testing $LABEL."
    shift; MINIMUMPASSED=$1
    shift; EXPRESSION="$1"
    while [ "$EXPRESSION" != "" ]; do
        if $EXPRESSION; then ((PASSED++)); fi
        shift; EXPRESSION=$1
    done
    if [ $PASSED -ge $MINIMUMPASSED ]; then
        echo "✅ Passed!"
        return 0
    else
        echo "❌ $LABEL check failed."
        FAILED+=("$LABEL")
        return 1
    fi
}

checkOSPackages() {
    LABEL=$1
    shift
    echo -e "\n🧪 Testing $LABEL"
    if apk info -e "$@"; then 
        echo "✅  Passed!"
        return 0
    else
        echo "❌ $LABEL check failed."
        FAILED+=("$LABEL")
        return 1
    fi
}

checkExtension() {
    # Happens asynchronusly, so keep retrying 10 times with an increasing delay
    EXTN_ID="$1"
    TIMEOUT_SECONDS="${2:-10}"
    RETRY_COUNT=0
    echo -e -n "\n🧪 Looking for extension $1 for maximum of ${TIMEOUT_SECONDS}s"
    until [ "${RETRY_COUNT}" -eq "${TIMEOUT_SECONDS}" ] || \
        [ ! -e $HOME/.vscode-server/extensions/${EXTN_ID}* ] || \
        [ ! -e $HOME/.vscode-server-insiders/extensions/${EXTN_ID}* ] || \
        [ ! -e $HOME/.vscode-test-server/extensions/${EXTN_ID}* ] || \
        [ ! -e $HOME/.vscode-remote/extensions/${EXTN_ID}* ]
    do
        sleep 1s
        (( RETRY_COUNT++ ))
        echo -n "."
    done

    if [ ${RETRY_COUNT} -lt ${TIMEOUT_SECONDS} ]; then
        echo -e "\n✅ Passed!"
        return 0
    else
        echo -e "\n❌ Extension $EXTN_ID not found."
        FAILED+=("$LABEL")
        return 1
    fi
}

checkCommon()
{
    PACKAGE_LIST="git \
        openssh-client \
        gnupg \
        procps \
        lsof \
        htop \
        net-tools \
        psmisc \
        curl \
        wget \
        rsync \
        ca-certificates \
        unzip \
        zip \
        nano \
        vim \
        less \
        jq \
        libgcc \
        libstdc++ \
        krb5-libs \
        libintl \
        libssl1.1 \
        lttng-ust \
        tzdata \
        userspace-rcu \
        zlib \
        sudo \
        coreutils \
        sed \
        grep \
        which \
        ncdu \
        shadow \
        strace \
        man-pages"

    # Actual tests
    checkOSPackages "common-os-packages" ${PACKAGE_LIST}
    checkMultiple "vscode-server" 1 "[ -d $HOME/.vscode-server/bin ]" "[ -d $HOME/.vscode-server-insiders/bin ]" "[ -d $HOME/.vscode-test-server/bin ]" "[ -d $HOME/.vscode-remote/bin ]" "[ -d $HOME/.vscode-remote/bin ]"
    check "non-root-user" id ${USERNAME}
    check "locale" [ $(locale -a | grep en_US.utf8) ]
    check "sudo" sudo echo "sudo works."
    check "zsh" zsh --version
    check "oh-my-zsh" [ -d "$HOME/.oh-my-zsh" ]
    check "login-shell-path" [ "$(bash -c 'echo $PATH')" = "$(bash -lc 'echo $PATH')" ]
    check "code" bash -i -c "code --version"
}

reportResults() {
    if [ ${#FAILED[@]} -ne 0 ]; then
        echo -e "\n💥  Failed tests: ${FAILED[@]}"
        exit 1
    else 
        echo -e "\n💯  All passed!"
        exit 0
    fi
}