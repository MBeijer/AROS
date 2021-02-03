#!/bin/bash
for file in $1/*
do
  diffmerge "../aros-official/${file}" "${file}"
done
