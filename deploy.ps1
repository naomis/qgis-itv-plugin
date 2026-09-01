param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'deploy.config.ps1')
)

$ErrorActionPreference = 'Stop'

$defaultConfig = @{
    QgisPluginsPath    = (Join-Path $env:APPDATA 'QGIS\QGIS3\profiles\default\python\plugins')
    PluginDirectoryName = (Split-Path -Leaf $PSScriptRoot)
}

$config = @{}
foreach ($key in $defaultConfig.Keys) {
    $config[$key] = $defaultConfig[$key]
}

if (Test-Path -LiteralPath $ConfigPath) {
    . $ConfigPath
    if ($DeployConfig) {
        foreach ($key in $DeployConfig.Keys) {
            $config[$key] = $DeployConfig[$key]
        }
    }
}

$sourceDir = $PSScriptRoot
$targetRoot = $config['QgisPluginsPath']
$pluginDirName = $config['PluginDirectoryName']
$targetDir = Join-Path $targetRoot $pluginDirName

if (-not (Test-Path -LiteralPath $targetRoot)) {
    throw "Le dossier cible n'existe pas: $targetRoot"
}

$excludeDirs = @(
    '.git',
    '__pycache__',
    '.pytest_cache',
    '.mypy_cache',
    '.ruff_cache',
    '.cache'
)

$excludeFiles = @(
    '.gitignore',
    '.gitattributes',
    '.gitmodules',
    '*.pyc',
    '*.pyo'
)

$robocopyArgs = @(
    $sourceDir,
    $targetDir,
    '/MIR',
    '/R:1',
    '/W:1',
    '/XD'
) + $excludeDirs + @(
    '/XF'
) + $excludeFiles

Write-Host "Deploiement: $sourceDir -> $targetDir"
& robocopy @robocopyArgs

$robocopyExitCode = $LASTEXITCODE
if ($robocopyExitCode -ge 8) {
    throw "Echec de la copie (robocopy exit code: $robocopyExitCode)"
}

Write-Host "Deploiement termine (robocopy exit code: $robocopyExitCode)"
