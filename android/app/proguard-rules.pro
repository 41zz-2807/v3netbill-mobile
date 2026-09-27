# Proguard rules untuk v3Netbill Mobile.
#
# Release build memakai minify dan shrinkResources, jadi aturan ini menjaga
# hal-hal yang tetap dibutuhkan saat obfuscation dijalankan.

# Flutter engine memakai reflection untuk entry point-nya.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Dio memakai refleksi hanya untuk tipe generik pada serialization.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-dontwarn javax.annotation.**

# flutter_secure_storage memakai PGP pada Android.
-keep class com.google.crypto.tink.** { *; }
-keep class com.google.crypto.tink.tink.** { *; }

# Provider dipakai untuk state management, kelasnya dirujuk langsung.
-keep class com.v3netbill.v3netbill_mobile.** { *; }
