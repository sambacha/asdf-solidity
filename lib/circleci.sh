#!/usr/bin/env bash
#source: https://github.com/ethereum/solc-bin/commit/1039e591ef19d782feb1729362177f94c65a15c3
#SPDX-License-Identifier: GPL-v3.0

set -e
set -o pipefail

default_source=circleci
default_solidity_version=latest

if [[ $1 == --help ]]; then
    echo "Downloads release binaries, puts them at the right locations in a local"
    echo "checkout of the solc-bin repository and updates the file lists."
    echo
    echo "WARNING: The binaries will be overwritten if they already exist."
    echo
    echo
    echo "Usage:"
    echo "    ./$(basename "$0") --help"
    echo "    ./$(basename "$0") [source] [solidity_version] [solc_bin_dir]"
    echo
    echo "    source           The source to get binaries from. Can be 'circleci' or 'github'."
    echo "                     Default: '${default_source}'."
    echo "    solidity_version Version tag representing the release to download, including"
    echo "                     the leading 'v'. Use 'latest' to get the most recent release."
    echo "                     In case of CircleCI 'latest' is the only supported value."
    echo "                     Default: '${default_solidity_version}'."
    echo "    solc_bin_dir     Location of the solc-bin checkout."
    echo "                     Default: current working directory."
    echo
    echo
    echo "Examples:"
    echo "    ./$(basename "$0") --help"
    echo "    ./$(basename "$0") circleci latest"
    echo "    ./$(basename "$0") github v0.6.9"
    echo "    ./$(basename "$0") github latest ~/solc-bin/"
    exit 0
fi


# GENERAL UTILITIES

query_api() {
    local api_endpoint="$1"

    curl --fail --silent --show-error "$api_endpoint"
}

die() {
    local format="$1"

    >&2 printf "ERROR: $format\n" "${@:2}"
    exit 1
}

is_wasm() {
    # Just a heuristic but it does match the expected release versions in solc-bin so far.
    grep --fixed-strings --silent 'var wasmBinaryFile="data:application/octet-stream;base64,AGFzbQEA' "$@" && return 0
    return 1
}

expect_single_line() {
    local text="$1"

    local line_count; line_count="$(echo "$text" | grep --count "")"
    [[ $text != "" ]] || die "Expected one line, got zero."
    (( $line_count < 2 )) || die "Expected one line, got %d:\n%s" "$line_count" "$text"
}


# JOB INFO FROM CIRCLECI API

filter_jobs_by_name() {
    local job_name="$1"
    jq '[ .[] | select (.workflows.job_name == "'"$job_name"'") ]'
}

select_latest_job_info() {
    # ASSUMPTION: Newer jobs always have higher build_num
    jq 'sort_by(.build_num) | last'
}


# ARTIFACT INFO FROM CIRCLECI API

filter_artifacts_by_name()  {
    local artifact_name="$1"

    jq '[ .[] | select (.path == "'"$artifact_name"'") ]'
}


# TAG INFO FROM GITHUB API

filter_only_version_tags()  {
    jq '.[] | select (.name | startswith("v"))'
}

filter_tags_by_commit()  {
    local commit_hash="$1"

    jq '[ . | select (.commit.sha == "'"$commit_hash"'") ]'
}

filter_tags_by_name()  {
    local tag_name="$1"

    jq '[ . | select (.name == "'"$tag_name"'") ]'
}


# RELEASE INFO FROM GITHUB API

filter_assets_by_name() {
    local name_regex="$1"

    jq '[ .assets[] | select(.name | test("'"${name_regex}"'")) ]'
}


# REPOSITORY STRUCTURE

target_to_job_name() {
    local target="$1"

    case "$target" in
        # FIXME: We don't have Windows or static Linux builds set up on CircleCI
        macosx-amd64) echo b_osx ;;
        emscripten)   echo b_ems ;;
        *) die "Invalid target: %s" "$target" ;;
    esac
}

target_to_circleci_artifact_name() {
    local target="$1"

    case "$target" in
        # FIXME: What would that be in case of Windows? A zip file or an executable?
        linux-amd64)  echo solc ;;
        macosx-amd64) echo solc ;;
        emscripten)   echo soljson.js ;;
        *) die "Invalid target: %s" "$target" ;;
    esac
}

target_to_github_artifact_regex() {
    local target="$1"

    case "$target" in
        linux-amd64)   echo '^(solc-static-linux|solc)$' ;;
        macosx-amd64)  echo '^solc-macos$' ;;
        windows-amd64) echo '^solidity-windows(-[0-9.]+)?\\.zip$' ;;
        emscripten)    echo '^soljson(-v[0-9.]+.*)?\\.js$' ;;
        *) die "Invalid target: %s" "$target" ;;
    esac
}

is_executable() {
    local target="$1"

    case "$target" in
        linux-amd64)   return 0 ;;
        macosx-amd64)  return 0 ;;
        windows-amd64) return 1 ;;
        emscripten)    return 1 ;;
        *) die "Invalid target: %s" "$target" ;;
    esac
}

format_binary_path() {
    local target="$1"
    local solidity_version="$2"
    local commit_hash="$3"

    short_hash="$(echo "$commit_hash" | head --bytes 8)"
    full_version="${solidity_version}+commit.${short_hash}"

    case "$target" in
        linux-amd64)       echo "${target}/solc-${target}-${full_version}" ;;
        macosx-amd64)      echo "${target}/solc-${target}-${full_version}" ;;
        windows-amd64)     echo "${target}/solc-${target}-${full_version}.zip" ;;
        emscripten-wasm32) echo "${target}/solc-${target}-${full_version}.js" ;;
        emscripten-asmjs)  echo "${target}/solc-${target}-${full_version}.js" ;;
        wasm)              echo "wasm/soljson-${full_version}.js" ;;
        bin)               echo "bin/soljson-${full_version}.js" ;;
        emscripten)        echo "bin/soljson-${full_version}.js" ;;
        *) die "Invalid target: %s" "$target" ;;
    esac
}


# MAIN LOGIC

query_circleci_artifact_url() {
    local target="$1"
    local build_num="$2"

    local artifact_endpoint="https://circleci.com/api/v1.1/project/github/ethereum/solidity/${build_num}/artifacts"
    local artifact_name; artifact_name="$(target_to_circleci_artifact_name "$target")"
    local artifact_url; artifact_url="$(
        query_api "$artifact_endpoint" |
        filter_artifacts_by_name "$artifact_name" |
        jq --raw-output '.[].url'
    )"
    expect_single_line "$artifact_url"

    echo "$artifact_url"
}

query_github_tag_info() {
    local endpoint="https://api.github.com/repos/ethereum/solidity/tags?per_page=100"

    local page=1
    local tag_info_list="$(query_api "${endpoint}&page=${page}")"
    while [[ $(echo "$tag_info_list" | jq '. | length') > 0 ]]; do
        echo "$tag_info_list"

        ((++page))
        local tag_info_list="$(query_api "${endpoint}&page=${page}")"
    done
}

download_binary() {
    local target_path="$1"
    local download_url="$2"

    # If the target exists we ovewrite it. As a special case, if it's a symlink, remove it
    # so that we only change link not the file it links to.
    [[ ! -L "$target_path" ]] || rm "$target_path"

    echo "Downloading release binary from ${download_url} into ${target_path}"
    curl "$download_url" --output "${target_path}" --location --no-progress-meter --create-dirs
}

download_binary_from_circleci() {
    local target="$1"
    local successful_jobs="$2"
    local tag_info="$3"
    local solc_bin_dir="$4"

    local job_name; job_name="$(target_to_job_name "$target")"
    local job_info; job_info="$(
        echo "$successful_jobs" |
        filter_jobs_by_name "$job_name" |
        select_latest_job_info
    )"
    echo "$job_info" | jq '{
        job_name: .workflows.job_name,
        build_url,
        stop_time,
        status,
        subject,
        vcs_revision,
        branch,
        author_date
    }'

    local build_num; build_num="$(echo "$job_info" | jq --raw-output '.build_num')"
    local commit_hash; commit_hash="$(echo "$job_info" | jq --raw-output '.vcs_revision')"

    local solidity_version; solidity_version="$(
        echo "$tag_info" |
        filter_tags_by_commit "$commit_hash" |
        jq --raw-output '.[].name'
    )"
    expect_single_line "$solidity_version"

    local artifact_url; artifact_url="$(query_circleci_artifact_url "$target" "$build_num")"
    local binary_path; binary_path="$(format_binary_path "$target" "$solidity_version" "$commit_hash")"
    download_binary "${solc_bin_dir}/${binary_path}" "$artifact_url"
    ! is_executable "$target" || chmod +x "${solc_bin_dir}/${binary_path}"

    if [[ $target == emscripten ]]; then
        disambiguate_emscripten_binary "$binary_path" "$solidity_version" "$commit_hash" "$solc_bin_dir"
    fi
}

download_binary_from_github() {
    local target="$1"
    local release_info="$2"
    local tag_info="$3"
    local solc_bin_dir="$4"

    local solidity_version; solidity_version="$(echo "$release_info" | jq --raw-output '.tag_name')"

    local commit_hash; commit_hash="$(
        echo "$tag_info" |
        filter_tags_by_name "$solidity_version" |
        jq --raw-output '.[].commit.sha'
    )"
    expect_single_line "$commit_hash"

    local asset_info; asset_info="$(echo "$release_info" | filter_assets_by_name "$(target_to_github_artifact_regex "$target")")"
    local artifact_url; artifact_url="$(echo "$asset_info" | jq --raw-output '.[].browser_download_url')"
    local asset_count; asset_count=$(echo "$artifact_url" | grep --count "")

    if [[ $artifact_url == "" ]]; then
        >&2 echo "WARNING: No artifact matching target '${target}' available in release ${solidity_version}."
    elif (( $asset_count >= 2 )); then
        local joined_asset_names; joined_asset_names="$(echo "$asset_info" | jq --raw-output '[ .[].name ] | join(", ")')"
        die "Expected at most one matching asset. Found %d: %s" "$asset_count" "$joined_asset_names"
    else
        local binary_path; binary_path="$(format_binary_path "$target" "$solidity_version" "$commit_hash")"
        download_binary "${solc_bin_dir}/${binary_path}" "$artifact_url"
        ! is_executable "$target" || chmod +x "${solc_bin_dir}/${binary_path}"

        if [[ $target == emscripten ]]; then
            disambiguate_emscripten_binary "$binary_path" "$solidity_version" "$commit_hash" "$solc_bin_dir"
        fi
    fi
}

disambiguate_emscripten_binary() {
    local binary_path="$1"
    local solidity_version="$2"
    local commit_hash="$3"
    local solc_bin_dir="$4"

    if is_wasm "${solc_bin_dir}/${binary_path}"; then
        local dest_path; dest_path="$(format_binary_path wasm "$solidity_version" "$commit_hash")"
        local emscripten_target=emscripten-wasm32

        echo "Smells like fresh wasm. Moving ${binary_path} to wasm/"
        mkdir -p "$(dirname "${solc_bin_dir}/${dest_path}")"
        mv "${solc_bin_dir}/${binary_path}" "${solc_bin_dir}/${dest_path}"
        ln --symbolic "../${dest_path}" "${solc_bin_dir}/${binary_path}"
    else
        local dest_path="$binary_path"
        local emscripten_target=emscripten-asmjs
    fi

    local emscripten_binary_path; emscripten_binary_path="$(format_binary_path "$emscripten_target" "$solidity_version" "$commit_hash")"
    echo "Creating or updating link: ${emscripten_binary_path} -> ${dest_path}"
    mkdir -p "$(dirname "${solc_bin_dir}/$emscripten_binary_path")"
    [[ ! -L "${solc_bin_dir}/$emscripten_binary_path" ]] || rm "${solc_bin_dir}/$emscripten_binary_path"
    ln --symbolic "../${dest_path}" "${solc_bin_dir}/${emscripten_binary_path}"
}

download_release() {
    local source="$1"
    local solidity_version="$2"
    local solc_bin_dir="$3"

    echo "===> DOWNLOADING RELEASE ${solidity_version} FROM ${source}"
    echo "solc-bin directory: ${solc_bin_dir}"

    echo "Getting tag info from github"
    local tag_info; tag_info="$(query_github_tag_info | filter_only_version_tags)"

    case "$source" in
        circleci)
            local release_targets=(
                # FIXME: We don't have Windows or static Linux builds set up on CircleCI
                #linux-amd64
                #windows-amd64
                macosx-amd64
                emscripten
            )

            [[ $solidity_version == latest ]] || die "Only getting the latest release is supported for CircleCI"

            local job_endpoint="https://circleci.com/api/v1.1/project/github/ethereum/solidity/tree/release"
            local filter="filter=successful&limit=100"
            local successful_jobs; successful_jobs="$(query_api "${job_endpoint}?${filter}")"
            echo "Got $(echo "$successful_jobs" | jq '. | length') recent successful job records from CircleCI"

            for target in ${release_targets[@]}; do
                download_binary_from_circleci "$target" "$successful_jobs" "$tag_info" "$solc_bin_dir"
            done
            ;;

        github)
            local release_targets=(
                linux-amd64
                windows-amd64
                macosx-amd64
                emscripten
            )

            if [[ $solidity_version == latest ]]; then
                local release_info_endpoint="https://api.github.com/repos/ethereum/solidity/releases/latest"
            else
                local release_info_endpoint="https://api.github.com/repos/ethereum/solidity/releases/tags/${solidity_version}"
            fi

            echo "Getting ${solidity_version} release info from ${release_info_endpoint}"
            local release_info; release_info="$(query_api "$release_info_endpoint")"

            echo "$release_info" | jq '{
                name,
                author: .author.login,
                tag_name,
                target_commitish,
                draft,
                prerelease,
                created_at,
                published_at,
                assets: [ .assets[].name ]
            }'

            for target in ${release_targets[@]}; do
                download_binary_from_github "$target" "$release_info" "$tag_info" "$solc_bin_dir"
            done
            ;;

        *) die "Invalid source: '${source}'. Must be either 'circleci' or 'github'." ;;
    esac
}

main() {
    local source="${1:-"$default_source"}"
    local solidity_version="${2:-"$default_solidity_version"}"
    local solc_bin_dir="${3:-$PWD}"

    (( $# < 4 )) || die "Too many arguments"

    download_release "$source" "$solidity_version" "$solc_bin_dir"
}

main "$@"
#EOF
