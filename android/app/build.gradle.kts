import com.android.build.api.variant.VariantOutputConfiguration
import org.gradle.api.tasks.compile.JavaCompile
import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release keeps the canonical id; development build types get their own ids
// so they install side by side instead of replacing a release install.
val baseApplicationId = "app.tithi.pro"

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
    namespace = baseApplicationId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = baseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Flutter's --split-per-abi offsets each output's versionCode by
        // abiIndex * 1000, but the in-app updater must compare against the
        // base +N in the GitHub release tag. Publish the pre-offset value in
        // manifest meta-data so Kotlin can expose it over the update channel.
        manifestPlaceholders["baseBuildNumber"] = flutter.versionCode.toString()
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
            // Flutter 3.50 propagates applicationIdSuffix to native library
            // modules, which AGP correctly rejects for library projects.
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

}

// APK output naming is configured through the public variant API in AGP 9.
androidComponents {
    onVariants { variant ->
        // Set the id on the variant itself instead of using build-type
        // applicationIdSuffix: Flutter copies app build types onto plugin
        // library modules with initWith(), and suffixes are invalid there.
        // The manifest's ${applicationId} placeholder (FileProvider authority)
        // follows this value; the Kotlin namespace stays `app.tithi.pro`.
        when (variant.name) {
            "debug" -> variant.applicationId.set("$baseApplicationId.debug")
            "profile" -> variant.applicationId.set("$baseApplicationId.profile")
        }

        variant.outputs.forEach { output ->
            if (output.outputType == VariantOutputConfiguration.OutputType.SINGLE) {
                val outputName =
                    "tithi-${output.versionName.get()}+${output.versionCode.get()}-${variant.name}.apk"
                output.outputFileName.set(outputName)
            }
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
