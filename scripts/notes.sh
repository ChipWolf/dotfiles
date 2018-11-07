#!/bin/bash

NOTES_HOME="$HOME/.local/notes"
NOTES_DATE="$NOTES_HOME/$(date '+%Y%m')" # 201807
NOTES_FILE="$NOTES_DATE/$(date '+%dT').md" # 16T

mkdir -p "$NOTES_DATE"
touch "$NOTES_FILE"

if [[ "$1" != '-n' ]]; then
  if [ ! -z "$(cat $NOTES_FILE | tail -1)" ]; then
    echo >> "$NOTES_FILE"
  fi
  echo -n "# $(date '+%Y%m%dT%H%MZ')" >> "$NOTES_FILE"
  if [ ! -z "$1" ]; then
    echo -n " - $@" >> "$NOTES_FILE"
  fi
  echo -e "\n" >> "$NOTES_FILE"
fi

vim "+normal G$" +startinsert "$NOTES_FILE"

