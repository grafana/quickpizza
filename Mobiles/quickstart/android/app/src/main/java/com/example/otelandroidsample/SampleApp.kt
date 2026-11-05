package com.example.otelandroidsample

import android.app.Application

class SampleApp : Application() {
    override fun onCreate() {
        super.onCreate()
        OTel.start(this) // first thing, so startup, crashes and the first screen are captured
    }
}
