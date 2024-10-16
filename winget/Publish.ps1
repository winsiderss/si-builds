param (
    [ValidateSet("Canary", "Release")]
    [string]$Channel,
    [string]$Version,
    [string]$Submit,
    [string]$Output
)

# Fetch the latest release data from GitHub API
$releasesUrl = "https://api.github.com/repos/winsiderss/si-builds/releases"
$releases = Invoke-RestMethod -Uri $releasesUrl

# Find the appropriate release based on Channel and Version
$release = if ($Version -eq "Latest")
{
    $releases[0]
}
else
{
    $releases | Where-Object { $_.tag_name -eq $Version } | Select-Object -First 1
}
if (-not $release)
{
    Write-Host "No matching release found for Channel: $Channel and Version: $Version"
    exit 1
}

# Find the setup binary URL
$setupAsset = $release.assets | Where-Object { $_.name -match "$Channel-setup.exe" } | Select-Object -First 1
if (-not $setupAsset)
{
    Write-Host "No setup binary found for Channel: $Channel in release: $($release.tag_name)"
    exit 1
}

Write-Host "Setup URL: $($setupAsset.browser_download_url)"

# Download the setup binary
$setupBinary = Join-Path -Path $env:TEMP -ChildPath $setupAsset.name
Invoke-WebRequest -Uri $setupAsset.browser_download_url -OutFile $setupBinary

$setupVersion = (Get-Item $setupBinary).VersionInfo.FileVersion

# Download the latest wingetcreate
$wingetCreate = Join-Path -Path $env:TEMP -ChildPath "wingetcreate.exe"
Invoke-WebRequest -Uri "https://aka.ms/wingetcreate/latest" -OutFile $wingetCreate

$identifier = if ($Channel -eq "Canary")
{
    "WinsiderSS.SystemInformer.Canary"
}
else
{
    "WinsiderSS.SystemInformer"
}

# Publish to winget...

Write-Host "Publishing: $identifier $setupVersion"

$wingetCreateArgs = @(
    "update",
    "--urls", "$($setupAsset.browser_download_url)|neutral",
    "--version", $setupVersion
)

if ($Output)
{
    $wingetCreateArgs += @("--out", $Output)
}

if ($Submit)
{
    $wingetCreateArgs += @(
        "--submit",
        "--token", $Submit
        )
}

$wingetCreateArgs += @($identifier)

$process = Start-Process -FilePath $wingetCreate -ArgumentList $wingetCreateArgs -PassThru -Wait -NoNewWindow

if ($process.ExitCode -ne 0)
{
    Write-Host "wingetcreate failed with exit code: $($process.ExitCode)"
    exit 1
}

Write-Host "Published $identifier $setupVersion"
exit 0
