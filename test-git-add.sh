#!/bin/bash

echo "=== Testing Clone Template Git Add Fix ==="
echo "Testing the git add issue in clone-template.sh"
echo ""

# Create test environment
TEST_DIR="/tmp/test-clone-template-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create a simple project structure
mkdir -p project
cd project

# Create sample files
echo '{"name": "test-project", "version": "1.0.0"}' > package.json
echo "# Test Project" > README.md
echo "console.log('Hello World');" > index.js

echo "Created test files:"
ls -la

# Initialize git repo
git init -b main
git config user.name "Test User"
git config user.email "test@example.com"

echo ""
echo "Testing git add ."

# Test the git add command
git add .

# Check if files were staged
STAGED_FILES=$(git diff --cached --name-only | wc -l)
echo "Files staged for commit: $STAGED_FILES"

if [ "$STAGED_FILES" -gt 0 ]; then
    echo "✅ SUCCESS: git add . worked correctly!"
    echo "Staged files:"
    git diff --cached --name-only
    
    # Test commit
    git commit -m "Test commit"
    echo "✅ Commit successful"
else
    echo "❌ FAILED: git add . did not stage any files"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo ""
echo "=== Git Add Test Complete ==="
