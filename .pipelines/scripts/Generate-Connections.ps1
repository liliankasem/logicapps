<#
    .SYNOPSIS
        Generate a connections json file using API connections already deployed to a resource group.

    .PARAMETER resourceGroup
        The name of the resource group that contains the API connectors.

    .PARAMETER outputLocation
    The path to store the updated connections json file. Defaults to connections.json in the local directory.

    .EXAMPLE
        Generates a connections json file.

        ./Generate-Connections.ps1 -resourceGroup rg-api-connections -outputLocation connections.json
#>

param(
    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroup = "",

    [Parameter(Mandatory = $False)]
    [string]
    $outputLocation = "connections.json"
)

Function Get-ConnectionsFile {
  <#
      .SYNOPSIS
          Gets details about the connections in a given resource group and outputs a json file.
  #>
  Write-Host 'Looking up API Connectors'
  $apiConnections = (Get-ApiConnections) ?? @{}

  $json = @{ "managedApiConnection" = $apiConnections; } | ConvertTo-Json -Depth 10 -Compress
  $json = [Regex]::Replace($json, "\\u[a-zA-Z0-9]{4}", { param($u) [Regex]::Unescape($u) })
  $json | Set-Content -Path $outputLocation
}

Function Get-ApiConnections {
  $resources = Get-AzResource -ResourceGroupName $resourceGroup -ResourceType Microsoft.Web/connections
  return @(
    $resources | ForEach-Object {
      Write-Host 'Found API connector: '$_.Name
      $connectionResource = Get-AzResource -ResourceId $_.id
      return @{
        $_.Name = @{
          "api"                  = @{
            "id" = $connectionResource.Properties.api.id
          };
          "connection"           = @{
            "id" = $_.Id.ToLower();
          };
          "connectionRuntimeUrl" = $connectionResource.Properties.connectionRuntimeUrl;
          "authentication"       = @{
            "type" = "ManagedServiceIdentity"
          }
        }
      }
    }
  )
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

# Fix the PSScriptRoot value for older versions of PowerShell
if (!$PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }

Get-ConnectionsFile
