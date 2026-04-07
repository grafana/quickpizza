#!/bin/bash

# Script to run React Native app on iOS simulator

cd "$(dirname "$0")/.."

# ============================================
# Config file check (config.json, same as Flutter)
# ============================================
CONFIG_FILE="config.json"
CONFIG_EXAMPLE="config.json.example"

if [ ! -f "$CONFIG_FILE" ]; then
    echo ""
    echo "⚠️  WARNING: $CONFIG_FILE not found!"
    echo ""
    
    if [ -f "$CONFIG_EXAMPLE" ]; then
        echo "Creating $CONFIG_FILE from $CONFIG_EXAMPLE..."
        cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
        echo ""
        echo "📝 Please edit $CONFIG_FILE with your actual values:"
        echo "   - FARO_COLLECTOR_URL: Your Grafana Faro collector URL"
        echo "   - BASE_URL: Backend API URL (optional, has platform defaults)"
        echo "   - PORT: Backend port (optional, defaults to 3333)"
        echo ""
        echo "Then run this script again."
        exit 1
    else
        echo "❌ ERROR: $CONFIG_EXAMPLE not found!"
        exit 1
    fi
fi

echo "✅ Using config from $CONFIG_FILE"
echo ""
echo "Running React Native app on iOS..."
echo "Make sure Metro is running (yarn start) in another terminal, or run: yarn ios"
yarn ios
