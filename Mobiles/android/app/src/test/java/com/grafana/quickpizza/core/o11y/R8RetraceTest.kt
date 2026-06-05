package com.grafana.quickpizza.core.o11y

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import proguard.retrace.ReTrace
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.LineNumberReader
import java.io.PrintWriter
import java.io.StringReader
import java.nio.charset.StandardCharsets

/**
 * Verifies that a fixed obfuscated stack + mapping fixture deobfuscate with ProGuard ReTrace
 * (same tool chain as Android SDK `retrace` / server-side R8 retrace).
 */
class R8RetraceTest {

    @Test
    fun sampleObfuscatedStackDeobfuscatesToDebugViewModel() {
        val mappingFile = File.createTempFile("quickpizza-mapping", ".txt")
        mappingFile.deleteOnExit()
        mappingFile.writeText(SAMPLE_MAPPING)

        val output = ByteArrayOutputStream()
        val reTrace = ReTrace(mappingFile)
        reTrace.retrace(
            LineNumberReader(StringReader(SAMPLE_OBFUSCATED_STACK)),
            PrintWriter(output, true, StandardCharsets.UTF_8),
        )

        val retraced = output.toString(StandardCharsets.UTF_8)
        assertFalse("Expected obfuscated class name to disappear", retraced.contains("a5.r0"))
        assertTrue(
            "Expected deobfuscated DebugViewModel frame, got:\n$retraced",
            retraced.contains("com.grafana.quickpizza.features.debug.DebugViewModel.triggerRuntimeCrash") &&
                retraced.contains(":163"),
        )
    }

    private companion object {
        const val SAMPLE_MAPPING = """
            com.grafana.quickpizza.features.debug.DebugViewModel -> a5.r0:
                163:163:void triggerRuntimeCrash():163:163 -> invoke
        """

        const val SAMPLE_OBFUSCATED_STACK = """
            java.lang.RuntimeException: Deliberate crash from QuickPizza debug tab
                at a5.r0.invoke(DebugViewModel.kt:163)
                at a5.r0.invoke(Unknown Source)
                at kotlinx.coroutines.internal.DispatchedContinuationKt.resumeCancellableWith(DispatchedContinuation.kt:375)
        """
    }
}
