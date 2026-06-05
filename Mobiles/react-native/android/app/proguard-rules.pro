# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:

# --- Android native crash symbolication (R8 retrace) ---
# Preserve source file + line number metadata so obfuscated stack traces can be
# retraced against mapping.txt (server-side R8 retrace in the Faro collector).
# Rename the source file attribute to a constant so it leaks no original names
# while still keeping the line table that retrace needs.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
