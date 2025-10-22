#!/bin/bash
# Start Pixelopolis Flutter web app on http://localhost:8080

echo "Starting Pixelopolis on http://localhost:8080"
echo "Press 'r' for hot reload, 'q' to quit"
echo ""

flutter run -d chrome --web-port=8080
