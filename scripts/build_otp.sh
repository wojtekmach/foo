#!/bin/sh
# Usage: build_otp VERSION SOURCE_DIR TARGET_DIR TARGET OPENSSL_DIR XCOMP_CONF
set -euo pipefail
version=$1
source_dir=$2
target_dir=$3
target=$4
openssl_dir=$5
xcomp_conf=$6

if [ ! -d $source_dir ]; then
  ref="OTP-$version"
  git clone --depth 1 https://github.com/erlang/otp --branch $ref $source_dir
fi

if [ ! -d $target_dir ]; then
  cd $source_dir
  export MAKEFLAGS=-j`nproc`
  export ERL_TOP=`pwd`
  export ERLC_USE_SERVER=true
  ./otp_build configure \
    --with-ssl=$openssl_dir \
    --disable-dynamic-ssl-lib \
    --enable-builtin-zlib \
    --xcomp-conf=$xcomp_conf
  ./otp_build boot -s
  ./otp_build release -s $target_dir
fi
