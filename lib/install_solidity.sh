install_solidity() {
  local install_type=$1
  local version=$2
  local install_path=$3

  if [ "$SVMRCDIR" = "" ]; then
    local svmrc_download_dir=$(mktemp -d -t solidity_XXXXXX)
  else
    local svmrc_download_dir=$SVMRCDIR
  fi

  if [ "$install_type" = "version" ]; then
    install_solidity_version $version $install_path $svmrc_download_dir
  else
    install_solidity_ref $version $install_path $svmrc_download_dir
  fi

  mkdir -p $install_path/.svmrc/
}