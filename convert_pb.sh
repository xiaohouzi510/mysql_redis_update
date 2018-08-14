#!/bin/bash
OUT_PB="pblua"
rm -rf OUT_PB/*
if [[ ! -d ${OUT_PB} ]]; then mkdir -p ${OUT_PB}; fi
if [[ ! -d ${OUT_PB}/cs/ ]]; then mkdir -p ${OUT_PB}/cs/; fi
if [[ ! -d ${OUT_PB}/ss/ ]]; then mkdir -p ${OUT_PB}/ss/; fi
if [[ ! -d ${OUT_PB}/common/ ]]; then mkdir -p ${OUT_PB}/common/; fi
if [[ ! -d ${OUT_PB}/database/ ]]; then mkdir -p ${OUT_PB}/database/; fi
if [[ ! -d ${OUT_PB}/game_third/ ]]; then mkdir -p ${OUT_PB}/game_third/; fi
if [[ ! -d ${OUT_PB}/proto/ ]]; then mkdir -p ${OUT_PB}/proto/; fi

PROTO_PATH="../../protocol"
protoc --plugin=./pbplugin/protoc-gen-lua --proto_path=${PROTO_PATH}/cs/ --proto_path=${PROTO_PATH}/ss/ --proto_path=${PROTO_PATH}/game_third/ --lua_out=${OUT_PB}/cs/ ${PROTO_PATH}/cs/*.proto
protoc --plugin=./pbplugin/protoc-gen-lua --proto_path=${PROTO_PATH}/cs/ --proto_path=${PROTO_PATH}/ss/ --proto_path=${PROTO_PATH}/database/ --proto_path=${PROTO_PATH}/game_third/ --proto_path=${PROTO_PATH}/common/ --lua_out=${OUT_PB}/ss/ ${PROTO_PATH}/ss/*.proto
protoc --plugin=./pbplugin/protoc-gen-lua --proto_path=${PROTO_PATH}/database/ --lua_out=${OUT_PB}/database ${PROTO_PATH}/database/*.proto
protoc --plugin=./pbplugin/protoc-gen-lua --proto_path=${PROTO_PATH}/common/ --lua_out=${OUT_PB}/common ${PROTO_PATH}/common/*.proto
protoc --plugin=./pbplugin/protoc-gen-lua --proto_path=${PROTO_PATH}/game_third/ --lua_out=${OUT_PB}/game_third ${PROTO_PATH}/game_third/*.proto
protoc --plugin=./pbplugin/protoc-gen-lua --proto_path=${PROTO_PATH}/resource/proto/ --lua_out=${OUT_PB}/proto ${PROTO_PATH}/resource/proto/*.proto