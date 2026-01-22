#!/bin/bash

# 1. Check if a project name was provided
if [ -z "$1" ]; then
  echo "Usage: ./create-spring.sh <project-name>"
  echo "Example: ./create-spring.sh my-awesome-api"
  exit 1
fi

PROJECT_NAME=$1
GROUP_ID="com.ajay" # You can hardcode your preferred group ID here
JAVA_VERSION="21"   # Defaulting to 21 (LTS), change to 17 if needed

echo "🚀 Creating Spring Boot Project: $PROJECT_NAME..."

# 2. Create the directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME" || exit

# 3. Download from Spring Initializr
# We ask for: Web, JPA, H2, Lombok, Validation, PostgreSQL
# We force the type to 'maven-project'
curl https://start.spring.io/starter.zip \
    -d type=maven-project \
    -d language=java \
    -d bootVersion=3.4.1 \
    -d baseDir="$PROJECT_NAME" \
    -d groupId="$GROUP_ID" \
    -d artifactId="$PROJECT_NAME" \
    -d name="$PROJECT_NAME" \
    -d packageName="$GROUP_ID.$PROJECT_NAME" \
    -d packaging=jar \
    -d javaVersion="$JAVA_VERSION" \
    -d dependencies=web,data-jpa,h2,lombok,validation,postgresql \
    -o project.zip

# 4. Unzip and Clean up
# The zip usually contains the folder structure inside, but sometimes it explodes files.
# We unzip quietly (-q)
unzip -q project.zip

# Handle the case where files are scattered or nested
if [ -d "$PROJECT_NAME" ]; then
    # If Spring put them in a subfolder, move them up
    mv "$PROJECT_NAME"/* .
    mv "$PROJECT_NAME"/.* . 2>/dev/null # Move hidden files like .mvn
    rmdir "$PROJECT_NAME"
fi

# 5. Cleanup the zip
rm project.zip

# 6. Make mvnw executable
chmod +x mvnw

echo "✅ Project '$PROJECT_NAME' created successfully!"
echo "📂 Location: $(pwd)"
echo "------------------------------------------------"
echo "To start coding:"
echo "  cd $PROJECT_NAME"
echo "  vim src/main/java/$GROUP_ID/${PROJECT_NAME//-/_}/ExpenseManagerApplication.java"
echo ""
echo "To run the app:"
echo "  ./mvnw spring-boot:run"
