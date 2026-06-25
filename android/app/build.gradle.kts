import org.gradle.api.tasks.compile.JavaCompile
import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingValue(propertyName: String, environmentName: String): String? {
    return (keystoreProperties[propertyName] as String?)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environmentName)?.takeIf { it.isNotBlank() }
}

fun signingFile(path: String): File {
    val candidate = File(path)
    return if (candidate.isAbsolute) candidate else rootProject.file(path)
}

val releaseStoreFile = signingValue("storeFile", "TITHI_RELEASE_STORE_FILE")
val releaseStorePassword = signingValue("storePassword", "TITHI_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "TITHI_RELEASE_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "TITHI_RELEASE_KEY_PASSWORD")

fun missingReleaseSigningValues(): List<String> {
    return buildList {
        if (releaseStoreFile == null) {
            add("storeFile or TITHI_RELEASE_STORE_FILE")
        } else if (!signingFile(releaseStoreFile).isFile) {
            add("existing keystore file at $releaseStoreFile")
        }
        if (releaseStorePassword == null) {
            add("storePassword or TITHI_RELEASE_STORE_PASSWORD")
        }
        if (releaseKeyAlias == null) {
            add("keyAlias or TITHI_RELEASE_KEY_ALIAS")
        }
        if (releaseKeyPassword == null) {
            add("keyPassword or TITHI_RELEASE_KEY_PASSWORD")
        }
    }
}

android {
    namespace = "app.tithi.pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.tithi.pro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            releaseStoreFile?.let { storeFile = signingFile(it) }
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        create("staging") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            matchingFallbacks += listOf("debug")
        }

        release {
            // Enable R8/ProGuard code shrinking
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")

            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                val outputName = "tithi-${variant.versionName}+${variant.versionCode}-${variant.buildType.name}.apk"
                output.outputFileName = outputName
            }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Required by Flutter's Play Store deferred components integration
    // (FlutterPlayStoreSplitApplication / PlayStoreDeferredComponentManager).
    implementation("com.google.android.play:feature-delivery:2.1.0")
    // App update APIs (separate from split-install classes above).
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")
}

tasks.matching {
    it.name in setOf(
        "validateSigningRelease",
        "packageRelease",
        "bundleRelease",
    )
}.configureEach {
    doFirst {
        val missingValues = missingReleaseSigningValues()
        if (missingValues.isNotEmpty()) {
            throw GradleException(
                "Release signing is not configured. Add android/key.properties " +
                    "from android/key.properties.example or set the TITHI_RELEASE_* " +
                    "environment variables. Missing: ${missingValues.joinToString(", ")}"
            )
        }
    }
}

// Work around Gradle state tracking issue where AGP sometimes does not materialize
// manifest merger blame output for release variants.
tasks.matching { it.name == "processReleaseMainManifest" }.configureEach {
    doNotTrackState("manifest merger blame file can be absent in some AGP/Gradle combinations")
}

tasks.withType<JavaCompile>().configureEach {
    if (name == "compileReleaseJavaWithJavac") {
        doFirst {
            val registrantFile = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")

            if (registrantFile.exists()) {
                val filteredLines = registrantFile.readLines()
                    .filterNot { line -> line.contains("integration_test") }
                registrantFile.writeText(filteredLines.joinToString("\n"))
            }
        }
    }
}
