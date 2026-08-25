#!/bin/bash

# Shared validation for Android release builds. This file is sourced by the
# APK/AAB build scripts and intentionally never reads signing passwords.

ANDROID_KEY_PROPERTIES="$PROJECT_ROOT/android/key.properties"
ANDROID_RELEASE_PROPERTIES="$PROJECT_ROOT/android/release-signing.properties"

android_release_fail() {
    echo "❌ $*" >&2
    return 1
}

read_android_property() {
    local file="$1"
    local key="$2"
    awk -F= -v requested_key="$key" '
        $1 == requested_key {
            value = substr($0, index($0, "=") + 1)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            print value
            exit
        }
    ' "$file"
}

normalize_sha256() {
    printf '%s' "$1" | tr -d '[:space:]:' | tr '[:lower:]' '[:upper:]'
}

load_android_release_metadata() {
    local pubspec_version
    if [[ ! -f "$ANDROID_RELEASE_PROPERTIES" ]]; then
        android_release_fail "Missing android/release-signing.properties"
        return 1
    fi
    pubspec_version=$(awk '$1 == "version:" { print $2; exit }' "$PROJECT_ROOT/pubspec.yaml")
    if [[ ! "$pubspec_version" =~ ^[^+]+\+[0-9]+$ ]]; then
        android_release_fail "pubspec.yaml version must use <name>+<numericCode>: $pubspec_version"
        return 1
    fi
    ANDROID_VERSION_NAME="${pubspec_version%%+*}"
    ANDROID_VERSION_CODE="${pubspec_version##*+}"
    ANDROID_APPLICATION_ID=$(read_android_property "$ANDROID_RELEASE_PROPERTIES" "applicationId")
    ANDROID_EXPECTED_CERT_SHA256=$(normalize_sha256 "$(
        read_android_property "$ANDROID_RELEASE_PROPERTIES" "certificateSha256"
    )")

    if [[ -z "$ANDROID_APPLICATION_ID" ]]; then
        android_release_fail "Missing applicationId in android/release-signing.properties"
        return 1
    fi
    if [[ ! "$ANDROID_EXPECTED_CERT_SHA256" =~ ^[0-9A-F]{64}$ ]]; then
        android_release_fail "certificateSha256 must contain exactly 64 hexadecimal characters"
        return 1
    fi
}

require_android_release_signing() {
    if [[ ! -f "$ANDROID_KEY_PROPERTIES" ]]; then
        android_release_fail "Missing android/key.properties; refusing to build an unsigned or Debug-signed release"
        return 1
    fi

    local property value
    for property in storeFile storePassword keyAlias keyPassword; do
        value=$(read_android_property "$ANDROID_KEY_PROPERTIES" "$property")
        if [[ -z "$value" ]]; then
            android_release_fail "Missing $property in android/key.properties"
            return 1
        fi
    done

    local store_file
    store_file=$(read_android_property "$ANDROID_KEY_PROPERTIES" "storeFile")
    if [[ "$store_file" = /* ]]; then
        ANDROID_RELEASE_KEYSTORE="$store_file"
    else
        # Gradle's file(storeFile) is resolved from android/app.
        ANDROID_RELEASE_KEYSTORE="$PROJECT_ROOT/android/app/$store_file"
    fi
    if [[ ! -f "$ANDROID_RELEASE_KEYSTORE" ]]; then
        android_release_fail "Release keystore not found: $ANDROID_RELEASE_KEYSTORE"
        return 1
    fi
}

resolve_android_sdk_root() {
    if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "$ANDROID_SDK_ROOT" ]]; then
        printf '%s\n' "$ANDROID_SDK_ROOT"
        return 0
    fi
    if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME" ]]; then
        printf '%s\n' "$ANDROID_HOME"
        return 0
    fi

    local local_properties="$PROJECT_ROOT/android/local.properties"
    local configured_sdk=""
    if [[ -f "$local_properties" ]]; then
        configured_sdk=$(read_android_property "$local_properties" "sdk.dir")
    fi
    if [[ -n "$configured_sdk" && -d "$configured_sdk" ]]; then
        printf '%s\n' "$configured_sdk"
        return 0
    fi
    if [[ -d "$HOME/Library/Android/sdk" ]]; then
        printf '%s\n' "$HOME/Library/Android/sdk"
        return 0
    fi
    if [[ -d "$HOME/Android/Sdk" ]]; then
        printf '%s\n' "$HOME/Android/Sdk"
        return 0
    fi
    return 1
}

resolve_android_build_tool() {
    local tool_name="$1"
    if command -v "$tool_name" >/dev/null 2>&1; then
        command -v "$tool_name"
        return 0
    fi

    local sdk_root
    sdk_root=$(resolve_android_sdk_root) || return 1
    find "$sdk_root/build-tools" -mindepth 2 -maxdepth 2 -type f -name "$tool_name" \
        2>/dev/null | sort | tail -1
}

assert_release_artifact_name() {
    local artifact="$1"
    local extension="$2"
    local expected_name="flutter-Wallet-v${ANDROID_VERSION_NAME}.${extension}"
    if [[ "$(basename "$artifact")" != "$expected_name" ]]; then
        android_release_fail "Unexpected release filename: $(basename "$artifact") (expected $expected_name)"
        return 1
    fi
}

assert_release_certificate() {
    local actual_sha256
    actual_sha256=$(normalize_sha256 "$1")
    if [[ "$actual_sha256" != "$ANDROID_EXPECTED_CERT_SHA256" ]]; then
        android_release_fail "Release certificate SHA-256 mismatch"
        echo "   Expected: $ANDROID_EXPECTED_CERT_SHA256" >&2
        echo "   Actual:   ${actual_sha256:-<missing>}" >&2
        return 1
    fi
    echo "✅ Release certificate SHA-256 verified: $actual_sha256"
}

verify_android_apk() {
    local artifact="$1"
    assert_release_artifact_name "$artifact" "apk" || return 1

    local apksigner
    apksigner=$(resolve_android_build_tool "apksigner")
    if [[ -z "$apksigner" || ! -x "$apksigner" ]]; then
        android_release_fail "Android SDK apksigner was not found"
        return 1
    fi

    local certificate_output actual_sha256
    certificate_output=$("$apksigner" verify --verbose --print-certs "$artifact") || {
        android_release_fail "APK signature verification failed: $artifact"
        return 1
    }
    actual_sha256=$(printf '%s\n' "$certificate_output" | awk -F': ' \
        '/certificate SHA-256 digest:/ { print $2; exit }')
    assert_release_certificate "$actual_sha256" || return 1

    local aapt package_line actual_id actual_version_name actual_version_code
    aapt=$(resolve_android_build_tool "aapt")
    if [[ -z "$aapt" || ! -x "$aapt" ]]; then
        android_release_fail "Android SDK aapt was not found"
        return 1
    fi
    package_line=$("$aapt" dump badging "$artifact" | awk '/^package:/ { print; exit }')
    actual_id=$(printf '%s\n' "$package_line" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")
    actual_version_code=$(printf '%s\n' "$package_line" | sed -n "s/^package: name='[^']*' versionCode='\([^']*\)'.*/\1/p")
    actual_version_name=$(printf '%s\n' "$package_line" | sed -n "s/^package: name='[^']*' versionCode='[^']*' versionName='\([^']*\)'.*/\1/p")
    if [[ "$actual_id" != "$ANDROID_APPLICATION_ID" ||
          "$actual_version_name" != "$ANDROID_VERSION_NAME" ||
          "$actual_version_code" != "$ANDROID_VERSION_CODE" ]]; then
        android_release_fail "APK identity/version mismatch"
        echo "   Expected: $ANDROID_APPLICATION_ID $ANDROID_VERSION_NAME+$ANDROID_VERSION_CODE" >&2
        echo "   Actual:   ${actual_id:-<missing>} ${actual_version_name:-<missing>}+${actual_version_code:-<missing>}" >&2
        return 1
    fi
    echo "✅ APK identity verified: $actual_id $actual_version_name+$actual_version_code"
}

verify_android_aab() {
    local artifact="$1"
    assert_release_artifact_name "$artifact" "aab" || return 1

    local jarsigner keytool
    jarsigner=$(command -v jarsigner || true)
    keytool=$(command -v keytool || true)
    if [[ -z "$jarsigner" || -z "$keytool" ]]; then
        android_release_fail "JDK jarsigner and keytool are required to verify an AAB"
        return 1
    fi
    "$jarsigner" -verify "$artifact" >/dev/null 2>&1 || {
        android_release_fail "AAB signature verification failed: $artifact"
        return 1
    }

    local actual_sha256
    actual_sha256=$("$keytool" -printcert -jarfile "$artifact" 2>/dev/null | \
        awk '$1 == "SHA256:" { print $2; exit }')
    if [[ -z "$actual_sha256" ]]; then
        android_release_fail "AAB does not contain a readable signing certificate"
        return 1
    fi
    assert_release_certificate "$actual_sha256" || return 1
    verify_release_build_metadata || return 1
    echo "✅ AAB identity verified: $ANDROID_APPLICATION_ID $ANDROID_VERSION_NAME+$ANDROID_VERSION_CODE"
}

verify_release_build_metadata() {
    local metadata_root="$PROJECT_ROOT/build/app/intermediates/merged_manifests/release"
    local metadata_file
    metadata_file=$(find "$metadata_root" -type f -name output-metadata.json \
        2>/dev/null | sort | tail -1)
    if [[ -z "$metadata_file" || ! -f "$metadata_file" ]]; then
        android_release_fail "Release manifest metadata was not generated"
        return 1
    fi

    local actual_id actual_variant actual_version_name actual_version_code
    actual_id=$(sed -n 's/.*"applicationId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$metadata_file" | head -1)
    actual_variant=$(sed -n 's/.*"variantName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$metadata_file" | head -1)
    actual_version_name=$(sed -n 's/.*"versionName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$metadata_file" | head -1)
    actual_version_code=$(sed -n 's/.*"versionCode"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
        "$metadata_file" | head -1)
    if [[ "$actual_id" != "$ANDROID_APPLICATION_ID" ||
          "$actual_variant" != "release" ||
          "$actual_version_name" != "$ANDROID_VERSION_NAME" ||
          "$actual_version_code" != "$ANDROID_VERSION_CODE" ]]; then
        android_release_fail "AAB release manifest metadata mismatch"
        echo "   Expected: release $ANDROID_APPLICATION_ID $ANDROID_VERSION_NAME+$ANDROID_VERSION_CODE" >&2
        echo "   Actual:   ${actual_variant:-<missing>} ${actual_id:-<missing>} ${actual_version_name:-<missing>}+${actual_version_code:-<missing>}" >&2
        return 1
    fi
}

write_release_checksum() {
    local artifact="$1"
    local checksum_file="${artifact}.sha256"
    local digest
    if command -v shasum >/dev/null 2>&1; then
        digest=$(shasum -a 256 "$artifact" | awk '{ print $1 }')
    elif command -v sha256sum >/dev/null 2>&1; then
        digest=$(sha256sum "$artifact" | awk '{ print $1 }')
    else
        android_release_fail "Neither shasum nor sha256sum is available"
        return 1
    fi
    printf '%s  %s\n' "$digest" "$(basename "$artifact")" > "$checksum_file"
    echo "✅ SHA-256 checksum: $checksum_file"
}
