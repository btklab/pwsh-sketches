<#
.SYNOPSIS
    Get-Dataset -- Retrieves the 'iris' dataset from R using Rscript

    This script uses Rscript to execute an R command that loads the 'iris' dataset.

    Prerequisites: R must be installed on the system.
        install: winget install --id RProject.R --source winget -e
        and add to the PATH environment variable


.EXAMPLE
    # Show top 5 dataset names
    dataset | select -First 5
    
    Name          Type       Title
    ----          ----       -----
    AirPassengers ts         Monthly Airline Passenger Numbers 1949-1960
    BJsales       ts         Sales Data with Leading Indicator
    BJsales.lead  ts         Sales Data with Leading Indicator
    BOD           data.frame Biochemical Oxygen Demand
    CO2           data.frame Carbon Dioxide Uptake in Grass Plants

.EXAMPLE
    # Get the iris dataset
    dataset iris | select -First 5 | ft
    
    Sepal.Length Sepal.Width Petal.Length Petal.Width Species
    ------------ ----------- ------------ ----------- -------
    5.1          3.5         1.4          0.2         setosa
    4.9          3           1.4          0.2         setosa
    4.7          3.2         1.3          0.2         setosa
    4.6          3.1         1.5          0.2         setosa
    5            3.6         1.4          0.2         setosa

#>
function Get-Dataset {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "Name of the dataset")]
        [Alias('n')]
        [string] $Name
        ,
        [Parameter(Mandatory = $false, HelpMessage = "Path to Rscript.exe")]
        [Alias('Path')]
        [string] $RPath
        ,
        [Parameter(Mandatory = $false, HelpMessage = "Output the data as is")]
        [switch] $AsIs
        ,
        [Parameter(Mandatory = $false, HelpMessage = "Cast all columns to double")]
        [Alias('double')]
        [switch] $CastDouble
        ,
        [Parameter(Mandatory = $false, HelpMessage = "Show datasets")]
        [Alias('show')]
        [switch] $ShowDatasets
    )
    # Attempt to find Rscript.exe if not provided
    if (-not $RPath) {
        $RPath = Get-Command "Rscript" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
        if (-not $RPath) {
            Write-Error "Rscript.exe not found. Please specify the path using the -RPath parameter."
            return
        }
    }
    # Show Datasets
    if ( -not $Name -or $ShowDatasets ){
        [string] $rScriptPath = $PSScriptRoot.Replace('\','/') + "/" + "Get-Dataset_function.R"
        & $RPath $rScriptPath | ConvertFrom-Csv
        return
    }
    # R script to output iris dataset as CSV
    [string] $rScript = "write.csv($Name, stdout(), row.names = FALSE)"
    try {
        # Execute Rscript.exe and capture the output
        if ( $AsIs ){
            & $RPath -e $rScript
        } elseif ($CastDouble) {
            & $RPath -e $rScript `
                | ConvertFrom-Csv `
                | Cast-Double
        } else {
            & $RPath -e $rScript `
                | ConvertFrom-Csv
        }
        return
    }
    catch {
        Write-Error "Error executing Rscript: $($_.Exception.Message)"
    }
}
# set alias
[String] $tmpAliasName = "dataset"
[String] $tmpCmdName   = "Get-Dataset"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
# is alias already exists?
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
                    }
            } else {
                throw
            }
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
                }
        } else {
            throw
        }
    } catch {
        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green
        }
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
