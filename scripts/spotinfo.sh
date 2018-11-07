#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$(dirname "$SOURCE")" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$(dirname "$SOURCE")" && pwd )"

TRACK=$(osascript "$DIR/get_track.applescript")

STATE=$(echo "$TRACK" | jq -r .state)
TITLE="$(echo "$TRACK" | jq -r .name | sed 's/"/\\"/g')"
ARTIST="$(echo "$TRACK" | jq -r .artist | sed 's/"/\\"/g')"

if [[ "$STATE" == "playing" ]]; then
  STATE="true"
else
  STATE="false"
fi

SEPERATOR="-"
if [[ "$PLAYING" == "true"  ]]; then
  PLAYSYMBOL="▶"
else
  PLAYSYMBOL="❚❚"
fi
if [[ "$TRACK" == "null" ]]; then
  OUTPUT="◼"
else
  OUTPUT="$PLAYSYMBOL $ARTIST $SEPERATOR $TITLE"
fi
echo -n "$OUTPUT"

