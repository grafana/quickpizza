package com.grafana.quickpizza.core.api

import com.google.gson.Gson
import okhttp3.Call
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ApiClient @Inject constructor(
    // Call.Factory is the minimal OkHttp interface — OkHttpClient and the OkHttpTelemetry
    // wrapper both implement it. Using Call.Factory here lets us accept the instrumented
    // wrapper returned by OkHttpTelemetry.newCallFactory() without an unsafe cast.
    private val callFactory: Call.Factory,
    private val baseUrlProvider: () -> String,
    private val tokenProvider: () -> String?,
) {
    private val gson = Gson()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    fun get(endpoint: String): Response {
        val request = Request.Builder()
            .url("${baseUrlProvider()}$endpoint")
            .applyAuthHeader()
            .get()
            .build()
        return callFactory.newCall(request).execute()
    }

    fun post(
        endpoint: String,
        body: Any? = null,
        includeAuth: Boolean = true,
    ): Response {
        val requestBody = if (body != null) {
            gson.toJson(body).toRequestBody(jsonMediaType)
        } else {
            "{}".toRequestBody(jsonMediaType)
        }
        val builder = Request.Builder()
            .url("${baseUrlProvider()}$endpoint")
            .post(requestBody)
        if (includeAuth) builder.applyAuthHeader()
        return callFactory.newCall(builder.build()).execute()
    }

    fun delete(endpoint: String): Response {
        val request = Request.Builder()
            .url("${baseUrlProvider()}$endpoint")
            .applyAuthHeader()
            .delete()
            .build()
        return callFactory.newCall(request).execute()
    }

    private fun Request.Builder.applyAuthHeader(): Request.Builder {
        val token = tokenProvider()
        if (!token.isNullOrEmpty()) {
            addHeader("Authorization", "Token $token")
        }
        return this
    }
}

fun buildBaseOkHttpClient(timeoutSeconds: Long = 10): OkHttpClient =
    OkHttpClient.Builder()
        .connectTimeout(timeoutSeconds, TimeUnit.SECONDS)
        .readTimeout(timeoutSeconds, TimeUnit.SECONDS)
        .writeTimeout(timeoutSeconds, TimeUnit.SECONDS)
        .build()
