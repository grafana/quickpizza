package com.grafana.quickpizza

import android.app.Application
import com.grafana.quickpizza.core.config.RuntimeConfigHolder
import com.grafana.quickpizza.core.o11y.OTelService
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class QuickPizzaApp : Application() {

    @Inject
    lateinit var runtimeConfig: RuntimeConfigHolder

    @Inject
    lateinit var otelService: OTelService

    override fun onCreate() {
        super.onCreate()
        // Resolve the in-use URLs before anything else so OTelService and
        // ApiClient see the same snapshot for the rest of the session.
        runtimeConfig.current
        otelService.initialize()
    }
}
