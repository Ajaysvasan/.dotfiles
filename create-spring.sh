#!/bin/bash

# 1. Check if a project name was provided
if [ -z "$1" ]; then
  echo "Usage: ./create-spring.sh <project-name>"
  echo "Example: ./create-spring.sh my-awesome-api"
  exit 1
fi

PROJECT_NAME=$1
GROUP_ID="com.ajay"

# 2. Sanitize PROJECT_NAME for the Java Package (replace - with _)
PACKAGE_NAME_SUFFIX=${PROJECT_NAME//-/_}
FULL_PACKAGE_NAME="${GROUP_ID}.${PACKAGE_NAME_SUFFIX}"

echo "🚀 Creating Spring Boot Project: $PROJECT_NAME..."
echo "📦 Package Name: $FULL_PACKAGE_NAME"

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME" || exit

# 3. Download from Spring Initializr
# REMOVED 'bootVersion' so it always fetches the latest stable version
curl -G https://start.spring.io/starter.zip \
    -d type=maven-project \
    -d language=java \
    -d baseDir="$PROJECT_NAME" \
    -d groupId="$GROUP_ID" \
    -d artifactId="$PROJECT_NAME" \
    -d name="$PROJECT_NAME" \
    -d packageName="$FULL_PACKAGE_NAME" \
    -d packaging=jar \
    -d javaVersion=21 \
    -d dependencies=web,data-jpa,h2,lombok,validation,postgresql \
    -o project.zip

# 4. Check if download was successful
if ! file project.zip | grep -q "Zip archive"; then
    echo "❌ Error: Failed to download valid project. Server response:"
    cat project.zip
    rm project.zip
    cd ..
    rmdir "$PROJECT_NAME"
    exit 1
fi

# 5. Unzip and cleanup
unzip -q project.zip
if [ -d "$PROJECT_NAME" ]; then
    mv "$PROJECT_NAME"/* .
    mv "$PROJECT_NAME"/.* . 2>/dev/null
    rmdir "$PROJECT_NAME"
fi
rm project.zip
chmod +x mvnw

echo "✅ Project '$PROJECT_NAME' created successfully!"
echo "📂 Location: $(pwd)"
echo "------------------------------------------------"
echo "To start coding:"
echo "  cd $PROJECT_NAME"
echo "  vim src/main/java/${GROUP_ID//./\/}/$PACKAGE_NAME_SUFFIX/ExpenseManagerApplication.java"
echo ""
echo "To run the app:"
echo "  ./mvnw spring-boot:run"
