#!/bin/bash

echo "🚀 Starting Flutter Build on Vercel..."

# 1. Install Flutter (if not cached)
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

echo "✅ Flutter installed"
flutter --version

# 2. Re-create .env file from Vercel Environment Variables
# We explicitly write the vars we need into the .env file for the app to read at runtime
echo "📝 Creating .env file..."
rm -f .env
touch .env

echo "SUPABASE_URL=$SUPABASE_URL" >> .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> .env
echo "GMAIL_USERNAME=$GMAIL_USERNAME" >> .env
echo "GMAIL_APP_PASSWORD=$GMAIL_APP_PASSWORD" >> .env

echo "✅ .env file created"

# 3. Build the Web App
echo "🔨 Building web app..."
flutter config --enable-web
flutter pub get
flutter build web --release --no-tree-shake-icons

echo "🎉 Build complete!"
