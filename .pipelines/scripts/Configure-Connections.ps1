<#
    .SYNOPSIS
        Update connections json file with variables

    .PARAMETER armOutputFilePath
        The path to the output file generated from an ARM deployment of the API connectors.

    .PARAMETER connectionsFilePath
        The path to the connections.json file. Defaults to the file in the local directory.

    .PARAMETER outputLocation
    The path to store the updated connections json file. Defaults to connections.json in the local directory.

    .EXAMPLE
        Updates connections json file with given parameters.

        ./Configure-Connections.ps1 -armOutputFilePath connectorsOutput.json -connectionsFilePath connections.devops.json -outputLocation connections.json
#>

param(
    [Parameter(Mandatory = $True)]
    [string]
    $armOutputFilePath = "outputs.json",

    [Parameter(Mandatory = $False)]
    [string]
    $connectionsFilePath = "connections.devops.json",

    [Parameter(Mandatory = $False)]
    [string]
    $outputLocation = "connections.json"
)

Function Set-ConnectionVariables {
    <#
        .SYNOPSIS
            Output a connections.json file with variables populated.
    #>

    Write-Host "Loading in ARM deployment connector output file"
    $connectorsOutput = Get-Content $armOutputFilePath | ConvertFrom-Json
    $parameters = @{};
    foreach ($property in $connectorsOutput.PSObject.Properties) {
        $parameters[$property.Name] = $property.Value
    }

    Write-Host "Updating token values in connections file with output values"
    Set-DynamicParameters -sourceFilePath $connectionsFilePath -sourceParameters $parameters | Out-File $outputLocation
}

Function Set-DynamicParameters {
    <#
        .SYNOPSIS
            Read the JSON file from the specified file path, replace tokens, and return the result.
        .OUTPUTS
            JSON of the source file with parameters populated.
    #>
    Param(
        [Parameter(Mandatory = $True, HelpMessage = "The path for the file to read and where to replace tokens")]
        [string]$sourceFilePath,
        [Parameter(Mandatory = $True, HelpMessage = "The hash table with the parameters to iterate through and use for replacing tokens")]
        [hashtable]$sourceParameters
    )
    $result = (Get-Content $sourceFilePath -Encoding UTF8 -Raw)
    $result = Set-TokenValue -InputObject $result -parameters $sourceParameters
    return $result
}

Function Set-TokenValue {
    <#
        .SYNOPSIS
            Replace the token values in the string that is passed as input with the parameter values that are also passed as input.
        .DESCRIPTION
            Iterate through each parameter that's passed as input and replace
            all instances for the "parameter.key" value with the "parameter.value"
            value found in the string that's passed as input.
        .OUTPUTS
            The result from the updates
    #>
    Param(
        [Parameter(Mandatory = $True, HelpMessage = "The value to search for the tokens to replace")]
        [string] $InputObject,
        [Parameter(Mandatory = $True, HelpMessage = "The hash table with the parameters to iterate through and use for replacing tokens")]
        [hashtable] $parameters
    )

    foreach ($key in $parameters.Keys) {
        $InputObject = $InputObject -replace "{$($key)}", $parameters[$key].Value;
    }
    return $InputObject;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

# Fix the PSScriptRoot value for older versions of PowerShell
if (!$PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }

Set-ConnectionVariables
