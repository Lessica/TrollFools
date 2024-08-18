#!/bin/sh

cd $(dirname $0)/..

plutil -convert xml1 TrollFools/TrollFools.entitlements
