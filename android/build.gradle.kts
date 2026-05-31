allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// yandex_mapkit 4.2.x bumped maps.mobile to 4.22.0 but its Java code still
// references MapObjectTapListener/ClusterTapListener removed in that version.
// Force the version that the plugin's Java code was actually written against.
subprojects {
    configurations.all {
        resolutionStrategy {
            force("com.yandex.android:maps.mobile:4.6.1-lite")
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
