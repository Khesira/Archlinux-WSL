#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$DistroName    = "Archlinux"
$ImageName     = "archlinux"
$ContainerName = "archlinux"

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistDir       = Join-Path $ScriptDir "dist"

$OutputWsl     = Join-Path $DistDir "archlinux.wsl"

$cid = $null

try {
    if (-not (Test-Path $DistDir)) {
        New-Item -ItemType Directory -Path $DistDir | Out-Null
    }

    $existingDistros = wsl.exe --list --quiet 2>$null | ForEach-Object {
        $_.ToString().Replace("`0", "").Trim()
    } | Where-Object { $_ }

    if ($existingDistros -contains $DistroName) {
        Write-Host "WSL distro '$DistroName' already exists."
        $answer = Read-Host "Delete and recreate it? [y/N]"

        if ($answer -match '^(y|yes)$') {
            Write-Host "Unregistering existing distro..."
            wsl.exe --unregister $DistroName
        }
        else {
            Write-Host "Aborting."
            exit 1
        }
    }

    Write-Host "Building Docker image..."
    docker build `
        --no-cache `
        --build-arg DISTRO_NAME=$DistroName `
        -t $ImageName `
        $ScriptDir

    $existingContainer = docker ps -a --filter "name=^${ContainerName}$" --format "{{.ID}}"
    if ($existingContainer) {
        Write-Host "Removing old container '$ContainerName'..."
        docker rm -f $existingContainer | Out-Null
    }

    if (Test-Path $OutputWsl) {
        Remove-Item $OutputWsl -Force
    }

    Write-Host "Creating temporary container..."
    $cid = docker create --name $ContainerName $ImageName
    if (-not $cid) {
        throw "docker create did not return a container ID."
    }

    $cid = $cid.Trim()

    Write-Host "Exporting container filesystem to $OutputWsl ..."
    docker export $cid -o $OutputWsl

    Write-Host "Installing WSL distribution from $OutputWsl ..."
    wsl.exe --install --from-file $OutputWsl --name $DistroName
}
finally {
    if ($cid) {
        docker rm -f $cid *> $null
    }
}