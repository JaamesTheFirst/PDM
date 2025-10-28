# 🗺️ Mapbox Setup Guide

## 📋 Getting Your Mapbox Access Token

1. **Create a free account**: Visit https://account.mapbox.com/auth/signup/
2. **Get your token**: 
   - After signing up, go to https://account.mapbox.com/access-tokens/
   - Copy your **Default public token** (starts with `pk.ey...`)
3. **Share with team**: Send your token to team members via secure channel (Discord, WhatsApp, etc.)

## 🔧 Setup Instructions

### For Android:
1. Copy `AndroidManifest.xml.template` to `android/app/src/main/AndroidManifest.xml`
2. Replace `YOUR_MAPBOX_ACCESS_TOKEN` with your actual token (line 4)

### For iOS:
1. Copy `Info.plist.template` to `ios/Runner/Info.plist`
2. Replace `YOUR_MAPBOX_ACCESS_TOKEN` with your actual token (line 3)

### For Flutter (main.dart):
The token is already configured in `lib/main.dart` - no changes needed.

## ⚠️ Important Notes

- **DO NOT commit your token** - it's already in `.gitignore`
- Each team member needs to add their own token locally
- The token is safe to share (it's a public token)
- Free tier includes 50,000 map loads per month

## 🧪 Testing

After setup, run:
```bash
flutter run
```

Click "Ver mapa" to test the map functionality!

## 📚 Resources

- Mapbox Dashboard: https://account.mapbox.com/
- Mapbox Flutter Docs: https://docs.mapbox.com/flutter/
- Support: https://docs.mapbox.com/help/
