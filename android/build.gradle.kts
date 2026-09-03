allprojects {
    repositories {
        google()
        mavenCentral()
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

// Kotlin 2.x refuses to compile against a type whose annotations it cannot
// resolve. Several Firebase plugins call into Play Services / Guava APIs that
// carry Checker Framework annotations (`@UnknownInitialization` and friends),
// and those annotations are not pulled in transitively - which surfaces as:
//
//   e: ... Type annotation class
//   'org.checkerframework.checker.initialization.qual.UnknownInitialization'
//   of the inferred type is inaccessible.
//
// Putting checker-qual on every Android module's compile classpath resolves
// them. It is compileOnly, so nothing is added to the shipped APK.
subprojects {
    plugins.withId("com.android.library") {
        dependencies {
            add("compileOnly", "org.checkerframework:checker-qual:3.49.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
