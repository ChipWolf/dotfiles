#!/usr/bin/env python3
"""
Custom hints kitten — tmux-thumbs-style URL/path/filename selection.
Copies the selected match to the clipboard.

Usage (in kitty.conf):
    map ctrl+a>space kitten hints --alphabet asdfqwerzxcvjklmiuopghtybn1234567890 --customize-processing custom-hints.py

https://sw.kovidgoyal.net/kitty/kittens/hints/#completely-customizing-the-matching-and-actions-of-the-kitten
"""

import re
from kitty.clipboard import set_primary_selection, set_clipboard_string

RE_PATH = (
    r'(?=[ \t\n]|"|\(|\[|<|\')?'
    "(~/|/)?"
    "([-a-zA-Z0-9_+-,.]+/[^ \t\n\r|:\"'$%&)>\]]*)"
)

RE_URL = (
    r"(https?://|git@|git://|ssh://|s*ftp://|file:///)"
    "[a-zA-Z0-9?=%/_.:,;~@!#$&()*+-]*"
)

RE_COMMON_FILENAME = r"\s?([a-zA-Z0-9_.-/]*[a-zA-Z0-9_.-]+\.(ini|yml|yaml|vim|toml|conf|lua|go|php|rs|py|js|vue|jsx|html|htm|md|mp3|wav|flac|mp4|mkv|dll|exe|sh|txt|log|gz|tar|rar|7z|zip|mod|sum|iso|patch))\s?"

RE_URL_OR_PATH = RE_COMMON_FILENAME + "|" + RE_PATH + "|" + RE_URL


def mark(text, args, Mark, extra_cli_args, *a):
    # Find all matching text regions to present as hint targets
    for idx, m in enumerate(re.finditer(RE_URL_OR_PATH, text)):
        start, end = m.span()
        mark_text = text[start:end].replace("\n", "").replace("\0", "").strip()
        yield Mark(idx, start, end, mark_text, {})


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    # Copy the selected match to the clipboard
    matches, groupdicts = [], []
    for m, g in zip(data["match"], data["groupdicts"]):
        if m:
            matches.append(m), groupdicts.append(g)
    for word, match_data in zip(matches, groupdicts):
        set_clipboard_string(word)
