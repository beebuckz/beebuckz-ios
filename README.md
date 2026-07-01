Hi Claude! I am working on a Flutter project on an Ubuntu server, and I need you to write a single, robust Bash script that fixes a broken Android build setup.

Here is the exact situation and the constraints you must follow:

The Environment: I am running everything as root inside /root/beebuckz-flutter/build_project.

The Problem: The project was recently recreated, so Flutter is generating noul Gradle format with Kotlin DSL (build.gradle.kts) and Android Gradle Plugin 9+ (AGP 9). However, AGP 9 throws strict DSL errors with the Flutter plugin, and my previous cat << EOF commands were getting cut off by the terminal, causing NullPointerException.

The Fix Required from Flutter: Flutter explicitly recommended opting out of the new DSL by setting android.newDsl=false.

The Keystore: A new keystore has been generated at /root/beebuckz-release-key.jks with the password BeeBuckz2026! and alias beebuckz.

Please generate a single, copy-pasteable Bash script that executes everything sequentially using && or clean blocks, ensuring NO code gets cut off. The script must:

Navigate to /root/beebuckz-flutter/build_project.

Delete the current android directory (rm -rf android) and run flutter create --platforms=android . to get a fresh start.

Append android.newDsl=false to android/gradle.properties.

Overwrite android/app/build.gradle.kts with a complete, valid Kotlin DSL script that includes the java.util.Properties import, reads key.properties, and maps the release signing config correctly (without using the deprecated compilerOptions if it causes compatibility mismatches, or using standard JVM 1.8 compatibility options).

Create the android/key.properties file with the correct credentials:

Properties
storePassword=BeeBuckz2026!
keyPassword=BeeBuckz2026!
keyAlias=beebuckz
storeFile=/root/beebuckz-release-key.jks
Ensure MainActivity.kt is copied from the backup folder /root/beebuckz-flutter/android/app/src/main/kotlin/com/beebuckz/app/MainActivity.kt to the new path android/app/src/main/kotlin/com/beebuckz/app/MainActivity.kt.

Run flutter clean, flutter pub get, and finally flutter build appbundle --release.