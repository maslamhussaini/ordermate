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
cat <<EOT > .env
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
GMAIL_USERNAME=$GMAIL_USERNAME
GMAIL_APP_PASSWORD=$GMAIL_APP_PASSWORD
EOT

echo "✅ .env file created"

# 3. Build the Web App
echo "🔨 Building web app..."
flutter config --enable-web
flutter pub get
flutter build web --release --no-tree-shake-icons --base-href /

echo "🎉 Build complete!"
