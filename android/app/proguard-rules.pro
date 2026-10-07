# Flutter 相关
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# 原生桥接（通过 MethodChannel 反射调用，需要保留）
-keep class com.moko.downkyi.** { *; }
