# ProGuard / R8 rules for ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# ==============================================================================
# ProGuard / R8 rules for ONNX Runtime (Java & JNI)
# libonnxruntime4j_jni.so calls Java classes via JNI reflection:
# ai/onnxruntime/TensorInfo, ai/onnxruntime/OrtSession, ai/onnxruntime/OnnxValue, etc.
# Without these rules, R8 obfuscates/removes these classes in release builds,
# causing "JNI DETECTED ERROR IN APPLICATION: java_class == null in call to GetMethodID".
# ==============================================================================
-dontwarn ai.onnxruntime.**
-keep class ai.onnxruntime.** { *; }
-keep interface ai.onnxruntime.** { *; }
-keep enum ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }

# Flutter ONNX Runtime Plugin (MethodChannel handler and Java reflection)
-dontwarn com.masicai.flutteronnxruntime.**
-keep class com.masicai.flutteronnxruntime.** { *; }
-keepclassmembers class com.masicai.flutteronnxruntime.** { *; }

# Preserve JNI method names and reflection attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepclasseswithmembernames class * {
    native <methods>;
}
