# Build a release APK on your PC (requires Flutter + Android SDK).
# Run from project root:  powershell -ExecutionPolicy Bypass -File .\scripts\build_release_apk.ps1
#
# You must have android\app\google-services.json (from Firebase Console).
#
# Optional env vars before running:
#   $env:GEMINI_API_KEY = "..."     # optional: embed key (demo only)
#   $env:CHATBOT_WS_URL = "ws://..." # optional: use NLTK server instead of Gemini

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter is not in PATH. Install Flutter and run this script again."
    exit 1
}

if (-not (Test-Path "android\app\google-services.json")) {
    Write-Error "Missing android\app\google-services.json — download it from Firebase Console (Project settings → Your apps → Android)."
    exit 1
}

flutter pub get

$dd = @()
if ($env:GEMINI_API_KEY) { $dd += "--dart-define=GEMINI_API_KEY=$($env:GEMINI_API_KEY)" }
if ($env:CHATBOT_WS_URL) { $dd += "--dart-define=CHATBOT_WS_URL=$($env:CHATBOT_WS_URL)" }
if ($env:CHATBOT_HTTP_BASE) { $dd += "--dart-define=CHATBOT_HTTP_BASE=$($env:CHATBOT_HTTP_BASE)" }

& flutter build apk --release @dd

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    Write-Host "OK: $((Resolve-Path $apk).Path)"
} else {
    Write-Error "APK not found at $apk"
    exit 1
}
