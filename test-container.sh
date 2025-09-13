#!/bin/bash

# Simple Docker test wrapper for Windows
# Avoids path conversion issues with Git Bash on Windows

set -e

echo "Testing MVP Pipeline Container..."
echo "================================"

# Create test workspace if it doesn't exist  
mkdir -p test-workspace/source
mkdir -p test-workspace/mvp

# Create mock source files for testing
echo "Creating mock source files..."
cat > test-workspace/source/package.json << 'EOF'
{
  "name": "event-engagement-toolkit",
  "version": "1.0.0",
  "scripts": {
    "build": "next build",
    "dev": "next dev",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^13.0.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
EOF

cat > test-workspace/source/next.config.ts << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
}
module.exports = nextConfig
EOF

mkdir -p test-workspace/source/apps/web/src/app
cat > test-workspace/source/apps/web/src/app/page.tsx << 'EOF'
export default function Page() {
  return (
    <div>
      <h1>Test MVP Application</h1>
      <p>This is a test application.</p>
    </div>
  )
}
EOF

# Test 1: Basic container environment
echo "1. Testing basic container environment..."
docker run --rm \
  -e "AWS_BATCH_JOB_NAME=test-job" \
  -e "LOG_LEVEL=INFO" \
  mvp-pipeline:test \
  sh -c "echo 'Container is running'; ls -la /app/scripts/; whoami"

echo
echo "2. Testing environment validation..."
MSYS_NO_PATHCONV=1 docker run --rm \
  -e "LOG_LEVEL=INFO" \
  mvp-pipeline:test \
  sh -c "/app/scripts/test-environment.sh"

echo
echo "3. Testing AI_DEVELOPMENT stage..."
MSYS_NO_PATHCONV=1 docker run --rm \
  -e "AWS_BATCH_JOB_NAME=test-job" \
  -e "LOG_LEVEL=DEBUG" \
  -v "$(pwd)/test-workspace:/workspace" \
  mvp-pipeline:test \
  sh -c "/app/pipeline.sh AI_DEVELOPMENT 'Test MVP' 'A test MVP application' 'Basic web application'"

echo
echo "4. Checking generated output..."
if [ -f "test-workspace/mvp_output_dir.txt" ]; then
  echo "MVP output directory: $(cat test-workspace/mvp_output_dir.txt)"
fi

if [ -d "test-workspace/mvp" ]; then
  echo "Generated files:"
  find test-workspace/mvp -type f | head -10
fi

echo
echo "All tests completed!"
