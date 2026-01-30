#!/bin/bash

echo "🚀 Starting Flutter Build on Vercel..."

# 1. Install Flutter (if not cached)
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

echo "✅ Flutter installed"
flutter --version

# 2. Re-create .env file from Vercel Environment Variables
# We explicitly write the vars we need into the .env file for the app to read at runtime
echo "📝 Creating .env file from Vercel Environment Variables..."
printf "SUPABASE_URL=%s\n" "$SUPABASE_URL" > .env
printf "SUPABASE_ANON_KEY=%s\n" "$SUPABASE_ANON_KEY" >> .env
printf "GOOGLE_MAPS_API_KEY=%s\n" "$GOOGLE_MAPS_API_KEY" >> .env
printf "GMAIL_USERNAME=%s\n" "$GMAIL_USERNAME" >> .env
printf "GMAIL_APP_PASSWORD=%s\n" "$GMAIL_APP_PASSWORD" >> .env

echo "✅ .env file created"
cat .env | cut -c1-20 # Verify first 20 chars of each line for debugging (safe)

# 3. Build the Web App
echo "🔨 Building web app..."
flutter config --enable-web
flutter pub get
flutter build web --release --no-tree-shake-icons --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "🎉 Build complete!"
