package com.follow.clash.common


import android.app.Application
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.crashlytics.FirebaseCrashlytics
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

object GlobalState : CoroutineScope by CoroutineScope(Dispatchers.Default) {

    const val NOTIFICATION_CHANNEL = "FlClash"

    const val NOTIFICATION_ID = 1

    val packageName: String
        get() = application.packageName

    val RECEIVE_BROADCASTS_PERMISSIONS: String
        get() = "${packageName}.permission.RECEIVE_BROADCASTS"


    private var _application: Application? = null

    val application: Application
        get() = _application!!


    fun log(text: String) {
        Log.d("[FlClash]", text)
    }

    fun init(application: Application) {
        _application = application
    }

    fun setCrashlytics(enable: Boolean) {
        val app = _application ?: return
        if (!enable) {
            runCatching {
                FirebaseCrashlytics.getInstance().isCrashlyticsCollectionEnabled = false
            }
            return
        }
        runCatching {
            val firebaseApp = FirebaseApp.initializeApp(app)
            if (firebaseApp == null) {
                log("Firebase not configured; skip Crashlytics init")
                return@runCatching
            }
            FirebaseCrashlytics.getInstance().isCrashlyticsCollectionEnabled = true
            log("init crashlytics ${app.processName}")
        }.onFailure {
            log("Crashlytics init failed: ${it.message}")
        }
    }
}
