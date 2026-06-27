import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            )
        }
    }
    // Keep Java compilation on the same JVM target as Kotlin (above). Some
    // plugins (e.g. flutter_timezone, flutter_tts) declare their Java
    // compileOptions at 11 while their Kotlin targets 17, which Gradle rejects
    // as inconsistent. Apply this AFTER AGP configures (afterEvaluate) so it
    // wins. :app is already evaluated (evaluationDependsOn above) and is on 17
    // anyway, so configure it directly to avoid an afterEvaluate-after-eval error.
    val alignJavaTarget: Project.() -> Unit = {
        // Set on the AGP library extension so AGP regenerates the Java task at
        // 17 (a raw task override doesn't satisfy KGP's consistency check).
        extensions.findByType(LibraryExtension::class.java)?.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
    if (state.executed) alignJavaTarget() else afterEvaluate { alignJavaTarget() }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
