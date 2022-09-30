#!/bin/sh
# Usage: build_openssl VERSION SOURCE_DIR TARGET_DIR TARGET
set -euo pipefail
export MAKEFLAGS=-j`nproc`
version=$1
source_dir=$2
target_dir=$3
target=$4

if [ ! -d $source_dir ]; then
  if [[ $version == "3"* ]]; then
    ref="openssl-$version"
  else
    ref="OpenSSL_`echo $version | tr . _`"
  fi
  git clone --depth 1 https://github.com/openssl/openssl --branch $ref $source_dir
fi

if [ ! -d $target_dir ]; then
  cd $source_dir
  ./Configure $target --prefix=$target_dir
  make clean
  make
  make install_sw
fi
