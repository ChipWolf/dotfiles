on escape_quotes(string_to_escape)
  set AppleScript's text item delimiters to the "\""
  set the item_list to every text item of string_to_escape
  set AppleScript's text item delimiters to the "\\\""
  set string_to_escape to the item_list as string
  set AppleScript's text item delimiters to ""
  return string_to_escape
end escape_quotes

with timeout of 1 seconds
  tell application "Spotify"
    set ctrack to "{"
    set ctrack to ctrack & "\"artist\":\"" & my escape_quotes(current track's artist) & "\""
    set ctrack to ctrack & ",\"name\":\"" & my escape_quotes(current track's name) & "\""
    set ctrack to ctrack & ",\"state\":\"" & player state & "\""
    set ctrack to ctrack & "}"
  end tell
end
