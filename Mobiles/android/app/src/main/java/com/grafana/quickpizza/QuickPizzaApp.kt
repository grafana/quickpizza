package com.grafana.quickpizza

import android.app.Application
import com.grafana.quickpizza.core.o11y.OTelService
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class QuickPizzaApp : Application() {

    @Inject
    lateinit var otelService: OTelService

    override fun onCreate() {
        super.onCreate()
        otelService.initialize()
    }
}
