#!/bin/bash

set -eux


if [ -z ${PREFIX+x} ]; then
	export PREFIX="$HOME/.local"
fi

if [ "$HOST_OS" = "Linux" ]; then
	EXT=".a"
elif [ "$HOST_OS" = "macOS" ]; then
	EXT=".dylib"
else
	echo "unrecognized host"
	exit 1
fi


mkdir -p $HOME/.local/bin

asdf_retry() {
	cmd=$*
	$cmd || (sleep 2 && $cmd) || (sleep 10 && $cmd)
}

fetch_solc_linux() {
	VER="$1"
	if [ ! -f "$HOME/.local/bin/solc-$VER" ]; then
		rm -Rf solc-static-linux
		wget "https://github.com/ethereum/solidity/releases/download/v$VER/solc-static-linux"
		chmod +x solc-static-linux
		mv solc-static-linux "$HOME/.local/bin/solc-$VER"
		echo "Downloaded solc $VER"
	else
		echo "Skipped solc $VER, already present"
	fi
}

fetch_solc_macos() {
	VER="$1"
	if [ ! -f "$HOME/.local/bin/solc-$VER" ]; then
		rm -Rf solc-macos
		wget "https://github.com/ethereum/solidity/releases/download/v$VER/solc-macos"
		chmod +x solc-macos
		mv solc-macos "$HOME/.local/bin/solc-$VER"
		echo "Downloaded solc $VER"
	else
		echo "Skipped solc $VER, already present"
	fi
}

if [ "$HOST_OS" = "Linux" ]; then
	if [ "${SOLC_VER:-}" == "" ]; then
		asdf_retry fetch_solc_linux "0.8.7"
	else
		asdf_retry fetch_solc_linux "$SOLC_VER"
	fi
else
	if [ "${SOLC_VER:-}" == "" ]; then
		asdf_retry fetch_solc_macos "0.8.7"
	else
		asdf_retry fetch_solc_macos "$SOLC_VER"
	fi
fi
