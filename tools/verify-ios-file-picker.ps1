param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$homeScreenPath = Join-Path $ProjectRoot 'ios\MDOpener\Screens\HomeScreen.swift'
$appModelPath = Join-Path $ProjectRoot 'ios\MDOpener\Model\AppModel.swift'
$homeScreen = Get-Content -Raw -LiteralPath $homeScreenPath
$appModel = Get-Content -Raw -LiteralPath $appModelPath

$checks = [ordered]@{
    'custom markdown UTI is accepted' = $homeScreen.Contains('UTType(importedAs: "net.daringfireball.markdown"')
    'markdown extension type is accepted' = $homeScreen.Contains('UTType(filenameExtension: "md")')
    'security scope starts before detached read' = $appModel.IndexOf('url.startAccessingSecurityScopedResource()') -lt $appModel.IndexOf('Task.detached')
    'document read receives existing scope' = $appModel.Contains('securityScopeAlreadyOpen: scoped')
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
foreach ($check in $checks.GetEnumerator()) {
    $result = if ($check.Value) { 'PASS' } else { 'FAIL' }
    Write-Output ("{0}={1}" -f $check.Key, $result)
}

if ($failed.Count -gt 0) {
    exit 1
}
