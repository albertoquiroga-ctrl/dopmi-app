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

// Stripe assumes AGP 9 uses built-in Kotlin. Flutter currently opts out of it,
// so match Stripe's Java 17 bytecode explicitly when using the Kotlin plugin.
subprojects {
    if (name == "stripe_android") {
        // stripe_android declares its optional Issuing bridge twice. Keep the
        // compile-only bridge, but prevent the transitive declaration from
        // making release lint resolve Google's private TapAndPay SDK.
        configurations.configureEach {
            withDependencies {
                filterIsInstance<org.gradle.api.artifacts.ExternalModuleDependency>()
                    .filter {
                        it.group == "com.stripe" &&
                            it.name == "stripe-android-issuing-push-provisioning"
                    }
                    .forEach { it.isTransitive = false }
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
