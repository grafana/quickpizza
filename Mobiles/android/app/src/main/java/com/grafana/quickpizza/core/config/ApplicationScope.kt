package com.grafana.quickpizza.core.config

import javax.inject.Qualifier

/**
 * Marker for an application-scoped [kotlinx.coroutines.CoroutineScope] —
 * lives for the entire process lifetime, used for fire-and-forget background
 * work (e.g. keeping a hot StateFlow in sync with DataStore).
 */
@Qualifier
@Retention(AnnotationRetention.RUNTIME)
annotation class ApplicationScope
