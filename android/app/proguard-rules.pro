# Flutter's default rules are managed by the Flutter tool.
# Add your custom rules here.

# ===================================================================
# Rules for Google MediaPipe & Flutter Gemma
# ===================================================================
-keep class com.google.mediapipe.** { *; }
-keep interface com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# ===================================================================
# Rules for Google Protobuf (A major dependency)
# This is a very comprehensive set of rules for this library.
# ===================================================================
-keep class com.google.protobuf.** { *; }
-keep interface com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

-keepclasseswithmembers class * {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep public class * extends com.google.protobuf.Internal$EnumLite {
    public static final int[] $VALUES;
}

# ===================================================================
# Rules for Annotation/Reflection Libraries (like AutoValue)
# ===================================================================
-keep class javax.lang.model.** { *; }
-keep class javax.tools.** { *; }
-keep class com.google.auto.value.** { *; }
-keep @interface com.google.auto.value.**
-dontwarn javax.lang.model.**
-dontwarn com.google.auto.value.**

# ===================================================================
# Rules for common Networking Libraries (OkHttp, BouncyCastle, etc.)
# ===================================================================
-keep class org.conscrypt.** { *; }
-keep class org.bouncycastle.** { *; }
-keep class org.openjsse.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**