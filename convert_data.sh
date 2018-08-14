#!/bin/bash
rm -rf protodata/*
find ../../run/binconf/zone/data/ -maxdepth 1 -mindepth 1 -type f|xargs -I {} cp {} protodata
