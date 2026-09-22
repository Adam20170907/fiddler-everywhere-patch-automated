param(
    [Parameter(Mandatory = $true)]
    [string]$Root = "FE/resources/app/out"
)

$expectedPath = Join-Path $Root "file/identity.getfiddler.com/oauth/token.json"

# Prefer an existing token.json, even if the upstream application moved it.
$tokenFile = Get-ChildItem -Path $Root -Filter "token.json" -File -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($null -ne $tokenFile) {
    $sourceJson = $tokenFile.FullName
    try {
        $config = Get-Content -LiteralPath $sourceJson -Raw | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in '$sourceJson': $($_.Exception.Message)"
    }
}
else {
    $sourceJson = $expectedPath
    $parent = Split-Path -Parent $sourceJson
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    # Do not commit a real id_token. Supply it through the FIDDLER_ID_TOKEN
    # environment variable/secret, or leave it empty when it is not required.
    $config = [ordered]@{
        id_token   = if ($null -ne $env:FIDDLER_ID_TOKEN) { $env:FIDDLER_ID_TOKEN } else { "" }
        expires_in = 3539
        token_type = "Bearer"
        user_info  = [ordered]@{
            id         = "4fdf39f32f284b28a21aaad1f34b6994"
            email      = $env:PATCH_USER_EMAIL
            firstName  = $env:PATCH_USER_FNAME
            lastName   = $env:PATCH_USER_LNAME
            country    = $env:PATCH_USER_COUNTRYCODE
            identities = @(
                [ordered]@{
                    providerName = $env:PATCH_USER_PROVIDER
                }
            )
        }
    }

    Write-Warning "token.json was not found; created '$sourceJson'."
}

# Apply workflow inputs to both an existing and a newly created configuration.
if ($null -eq $config.user_info) {
    $config | Add-Member -MemberType NoteProperty -Name user_info -Value ([pscustomobject]@{})
}

$config.user_info.email = $env:PATCH_USER_EMAIL
$config.user_info.firstName = $env:PATCH_USER_FNAME
$config.user_info.lastName = $env:PATCH_USER_LNAME
$config.user_info.country = $env:PATCH_USER_COUNTRYCODE

if ($null -eq $config.user_info.identities -or $config.user_info.identities.Count -eq 0) {
    $config.user_info.identities = @([pscustomobject]@{ providerName = $env:PATCH_USER_PROVIDER })
}
else {
    $config.user_info.identities[0].providerName = $env:PATCH_USER_PROVIDER
}

$config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceJson -Encoding UTF8
Write-Host "Credentials written to: $sourceJson"
