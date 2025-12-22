#!/usr/bin/env bash
# Comprehensive Render build script for Django deployment
# This script handles all necessary setup for the backend

set -o errexit  # Exit on error
set -o pipefail # Exit on pipe failure
set -o nounset  # Exit on unset variable

echo "========================================="
echo "🚀 Starting Backend Build Process"
echo "========================================="

# Navigate to backend directory
echo ""
echo "📂 Step 1/6: Changing to backend directory..."
cd computer_shop_backend || { echo "❌ Failed to find computer_shop_backend directory"; exit 1; }
pwd

# Install Python dependencies
echo ""
echo "🔧 Step 2/6: Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt || { echo "❌ Failed to install dependencies"; exit 1; }
echo "✅ Dependencies installed successfully"

# Run database migrations
echo ""
echo "🗄️  Step 3/6: Running database migrations..."
python manage.py makemigrations --noinput || echo "⚠️  No new migrations to create"
python manage.py migrate --noinput || { echo "❌ Migration failed"; exit 1; }
echo "✅ Migrations completed successfully"

# Collect static files
echo ""
echo "📦 Step 4/6: Collecting static files..."
python manage.py collectstatic --noinput --clear || { echo "❌ Failed to collect static files"; exit 1; }
echo "✅ Static files collected successfully"

# Create admin user
echo ""
echo "👤 Step 5/6: Ensuring admin user exists..."
python manage.py ensure_admin || { echo "❌ Failed to create admin user"; exit 1; }
echo "✅ Admin user configured"

# Verify setup
echo ""
echo "🔍 Step 6/6: Verifying Django configuration..."
python manage.py check --deploy || { echo "⚠️  Deployment checks found issues (continuing anyway)"; }

echo ""
echo "========================================="
echo "✅ Build completed successfully!"
echo "========================================="
echo ""
echo "📝 Admin Credentials:"
echo "   Username: admin"
echo "   Password: Admin@1221"
echo ""
echo "🌐 Backend is ready to start!"
echo "========================================="
