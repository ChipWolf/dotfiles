#!/bin/bash
INFO_FILE="$HOME/.local/tmp/spotify.latest"
COUNT_FILE="$HOME/.local/tmp/spotify.count"

touch "$COUNT_FILE"
COUNT="$(cat "$COUNT_FILE")"
((COUNT++))
echo -n "$COUNT" > "$COUNT_FILE"

if [ $COUNT -ge 2 ]; then
  rm -f "$COUNT_FILE"
  
  bash "$HOME/Documents/Utilities/spotify-node/node.sh" > "$INFO_FILE"

fi

ARTIST=$(jq -c -M -r .song.artist "$INFO_FILE")
TRACK=$(jq -c -M -r .song.title "$INFO_FILE")
PLAYING=$(jq -c -M -r .playing "$INFO_FILE")
SEPERATOR="-"
if [[ "$PLAYING" == "true"  ]]; then
  PLAYSYMBOL="▶"
else
  PLAYSYMBOL="❚❚"
fi
if [[ "$TRACK" == "null" ]]; then
  OUTPUT="◼"
else
  OUTPUT="$PLAYSYMBOL $ARTIST $SEPERATOR $TRACK"
fi
echo -n "$OUTPUT"

