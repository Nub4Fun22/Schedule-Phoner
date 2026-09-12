#!/usr/bin/env bash
#
# Aligns the JVM target to 17 for both Java and Kotlin across ALL Gradle
# subprojects (i.e. every plugin module). This avoids the Gradle error:
#
#   Inconsistent JVM-target compatibility detected for tasks
#   'compileReleaseJavaWithJavac' (11) and 'compileReleaseKotlin' (1.8).
#
# which some plugins (e.g. flutter_timezone) trigger on newer Gradle.
#
# Run this AFTER `flutter create . --platforms=android` and BEFORE the build.
set -euo pipefail

GROOVY="android/build.gradle"
KTS="android/build.gradle.kts"

read -r -d '' GROOVY_SNIPPET <<'GRADLE' || true

// --- injected by ci/align_jvm_targets.sh: force consistent JVM target ---
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.android {
                compileOptions {
                    sourceCompatibility JavaVersion.VERSION_17
                    targetCompatibility JavaVersion.VERSION_17
                }
            }
        }
        project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
}
// --- end injected block ---
GRADLE

read -r -d '' KTS_SNIPPET <<'GRADLEKTS' || true

// --- injected by ci/align_jvm_targets.sh: force consistent JVM target ---
subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            kotlinOptions { jvmTarget = "17" }
        }
    }
}
// --- end injected block ---
GRADLEKTS

if [ -f "$GROOVY" ]; then
  echo "Patching Groovy $GROOVY"
  printf '%s\n' "$GROOVY_SNIPPET" >> "$GROOVY"
  echo "----- tail of $GROOVY -----"
  tail -25 "$GROOVY"
elif [ -f "$KTS" ]; then
  echo "Patching Kotlin-DSL $KTS"
  printf '%s\n' "$KTS_SNIPPET" >> "$KTS"
  echo "----- tail of $KTS -----"
  tail -25 "$KTS"
else
  echo "ERROR: neither $GROOVY nor $KTS was found after 'flutter create'." >&2
  exit 1
fi
