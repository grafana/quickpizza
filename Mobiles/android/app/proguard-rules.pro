# Add project specific ProGuard rules here.
# Keep OpenTelemetry classes
-keep class io.opentelemetry.** { *; }
-dontwarn io.opentelemetry.**
