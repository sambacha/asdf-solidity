#!/usr/bin/env bash

set -euo pipefail

# @test - Ensure this is the correct GitHub homepage where releases can be downloaded for solidity.
GH_REPO="https://github.com/ethereum/solidity"

# @test - catch failure, end process 
fail() {
  echo -e "asdf-solidity: $*"
  exit 1
}

curl_opts=(-fsSL)

# @dev: You might want to remove this if solidity is not hosted on GitHub releases,
# soliditylang.org has just recently launched, and github releases for solc-bin will be stopped
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

# @dev LC_ALL=C sort sane
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # @dev need to remove non-version strings from tags, as there are some outputted by this sort method. if we sort by `name` does not happen
}

list_all_versions() {
  # TODO: Adapt this. By default we simply list the tag names from GitHub releases.
  # Change this function if solidity has other means of determining installable versions.
  list_github_tags
}

# @download_release
download_release() {
  local version filename url
  version="$1"
  filename="$2"

  # @macos 
  # https://github.com/ethereum/solidity/v0.6.10/solc-macos
  # [solc-macos] Adapts the release URL convention for solidity specific for Mac OS X
  url="$GH_REPO/releases/download/v${version}/solc-macos"
  echo "* Downloading solidity release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

# @install_version
install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-solidity supports release installs only"
  fi

  # TODO: Adapt this to proper extension and adapt extracting strategy.
  local release_file="$install_path/solidity-$version.tar.gz"
  (
    mkdir -p "$install_path"
    download_release "$version" "$release_file"
    
#    TODO: Build from source option, for now, only static binaries
#    tar -xzf "$release_file" -C "$install_path" --strip-components=1 || fail "Could not extract $release_file"
#    rm "$release_file"

    # TODO: Asert solidity executable exists.
    local tool_cmd
    tool_cmd="$(echo "svm --version" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "solidity $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing solidity $version."
  )
}
