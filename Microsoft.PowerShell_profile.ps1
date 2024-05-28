Write-Host ""
Write-Host "Welcome John ⚡" -ForegroundColor DarkCyan
Write-Host ""

#All Colors: Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, DarkRed, DarkYellow, Gray, Green, Magenta, Red, White, Yellow.

# Check Internet and exit if it takes longer than 1 second
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
$configPath = "$HOME\pwsh_custom_config.yml"

function Initialize-DevEnv {
    if (-not $global:canConnectToGitHub) {
        Write-Host "❌ Skipping Dev Environment Initialization due to GitHub.com not responding within 1 second." -ForegroundColor Red
        return
    }
    $modules = @(
        @{ Name = "Terminal-Icons"; ConfigKey = "Terminal-Icons_installed" },
        @{ Name = "Powershell-Yaml"; ConfigKey = "Powershell-Yaml_installed" },
        @{ Name = "PoshFunctions"; ConfigKey = "PoshFunctions_installed" }
    )
    foreach ($module in $modules) {
        $isInstalled = Get-ConfigValue -Key $module.ConfigKey
        if ($isInstalled -ne "True") {
            Write-Host "Initializing $($module.Name) module..."
            Initialize-Module $module.Name
        } else {
            Import-Module $module.Name
            Write-Host "✅ $($module.Name) module is already installed." -ForegroundColor Green
        }
    }
    if ($vscode_installed_value -ne "True") { Invoke-Helper ; Test-vscode }
    if ($ohmyposh_installed_value -ne "True") { Invoke-Helper ; Test-ohmyposh }
    if ($FiraCode_installed_value -ne "True") { Invoke-Helper ; Test-firacode }
    
    Write-Host "✅ Successfully initialized Pwsh with all Modules and applications" -ForegroundColor Green
}

function Invoke-Helper {
    Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/username/repo/branch/path/to/script.ps1" -UseBasicParsing).Content
}


# Function to create config file
function Install-Config {
    if (-not (Test-Path -Path $configPath)) {
        New-Item -ItemType File -Path $configPath | Out-Null
        Write-Host "Configuration file created at $configPath ❗" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Successfully loaded Config file" -ForegroundColor Green
    }
    Initialize-Keys
    Initialize-DevEnv
}

# Function to set a value in the config file
function Set-ConfigValue {
    param (
        [string]$Key,
        [string]$Value
    )
    $config = @{}

    # Try to load the existing config file content
    if (Test-Path -Path $configPath) {
        $content = Get-Content $configPath -Raw
        if (-not [string]::IsNullOrEmpty($content)) {
            $config = $content | ConvertFrom-Yaml
        }
    }

    # Ensure $config is a hashtable
    if (-not $config) {
        $config = @{}
    }

    $config[$Key] = $Value
    $config | ConvertTo-Yaml | Set-Content $configPath
    # Write-Host "Set '$Key' to '$Value' in configuration file." -ForegroundColor Green
    Initialize-Keys
}

# Function to get a value from the config file
function Get-ConfigValue {
    param (
        [string]$Key
    )
    $config = @{}
    # Try to load the existing config file content
    if (Test-Path -Path $configPath) {
        $content = Get-Content $configPath -Raw
        if (-not [string]::IsNullOrEmpty($content)) {
            $config = $content | ConvertFrom-Yaml
        }
    }
    # Ensure $config is a hashtable
    if (-not $config) {
        $config = @{}
    }
    return $config[$Key]
}

function Initialize-Module {
    param (
        [string]$moduleName
    )
    if ($global:canConnectToGitHub) {
        try {
            Install-Module -Name $moduleName -Scope CurrentUser -SkipPublisherCheck
            Set-ConfigValue -Key "${moduleName}_installed" -Value "True"
        } catch {
            Write-Error "❌ Failed to install module ${moduleName}: $_"
        }
    } else {
        Write-Host "❌ Skipping Module Initialization check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
    }
}

function Initialize-Keys {
    $keys = "Terminal-Icons_installed", "Powershell-Yaml_installed", "PoshFunctions_installed", "FiraCode_installed", "vscode_installed", "ohmyposh_installed"
    foreach ($key in $keys) {
        $value = Get-ConfigValue -Key $key
        Set-Variable -Name $key -Value $value -Scope Global
    }
}

# ------
# Custom function and alias section

function gitpush {
    git pull
    git add .
    git commit -m "$args"
    git push
}

function ssh-copy-key {
    param(
        [parameter(Position=0)]
        [string]$user,

        [parameter(Position=1)]
        [string]$ip
    )
    $pubKeyPath = "~\.ssh\id_ed25519.pub"
    $sshCommand = "cat $pubKeyPath | ssh $user@$ip 'cat >> ~/.ssh/authorized_keys'"
    Invoke-Expression $sshCommand
}

function grep {
    param (
        [string]$regex,
        [string]$dir
    )
    process {
        if ($dir) {
            Get-ChildItem -Path $dir -Recurse -File | Select-String -Pattern $regex
        } else {     # Use if piped input is provided
            $input | Select-String -Pattern $regex
        }
    }
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10)
    Get-Content $Path -Tail $n
}

#Use this function to process input and then pipe to Send-Wastebin, this allows input via pipeline or file.
function Initialize-Wastebin {
    param (
        [Parameter(Position=0)]
        [string]$FilePath,
        [Parameter(ValueFromPipeline=$true)]
        [string]$InputContent
    )
    begin {
        $contentList = @()
    }
    process {
        if ($FilePath) {
            if (-not (Test-Path $FilePath)) {
                Write-Host "File '$FilePath' not found."
                return
            }
            $contentList += Get-Content -Path $FilePath -Raw
        } elseif ($InputContent) {
            $contentList += $InputContent
        } else {
            Write-Host "No input provided."
            return
        }
    }
    end {
        return $contentList -join "`n"
    }
}

function Send-Wastebin {
    param (
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [string]$Content,
        [Parameter(Position=1)]
        [int]$ExpirationTime = 3600,
        [Parameter(Position=2)]
        [bool]$BurnAfterReading = $false
    )
    process {
        $WastebinServerUrl=[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("aHR0cHM6Ly9iaW4uY3Jhenl3b2xmLmRldg=="))
        try {
            $Payload = @{
                text = $Content
                extension = $null
                expires = $ExpirationTime
                burn_after_reading = $BurnAfterReading
            } | ConvertTo-Json
            $Response = Invoke-RestMethod -Uri $WastebinServerUrl -Method Post -Body $Payload -ContentType 'application/json'
            $Path = $Response.path -replace '\.\w+$'
            Write-Host ""
            Write-Host "$WastebinServerUrl$Path"
        }
        catch {
            Write-Host "Error occurred: $_"
        }
    }
}
Set-Alias -Name ptw -Value Initialize-Wastebin | Send-Wastebin

# Does the the rough equivalent of dir /s /b. For example, dirs *.png is dir /s /b *.png
function dirs {
    if ($args.Count -gt 0) {
        Get-ChildItem -Recurse -Include "$args" | Foreach-Object FullName
    } else {
        Get-ChildItem -Recurse | Foreach-Object FullName
    }
}

# Function to run a command or shell as admin.
function admin {
    if ($args.Count -gt 0) {   
        $argList = "& '" + $args + "'"
        Start-Process "wt.exe" -Verb runAs -ArgumentList $argList
    } else {
        Start-Process "wt.exe" -Verb runAs
    }
}
Set-Alias -Name sudo -Value admin

Function Test-CommandExists {
    Param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try { if (Get-Command $command) { RETURN $true } }
    Catch { Write-Host "$command does not exist"; RETURN $false }
    Finally { $ErrorActionPreference = $oldPreference }
} 

function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

function unzip ($file) {
    $fullPath = Join-Path -Path $pwd -ChildPath $file
    if (Test-Path $fullPath) {
        Write-Output "Extracting $file to $pwd"
        Expand-Archive -Path $fullPath -DestinationPath $pwd
    } else {
        Write-Output "File $file does not exist in the current directory"
    }
}

# Short ulities
function ll { Get-ChildItem -Path $pwd -File }
function df {get-volume}
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }
function md5 { Get-FileHash -Algorithm MD5 $args }
function sha1 { Get-FileHash -Algorithm SHA1 $args }
function sha256 { Get-FileHash -Algorithm SHA256 $args }
function expl { explorer . }

# Quick shortcuts
Set-Alias n notepad
Set-Alias vs code

# Aliases for reboot and poweroff
function Reboot-System {
    Restart-Computer -Force
    Set-Alias reboot Reboot-System
}
function Poweroff-System {
    Stop-Computer -Force
    Set-Alias poweroff Poweroff-System
}

# Useful file-management functions
function cd... { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

# Folder shortcuts
#function cdgit {Set-Location "G:\Informatik\Projekte"}
#function cdtbz {Set-Location "$env:OneDriveCommercial\Dokumente\Daten\TBZ"}
#function cdbmz {Set-Location "$env:OneDriveCommercial\Dokumente\Daten\BMZ"}
#function cdhalter {Set-Location "$env:OneDriveCommercial\Dokumente\Daten\Halter"}

#function ssh-m122 {
#    param ([string]$ip)
#    ssh -i ~\.ssh\06-student.pem -o ServerAliveInterval=30 "ubuntu@$ip"
#}

# -------------
# Run section

Install-Config
# Update PowerShell in the background
Start-Job -ScriptBlock {Invoke-Helper ; Update-PowerShell } > $null 2>&1
Import-Module -Name Microsoft.WinGet.CommandNotFound > $null 2>&1
if (-not $?) { Write-Host "💭 Make sure to install WingetCommandNotFound by MS Powertoys" -ForegroundColor Yellow }
if (-not (Test-Path -Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE | Out-Null
    Add-Content -Path $PROFILE -Value 'iex (iwr "https://raw.githubusercontent.com/Reactor46/home-configs/main/Microsoft.PowerShell_profile.ps1").Content'
    Write-Host "PowerShell profile created at $PROFILE." -ForegroundColor Yellow
}
oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/Reactor46/home-configs/main/montys.omp.json' | Invoke-Expression
