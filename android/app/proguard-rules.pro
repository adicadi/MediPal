# ML Kit Text Recognition - Comprehensive Keep Rules
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# If you use the specific language bundles:
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# OkHttp / ucrop rules (just in case they reappear)
-keep class okhttp3.** { *; }
-keep class com.yalantis.ucrop.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.yalantis.ucrop.**