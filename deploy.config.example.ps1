# Copy this file to deploy.config.ps1 to override the default deployment path.
$DeployConfig = @{
    QgisPluginsPath = (Join-Path $env:APPDATA 'QGIS\QGIS3\profiles\default\python\plugins')
    PluginDirectoryName = 'qgis-itv-plugin'
}