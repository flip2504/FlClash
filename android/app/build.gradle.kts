import groovy.json.JsonSlurper
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
    id("com.google.firebase.crashlytics") apply false
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val brandApplicationId: String? = localProperties.getProperty("brand.applicationId")
val brandAppName: String? = localProperties.getProperty("brand.appName")

fun googleServicesHasClientForPackage(jsonFile: File, applicationId: String): Boolean {
    return try {
        val parsed = JsonSlurper().parse(jsonFile) as? Map<*, *> ?: return false
        val clients = parsed["client"] as? List<*> ?: return false
        clients.any { client ->
            val clientMap = client as? Map<*, *> ?: return@any false
            val clientInfo = clientMap["client_info"] as? Map<*, *> ?: return@any false
            val androidInfo = clientInfo["android_client_info"] as? Map<*, *> ?: return@any false
            val pkg = androidInfo["package_name"] as? String
            pkg == applicationId
        }
    } catch (_: Exception) {
        false
    }
}

val resolvedApplicationId = (brandApplicationId ?: "com.follow.clash").trim()
val googleServicesJsonFile = file("google-services.json")
val hasGoogleServicesJson =
    googleServicesJsonFile.let { it.exists() && it.length() > 0 } &&
        googleServicesHasClientForPackage(googleServicesJsonFile, resolvedApplicationId)

if (hasGoogleServicesJson) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    println("google-services.json missing or does not match applicationId=$resolvedApplicationId; skipping Firebase plugins")
}

val mStoreFile: File = file("keystore.jks")
val mStorePassword: String? = localProperties.getProperty("storePassword")
val mKeyAlias: String? = localProperties.getProperty("keyAlias")
val mKeyPassword: String? = localProperties.getProperty("keyPassword")
val isRelease =
    mStoreFile.exists() && mStorePassword != null && mKeyAlias != null && mKeyPassword != null


android {
    namespace = "com.follow.clash"
    compileSdk = libs.versions.compileSdk.get().toInt()
    ndkVersion = libs.versions.ndkVersion.get()



    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = resolvedApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = libs.versions.targetSdk.get().toInt()
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resValue("string", "app_name", brandAppName ?: "FlClash")
    }

    signingConfigs {
        if (isRelease) {
            create("release") {
                storeFile = mStoreFile
                storePassword = mStorePassword
                keyAlias = mKeyAlias
                keyPassword = mKeyPassword
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (isRelease) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}


dependencies {
    implementation(project(":service"))
    implementation(project(":common"))
    implementation(libs.core.splashscreen)
    implementation(libs.gson)
    implementation(libs.smali.dexlib2) {
        exclude(group = "com.google.guava", module = "guava")
    }
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.crashlytics.ndk)
    implementation(libs.firebase.analytics)
}
