[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $NoitaExecutable
)

$InformationPreference = "Continue"

Write-Information "
This script prepares your Noita game environment for a Noita map capture. For an optimised map capture experience the Noita development build (noita_dev.exe) is used. The dev build uses a different savegame and config and the release build (noita.exe). Any changes done by this script should only apply to a game started with noita_dev.exe. Your normal configuration and savegames should remain untouched.

The followign actions will be performed:
  1. Reset dev build game configuration.
  2. Apply default settings to dev build game configuration.
  3. Apply custom settings to dev build game configuration.
  4. Enable noita-mapcap mod.

"
Write-Warning "Use this script at your own risk. Backup important data."

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice = $host.ui.PromptForChoice("Do you want to continue?", $null, $options, 0)
""
switch ($choice) {
    1 { exit }
}

#region Find noita_dev.exe
Write-Verbose "Looking for Noita game directory and executable."

if ($NoitaExecutable) {
    $noitaExe = Get-Item $NoitaExecutable -ErrorAction Stop
    if ($noitaExe.Name -ne "noita_dev.exe") {
        Write-Error "Executable is not noita_dev.exe!" -ErrorAction Stop
    }
} else {
    if (Test-Path (Join-Path $PSScriptRoot ..\..\noita_dev.exe)) {
        $noitaExe = Get-Item (Join-Path $PSScriptRoot ..\..\noita_dev.exe) -ErrorAction Stop
    } else {
        Write-Error "noita_dev.exe not found!" -ErrorAction Stop
    }
}
#endregion


#region Reset dev build game configuration
Write-Verbose "Resetting game config for noita_dev.exe."

# The next lines would be easier with Start-Process, but I was not able to hide the stdOut of noita_dev.exe this way.
# $p = Start-Process $noitaExe -ArgumentList "-clean_config" -WorkingDirectory $noitaExe.Directory -PassThru -NoNewWindow
$psi = New-object System.Diagnostics.ProcessStartInfo
$psi.CreateNoWindow = $true
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.FileName = $noitaExe
$psi.WorkingDirectory = $noitaExe.Directory
$psi.Arguments = @("-clean_config")
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()

$job = Start-Job -ArgumentList $p.Id -ScriptBlock {
    $procId = $args[0]
        (1..10) | ForEach-Object {
        Start-Sleep 1
        taskkill /PID $procId # *> $null
    }
    if (Get-Process -Id $procId) {
        Write-Warning "Unable to automatically close noita_dev.exe. Please close the game window manually."
    }
}

$p.WaitForExit()
Stop-Job $job
Remove-Job $job

if (Test-Path "$($NoitaExecutable.Directory)\save_shared\config.xml") {
    Write-Host "Successfully reset config.xml" -ForegroundColor Green
}
#endregion

#region Apply optimised and custom settings
# Get settings
$defaultSettingsPath = (Join-Path $PSScriptRoot "settings.default.jsonc")
$customSettingsPath = (Join-Path $PSScriptRoot "settings.jsonc")
If (Test-Path $defaultSettingsPath) {
    $defaultSettings = Get-Content $defaultSettingsPath | ConvertFrom-Json -AsHashtable
} else {
    Write-Error "Default settings file '$($defaultSettingsPath.Name)' not found!"
}
If (Test-Path $customSettingsPath) {
    $customSettings = Get-Content $customSettingsPath | ConvertFrom-Json -AsHashtable
}

# Merge custom settings into recommended settings, overriding the latter.
$mergedSettings = $defaultSettings.Clone()
if ($customSettings) {
    $customSettings.general_settings.GetEnumerator() | ForEach-Object { $mergedSettings.general_settings[$_.Key] = $_.Value }
    $customSettings.config_xml.GetEnumerator() | ForEach-Object { $mergedSettings.general_settings[$_.Key] = $_.Value }
}

$mergedSettings.config_xml.window_w = $mergedSettings.general_settings.CAPTURE_RESOLUTION_WIDTH
$mergedSettings.config_xml.window_h = $mergedSettings.general_settings.CAPTURE_RESOLUTION_HEIGHT
$mergedSettings.config_xml.internal_size_w = $mergedSettings.general_settings.CAPTURE_RESOLUTION_WIDTH
$mergedSettings.config_xml.internal_size_h = $mergedSettings.general_settings.CAPTURE_RESOLUTION_HEIGHT
$mergedSettings.config_xml.backbuffer_width = $mergedSettings.general_settings.CAPTURE_RESOLUTION_WIDTH
$mergedSettings.config_xml.backbuffer_height = $mergedSettings.general_settings.CAPTURE_RESOLUTION_HEIGHT

# Apply settings to config.xml
$configFile = Get-Item (Join-Path $noitaExe.Directory "save_shared\config.xml")
$config = [Xml](Get-Content $configFile)
$mergedSettings.config_xml.GetEnumerator() | ForEach-Object {
    $config.Config."$($_.Key)" = $_.Value
}
$config.Save($configFile)

# Apply settings to magic_numbers.xml
$modMagicNumbersFile = Get-Item (Join-Path $PSScriptRoot "files\magic_numbers.xml")
$modMagicNumbers = [Xml](Get-Content $modMagicNumbersFile)
$modMagicNumbers.MagicNumbers.VIRTUAL_RESOLUTION_X = $mergedSettings.general_settings.CAPTURE_RESOLUTION_WIDTH
$modMagicNumbers.MagicNumbers.VIRTUAL_RESOLUTION_Y = $mergedSettings.general_settings.CAPTURE_RESOLUTION_HEIGHT
if ($mergedSettings.general_settings.WORLD_SEED) {
    $modMagicNumbers.MagicNumbers.SetAttribute("WORLD_SEED", $mergedSettings.general_settings.WORLD_SEED)
}
$modMagicNumbers.Save($modMagicNumbersFile)

if ($customSettings) {
    Write-Host "Successfully applied CUSTOM settings (settings.jsonc) to dev config." -ForegroundColor Green
} else {
    Write-Host "Successfully applied default settings (settings.default.jsonc) to dev config." -ForegroundColor Green
}

# Enable Mod
$noitaModConfigFile = Get-Item (Join-Path $noitaExe.Directory "save00\mod_config.xml")
$noitaModConfig = [Xml](Get-Content $noitaModConfigFile)
$node = $noitaModConfig.Mods.Mod | Where-Object name -eq "noita-mapcap"
$node.enabled = 1
$noitaModConfig.Save($noitaModConfigFile)
#endregion

Write-Host "Successfully enabled noita-mapcap mod." -ForegroundColor Green

Write-Host "All done! " -ForegroundColor Green -NoNewline