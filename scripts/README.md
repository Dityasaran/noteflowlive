# Build Scripts

## Build the app
./scripts/build_swift_app.sh

## Package as DMG  
./scripts/make_dmg.sh

## Optional env vars for signing & notarization:
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
APPLE_ID="your@email.com"
APPLE_TEAM_ID="YOURTEAMID"
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
