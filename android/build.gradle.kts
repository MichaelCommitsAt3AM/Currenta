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
    
    val fixLintDependency = Action<AppliedPlugin> {
        tasks.matching { it.name.contains("Lint", ignoreCase = true) }.configureEach {
            if (project.name != "app") {
                try {
                    dependsOn(":app:extractProguardFiles")
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }
    pluginManager.withPlugin("com.android.library", fixLintDependency)
    pluginManager.withPlugin("com.android.application", fixLintDependency)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
