#!/bin/bash

if [ "$(uname)" == "Darwin" ]; then
  LOVE="/Applications/love.app/Contents/MacOS/love"
else
  LOVE="love"
fi

if pgrep -f "networking/server" > /dev/null; then
  echo "Server already running."
else
  echo "Starting server..."
  $LOVE ./networking/server &
fi

echo "Starting client..."
$LOVE .