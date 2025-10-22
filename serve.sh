#!/bin/bash
# Serve the built Pixelopolis app on http://localhost:8080
# This is more stable than flutter run - won't die when laptop sleeps!

echo "🎮 Starting Pixelopolis on http://localhost:8080"
echo "This server is stable and won't die when your laptop sleeps."
echo "Press Ctrl+C to stop"
echo ""

cd build/web && python3 -m http.server 8080
