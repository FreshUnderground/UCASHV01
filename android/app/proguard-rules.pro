# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Gson (si utilisé)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Conserver les modèles de données
-keep class com.example.ucashv01.** { *; }

# Règles standard Android
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Règles pour WebView
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
