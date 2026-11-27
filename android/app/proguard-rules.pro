# Keep GSON generic type tokens and reflection metadata used by flutter_local_notifications
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep flutter_local_notifications models & receivers (deserialized via GSON in ScheduledNotificationReceiver)
-keep class com.dexterous.** { *; }
