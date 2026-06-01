allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// yandex_mapkit 4.2.x declares maps.mobile:4.22.0 but its Java code uses
// MapObjectTapListener/ClusterTapListener removed in 4.22.0, and LineStyle/
// setHeadingModeActive not yet present in 4.6.1. 4.19.0 is the latest version
// that has all four APIs simultaneously.
subprojects {
    configurations.all {
        resolutionStrategy {
            force("com.yandex.android:maps.mobile:4.19.0-lite")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
