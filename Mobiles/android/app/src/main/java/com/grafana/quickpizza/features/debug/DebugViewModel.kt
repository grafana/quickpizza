package com.grafana.quickpizza.features.debug

import androidx.lifecycle.ViewModel
import com.grafana.quickpizza.core.o11y.AppLogger
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class DebugViewModel @Inject constructor(
    private val logger: AppLogger,
) : ViewModel() {

    fun logTestException() {
        val error = RuntimeException("Test exception from Debug tab")
        logger.exception("Test exception triggered by user", error)
    }

    fun triggerCrash() {
        // This will be caught by the OTel crash reporter and generate a crash log
        throw RuntimeException("Deliberate crash triggered from Debug tab")
    }

    fun triggerAnr() {
        // Block the main thread long enough to exceed Android's 5s ANR threshold
        Thread.sleep(6000)
    }
}
