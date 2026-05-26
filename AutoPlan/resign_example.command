#!/bin/bash

# Define your app path
APP_PATH="/Applications/AutoPlan.app"

# Find your free development certificate full name from Keychain.app
IDENTITY="Apple Development: xx@xx.com (xxx)"

codesign --force --sign "$IDENTITY" "$APP_PATH"

# Check the signing result
if [ $? -eq 0 ]; then
    echo "$✅ (date): Successfully resigned!" >> ./resign_log.txt
else
    echo "$❌ (date): Failed to resign!" >> ./resign_log.txt
fi