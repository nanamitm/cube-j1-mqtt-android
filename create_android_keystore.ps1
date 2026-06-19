param(
    [string]$KeystorePath       = ".\keystore\cubej1mqtt-release.jks",
    [string]$Alias              = "cubej1mqtt",
    [string]$CommonName         = "Cube J1 MQTT",
    [string]$OrganizationalUnit = "Personal",
    [string]$Organization       = "nanamitm",
    [string]$Country            = "JP",
    [int]   $ValidityDays       = 10950   # 30 years
)

$ErrorActionPreference = "Stop"

$keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if (!(Test-Path $keytool)) { throw "keytool not found: $keytool" }

$keystoreFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KeystorePath)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $keystoreFullPath) | Out-Null

if (Test-Path $keystoreFullPath) { throw "Keystore already exists: $keystoreFullPath" }

function New-RandomPassword([int]$Length = 24) {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

$storePasswordText = New-RandomPassword
$keyPasswordText   = New-RandomPassword

& $keytool -genkeypair -v `
    -keystore $keystoreFullPath -storetype JKS `
    -alias $Alias -keyalg RSA -keysize 2048 -validity $ValidityDays `
    -dname "CN=$CommonName, OU=$OrganizationalUnit, O=$Organization, C=$Country" `
    -storepass $storePasswordText -keypass $keyPasswordText

$content = "storeFile=$KeystorePath`nstorePassword=$storePasswordText`nkeyAlias=$Alias`nkeyPassword=$keyPasswordText`n"
[System.IO.File]::WriteAllText((Join-Path (Resolve-Path ".").Path "android-signing.properties"), $content, [System.Text.UTF8Encoding]::new($false))

Write-Host "Created keystore : $keystoreFullPath"
Write-Host "Created          : android-signing.properties"
Write-Host "Keep both private and back them up somewhere safe. Do NOT commit them."
Write-Host "Losing the keystore means future releases can never be signed with the same key again."
