#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [--list | VERSION]"
    echo ""
    echo "           VERSION     switches the default version of solc to the specified version"
    echo ""
    echo "           --list, -l  lists all installed versions of solc"
    echo ""
    exit 1
fi

SOLC_INSTALL_DIR=/usr/bin
VERSION=$1

if [ "$VERSION" = "--list" ] || [ "$VERSION" = "-l" ]; then
    find $SOLC_INSTALL_DIR -name 'solc-v*' -printf "%f\n" | awk -F'v' '{print $2}' | sort
    exit 0
fi

SOLC_PATH=$SOLC_INSTALL_DIR/solc-v$VERSION

if [ ! -f "$SOLC_PATH" ]; then
    echo "Error: ${SOLC_PATH} does not exist!"
    echo ""
    echo "Please select one of the installed versions:"
    echo ""
    echo "$($0 --list)"
    exit 1
fi

ln -fs "$SOLC_PATH" "$HOME"/.local/bin/solc
