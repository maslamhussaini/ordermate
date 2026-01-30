#!/bin/bash
echo "🚀 Starting Flutter Build on Vercel..."

# 1. Install Flutter (Shallow clone for speed)
if [ ! -d "flutter" ]; then
  git clone --depth 1 https://github.com/flutter/flutter.git -b stable
fi
export PATH="$PATH:`pwd`/flutter/bin"

echo "✅ Flutter PATH updated"
flutter doctor -v

# 2. Re-create .env file safely
echo "📝 Creating .env file..."

# Remove spaces from the Gmail App Password if they exist
CLEAN_GMAIL_PASS=$(echo "$GMAIL_APP_PASSWORD" | tr -d ' ')

cat <<EOT > .env
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
GMAIL_USERNAME=$GMAIL_USERNAME
GMAIL_APP_PASSWORD=$CLEAN_GMAIL_PASS
EOT

# Explicitly ensure the .env is in every possible assets directory
mkdir -p assets
cp .env assets/.env
mkdir -p web/assets
cp .env web/assets/.env

echo "✅ .env file created and cleaned"

# 3. Build the Web App
echo "🔨 Building web app..."
flutter config --enable-web
flutter pub get
flutter build web --release --no-tree-shake-icons --base-href /

# Final forced copy to the build output just in case
mkdir -p build/web/assets
cp .env build/web/assets/.env
echo "✅ Final verification: .env copied to build/web/assets/"

echo "📂 Verifying build output..."
ls -R build/web

echo "🎉 Build complete!"
