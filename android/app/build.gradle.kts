import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val releaseSigningPropertyNames = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val missingReleaseSigningProperties = releaseSigningPropertyNames.filter {
    keystoreProperties[it]?.toString()?.trim().isNullOrEmpty()
}
val releaseStoreFile = keystoreProperties["storeFile"]
    ?.toString()
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?.let { file(it) }
fun isReleaseArtifactTask(taskName: String): Boolean {
    val simpleName = taskName.substringAfterLast(':')
    return simpleName.contains("release", ignoreCase = true) &&
        listOf("assemble", "bundle", "package").any {
            simpleName.startsWith(it, ignoreCase = true)
        }
}

fun requireReleaseSigningConfig() {
    when {
        !keystorePropertiesFile.isFile -> throw GradleException(
            "Android release signing requires android/key.properties",
        )
        missingReleaseSigningProperties.isNotEmpty() -> throw GradleException(
            "Missing Android release signing properties: " +
                missingReleaseSigningProperties.joinToString(", "),
        )
        releaseStoreFile?.isFile != true -> throw GradleException(
            "Android release keystore does not exist: " +
                (releaseStoreFile?.path ?: "<missing storeFile>"),
        )
    }
}

if (gradle.startParameter.taskNames.any(::isReleaseArtifactTask)) {
    requireReleaseSigningConfig()
}

// Commands such as `gradlew build` add assembleRelease transitively, so their
// start task name alone is not enough. Recheck the resolved task graph before
// any Release artifact task can execute.
val appProject = project
gradle.taskGraph.whenReady {
    if (allTasks.any { task ->
            task.project == appProject && isReleaseArtifactTask(task.name)
        }
    ) {
        requireReleaseSigningConfig()
    }
}

val hasReleaseSigningConfig =
    keystorePropertiesFile.isFile &&
        missingReleaseSigningProperties.isEmpty() &&
        releaseStoreFile?.isFile == true

android {
    namespace = "com.zx.wallet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zx.wallet"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"].toString().trim()
                keyPassword = keystoreProperties["keyPassword"].toString()
                storeFile = releaseStoreFile
                storePassword = keystoreProperties["storePassword"].toString()
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
