#!/usr/bin/env bash
set -euo pipefail

# ─── Step 1: Navigate to project root ────────────────────────────────────────
cd /root/beebuckz-flutter/build_project

# ─── Step 2: Fresh Android directory ─────────────────────────────────────────
rm -rf android
flutter create --platforms=android .

# ─── Step 3: Opt out of AGP 9 new DSL ────────────────────────────────────────
echo "android.newDsl=false" >> android/gradle.properties

# ─── Step 4: Write android/key.properties ────────────────────────────────────
cat > android/key.properties << 'KEYEOF'
storePassword=BeeBuckz2026!
keyPassword=BeeBuckz2026!
keyAlias=beebuckz
storeFile=/root/beebuckz-release-key.jks
KEYEOF

# ─── Step 5: Overwrite android/app/build.gradle.kts ─────────────────────────
cat > android/app/build.gradle.kts << 'GRADLEOF'
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.beebuckz.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.beebuckz.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = keyProperties["storeFile"]?.let { file(it as String) }
            storePassword = keyProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
GRADLEOF

# ─── Step 6: Restore MainActivity.kt from backup ─────────────────────────────
BACKUP_MAIN="/root/beebuckz-flutter/android/app/src/main/kotlin/com/beebuckz/app/MainActivity.kt"
DEST_MAIN="android/app/src/main/kotlin/com/beebuckz/app/MainActivity.kt"

mkdir -p "$(dirname "$DEST_MAIN")"

if [ -f "$BACKUP_MAIN" ]; then
    cp "$BACKUP_MAIN" "$DEST_MAIN"
    echo "MainActivity.kt restored from backup."
else
    echo "WARNING: Backup MainActivity.kt not found at $BACKUP_MAIN — using Flutter default."
fi

# ─── Step 7: Build ───────────────────────────────────────────────────────────
flutter clean
flutter pub get
flutter build appbundle --release

echo ""
echo "✓ Build complete. AAB located at:"
echo "  build/app/outputs/bundle/release/app-release.aab"
