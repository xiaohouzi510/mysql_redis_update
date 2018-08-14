#!/bin/bash
rm -rf protodata/*
mkdir -p protodata
find ../../run/binconf/zone/data/ -maxdepth 1 -mindepth 1 -type f|xargs -I {} cp -rf {} ./protodata/