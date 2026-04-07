<#
.SYNOPSIS
    Sponge-Property (Alias: sponge, unbox)
    Buffers all pipeline input into memory before processing, then expands the specified property or properties.

    PURPOSE:
    This function eliminates the need for "backtracking" with parentheses when drilling down into nested objects.
    Instead of writing `(Get-Service).Name`, you can write `Get-Service | sponge Name`.

    BEHAVIOR:
    - Buffers ALL input from the pipeline before outputting any results.
    - If no property is specified, it simply outputs the buffered collection.
    - Supports deep-drilling via dot-notation (e.g., "User.ID") or multiple arguments.
    - Limitation: Only property expansion is supported; method execution is not.

.PARAMETER Property
    One or more property names to expand. Supports dot-separated strings (e.g., "Parent.Child") 
    and multiple arguments (e.g., "Parent", "Child").

.PARAMETER InputObject
    The objects passed from the pipeline to be buffered and expanded.

.EXAMPLE
    # Dot-notation expansion
    $json | sponge User.Details.ID

.EXAMPLE
    # Mixed dot-notation and multiple arguments
    $json | sponge User.Details ID
    
    # All are equivalent to:
    # (($json).User.Details).ID

.EXAMPLE
    # Simple expansion
    Get-Process | sponge Name

.NOTES
    The name "sponge" is inspired by the unix 'sponge' utility which "soaks up" 
    standard input before writing to a file, preventing race conditions.
#>
function Sponge-Property {
    [CmdletBinding()]
    [Alias('unbox')]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('p')]
        [string[]] $Property,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [object[]] $InputObject
    )

    process {
        # The automatic variable $input contains all objects from the pipeline.
        # We convert it to an array to "soak up" all data before further processing.
        $bufferedItems = @($input)

        if ($null -eq $Property -or $Property.Count -eq 0) {
            return $bufferedItems
        }

        # Normalize property list: handle both dot-notation and array elements.
        # Example: @("User.Details", "ID") -> @("User", "Details", "ID")
        $propertyChain = $Property | ForEach-Object { $_.Split('.') } | Where-Object { $_ -ne "" }

        # Drill down through the property chain
        $currentValue = $bufferedItems
        foreach ($p in $propertyChain) {
            if ($null -eq $currentValue) { break }
            $currentValue = $currentValue.$p
        }

        $currentValue
    }
}

# set alias
[String] $tmpAliasName = "sponge"
[String] $tmpCmdName   = "Sponge-Property"
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

