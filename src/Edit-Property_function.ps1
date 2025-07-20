<#
.SYNOPSIS
    Edit-Property (Alias: Add-Property) - Edits the values in a specified column.

    Edits or adds values in a specific column while preserving other columns.

.EXAMPLE
    # EXAMPLE 1: Edit the date format
    @"
    date version
    2020-02-26 v2.2.4
    2020-02-26 v3.0.3
    2019-11-10 v3.0.2
    "@ -split '\r?\n' `
        | ConvertFrom-Csv -Delimiter " " `
        | Edit-Property -Property date -Expression {(Get-Date $_.date).ToString('yyyy/MM/dd (ddd)') }

    # Output:
    # date             version
    # ----             -------
    # 2020/02/26 (Wed) v2.2.4
    # 2020/02/26 (Wed) v3.0.3
    # 2019/11/10 (Sun) v3.0.2

.EXAMPLE
    # EXAMPLE 2: Create a new property from an existing property
    @"
    date version
    2020-02-26 v2.2.4
    2020-02-26 v3.0.3
    "@ -split '\r?\n' `
        | ConvertFrom-Csv -Delimiter " " `
        | Edit-Property -Property date2 -Expression {(Get-Date $_.date).ToString('yy/M/d') }

    # Output:
    # date       version date2
    # ----       ------- -----
    # 2020-02-26 v2.2.4  20/2/26
    # 2020-02-26 v3.0.3  20/2/26

.EXAMPLE
    # EXAMPLE 3: Edit and add multiple properties at the same time
    @"
    date version
    2020-02-26 v2.2.4
    2020-02-26 v3.0.3
    2019-11-10 v3.0.2
    "@ -split '\r?\n'`
        | ConvertFrom-Csv -Delimiter " " `
        | Edit-Property -Property date, status -Expression `
            {($_.date -as [datetime]).DayOfWeek},
            {if ($_.version -match '^v3') {'Latest'} else {'Old'}}

    # Output:
    # date      version status
    # ----      ------- ------
    # Wednesday v2.2.4  Old
    # Wednesday v3.0.3  Latest
    # Sunday    v3.0.2  Latest

#>
function Edit-Property
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('p', 'n')]
        [String[]] $Property,

        [Parameter(Mandatory=$true, Position=1)]
        [Alias('e')]
        [Scriptblock[]] $Expression,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSObject] $InputObject
    )

    Begin {
        # Validate that the number of properties matches the number of expressions.
        if ($Property.Count -ne $Expression.Count) {
            throw "The number of properties must match the number of expressions."
        }

        # Create an ordered hashtable to map properties to expressions.
        $propExprMap = [ordered]@{}
        for ($i = 0; $i -lt $Property.Count; $i++) {
            $propExprMap[$Property[$i]] = $Expression[$i]
        }

        # Initialize the list of calculated properties to pass to Select-Object.
        [bool] $firstObjectProcessed = $false
        [object[]] $selectProperties = @()
        [object[]] $collectedInput = @()
    }

    Process {
        # Build the property list only once when the first object is processed.
        if (-not $firstObjectProcessed) {
            [string[]] $existingProperties = $InputObject.PSObject.Properties.Name
            [string[]] $newProperties = $propExprMap.Keys | Where-Object { $_ -notin $existingProperties }

            # Add existing properties in order.
            foreach ($propName in $existingProperties) {
                if ($propExprMap.Keys -contains $propName) {
                    # Add the property to be modified as a calculated property.
                    [object[]] $selectProperties += @{ Name = $propName; Expression = $propExprMap[$propName] }
                } else {
                    # Add properties that are not modified as they are.
                    [object[]] $selectProperties += $propName
                }
            }

            # Add new properties to the end.
            foreach ($propName in $newProperties) {
                [object[]] $selectProperties += @{ Name = $propName; Expression = $propExprMap[$propName] }
            }
            
            [bool] $firstObjectProcessed = $true
        }
        # Collect all input from the pipeline.
        [object[]] $collectedInput += $InputObject
    }

    End {
        # For all collected input, run Select-Object using the constructed property list.
        if ($collectedInput.Count -gt 0) {
            $collectedInput | Select-Object -Property $selectProperties
        }
    }
}

# set alias
[String] $tmpAliasName = "Add-Property"
[String] $tmpCmdName   = "Edit-Property"
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

