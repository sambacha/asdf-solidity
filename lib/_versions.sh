#!/usr/bin/env bash

# If we're able to successfuly fetch the  file, its content is written to
# STDOUT. Otherwise, nothing is written to STDOUT and an error message is
# written to STDERR.
download_solidity_builds() {
  local releases_url='https://raw.githubusercontent.com/ethereum/solc-bin/gh-pages/bin/list.txt'

  if ! curl -fs $releases_url; then
    cat >&2 <<EOS
==> Failed to fetch versions list.
SVMRC returned an error for the following URL:
${releases_url}
Make sure your internet connection is stable and that you can reach
https://github.com.
EOS

    return 1
  fi
}


get_solidity_versions() {
  # Get the builds file from Hex.pm
 # download_solidity_builds |
    # Filter only the first field (the version name)
  #  cut -d\  -f1 |
    # Normalize version names
   # sed -E '
    #  # Discard numeric versions just with major
     # /^v[0-9]+(-.*)?$/d;
      # Discard numeric versions just with major and minor
    #  /^v[0-9]+\.[0-9]+(-.*)?$/d;
      # Remove `v` prefix from numeric versions
     # s/^v([0-9]+\.[0-9]+\.[0-9]+(-.*)?)$/\1/
    '
}


# Sort the list of versions.
#
# Does not expect any arguments, assumes the list of versions is provided in
# STDIN.
#
sort_versions() {
  # Sort versions by the numerical values of each field.
  #
  # By default, sort will consider the entire line and sort lines
  # alphabetically according to the current system locale, which influences
  # details like whether downcase letters come before the uppercase ones.
  #
  # First, you'll notice the environment variable `LC_ALL` is being set to
  # `C` for this command. This enables bytewise sorting, which means
  # characters will be sorted by their numerical representation in the
  # encoding table (think ASCII for US English). This makes the sorting
  # algorithm completely uniform since it disregards the user's system
  # locale.
  #
  # Then you'll notice the `-t.` option, which changes the command to split
  # lines on the provided separator `.`, instead of considering the whole
  # line, which will influence the next options.
  #
  # Finally you'll notice the `k` options, which are key definitions that
  # tell sort how we want the sorting algorithm to look at lines. Each key
  # definition will be taken into consideration in order when deciding the
  # position of a line.
  #
  # Each key definition has the following format:
  # * First it specifies the number of the field where this definition
  #   starts, according to the separation specified by `-t`.
  # * Then it specified the number of the field where this definition stops.
  #   When you want to consider a single field, both start and stop values
  #   are the same in the definition.
  # * Finally, the definitions include a single-letter ordering option, which
  #   will override the global ordering options for the current key. In this
  #   case, we use `n` to ensure the sorting is numerical.
  #
  LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n
}


# Output the list of versions in a single line
echo `get_solidity_versions | sort_versions`
