# 1️⃣ Interactive input
$version = Read-Host -Prompt "Enter the new app version"

Write-Host "Enter the changelog. Type 'END' on a single line to finish:"
$changelogLines = @()
while ($true) {
    $line = Read-Host -Prompt "Changelog"
    if ($line -eq "END") { break }
    $changelogLines += $line
}
$changelog = $changelogLines -join "`n"
$changelogSingleLine = ($changelog -replace "`r?`n", "\n")

# 2️⃣ Update pubspec.yaml
$pubspec = Get-Content "pubspec.yaml"
$pubspec = $pubspec -replace 'version: .*', "version: $version"
Set-Content "pubspec.yaml" $pubspec
Write-Host "pubspec.yaml updated with version $version"

# 3️⃣ Update gradle.properties (optional)
$gradlePropertiesFile = "android/gradle.properties"
if (Test-Path $gradlePropertiesFile) {
    $gradleProperties = Get-Content $gradlePropertiesFile
    if ($gradleProperties -match 'flutter.versionName=.*') {
        $gradleProperties = $gradleProperties -replace 'flutter.versionName=.*', "flutter.versionName=$version"
        Set-Content $gradlePropertiesFile $gradleProperties
        Write-Host "gradle.properties updated with flutter.versionName=$version"
    }
}

# 4️⃣ Build Flutter release APK
Write-Host "Building Flutter release APK..."
flutter build apk --release --target-platform android-arm64

# 5️⃣ Handle old APK
$destDir = "api\app"
$oldApkDir = ".old_apk"
$oldApk = Get-ChildItem -Path $destDir -Filter "jw-life-*.apk" -File | Select-Object -First 1
$jsonFile = Join-Path $destDir "app_version.json"

if ($oldApk) {
    # Extract version from old APK name: jw-life-1-0-1.apk -> 1.0.1
    if ($oldApk.Name -match "jw-life-(\d+-\d+-\d+)\.apk") {
        $oldVersion = ($matches[1] -replace '-', '.')
        $oldVersionDir = Join-Path $oldApkDir $oldVersion
        if (-not (Test-Path $oldVersionDir)) { New-Item -ItemType Directory -Path $oldVersionDir | Out-Null }

        # Move old APK
        Move-Item $oldApk.FullName (Join-Path $oldVersionDir $oldApk.Name) -Force
        Write-Host "Moved old APK $($oldApk.Name) to $oldVersionDir"

        # Move old JSON
        if (Test-Path $jsonFile) {
            $jsonDest = Join-Path $oldVersionDir ("version-$($oldVersion -replace '\.', '-')"+".json")
            Move-Item $jsonFile $jsonDest -Force
            Write-Host "Moved old JSON to $jsonDest"
        }
    }
}

# 6️⃣ Copy new APK
$apkName = "jw-life-$($version -replace '\.', '-').apk"
$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$destApk = Join-Path $destDir $apkName

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk $destApk -Force
    Write-Host "New APK copied to $destApk"
} else {
    Write-Host "Source APK not found!"
    exit 1
}

# 7️⃣ Generate new app_version JSON
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$json = @(
    [PSCustomObject]@{
        version = $version
        name = $apkName
        timestamp = $timestamp
        changelog = $changelogSingleLine
    }
) | ConvertTo-Json -Depth 4 -Compress

# Ensure api\app folder exists
$jsonFileNew = Join-Path $destDir "app_version.json"
$json | Out-File -Encoding utf8 $jsonFileNew
Write-Host "New JSON generated: $jsonFileNew"
Write-Host "Build and update completed!"
