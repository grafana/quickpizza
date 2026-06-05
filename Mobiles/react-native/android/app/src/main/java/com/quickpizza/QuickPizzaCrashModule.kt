package com.quickpizza

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class QuickPizzaCrashModule(
  reactContext: ReactApplicationContext
) : ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "QuickPizzaCrash"

  @ReactMethod
  fun crash(variant: String) {
    Handler(Looper.getMainLooper()).post {
      when (variant) {
        "nullPointer" -> triggerNullPointer()
        "anr" -> triggerApplicationNotResponding()
        else -> triggerRuntimeException()
      }
    }
  }

  // The helpers below are intentionally private so R8/ProGuard renames them in
  // release builds. The resulting obfuscated stack frames are what we retrace
  // against mapping.txt to prove Android symbolication end to end.

  private fun triggerRuntimeException() {
    raiseQuickPizzaFailure("QuickPizza RN intentional native crash")
  }

  private fun triggerNullPointer() {
    val value: String? = readMissingValue()
    // Kotlin not-null assertion on a null value throws NullPointerException.
    value!!.length
  }

  private fun triggerApplicationNotResponding() {
    // Block the main (UI) thread well beyond the ANR watchdog timeout so Faro's
    // ANR tracker records an ANR event with the main-thread stack.
    val blockForMs = 10_000L
    val deadline = SystemClock.uptimeMillis() + blockForMs
    while (SystemClock.uptimeMillis() < deadline) {
      busyWaitOnMainThread()
    }
  }

  private fun readMissingValue(): String? = null

  private fun busyWaitOnMainThread() {
    // Tight loop keeps the main looper busy without sleeping so the
    // platform/Faro watchdog classifies it as an ANR.
    Thread.yield()
  }

  private fun raiseQuickPizzaFailure(message: String): Nothing {
    throw RuntimeException(message)
  }
}
