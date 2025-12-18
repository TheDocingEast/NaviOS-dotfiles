#!/usr/bin/env bash
# Rofi custom mode for symbols

SYMBOLS_FILE="$HOME/.local/share/rofi/symbols.csv"

# Rofi passes the query as first argument
query="$1"

# Filter symbols (optional)
while IFS= read -r line; do
    [[ "$line" =~ $query ]] && echo "$line"
done < "$SYMBOLS_FILE"

