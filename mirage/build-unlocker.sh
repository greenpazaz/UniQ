#!/bin/sh

set -e

mirage configure -t xen
make depend
make

cp ./unlocker.xen /build/unlocker/
