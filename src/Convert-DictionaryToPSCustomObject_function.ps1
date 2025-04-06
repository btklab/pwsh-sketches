<#
.SYNOPSIS
    Convert-DictionaryToPSCustomObject (Alias: dict2psobject)

    Convert a dictionary (hashtable) into a PSCustomObject
    This does not support scriptblock or nested structures within the dictionary.
  
.LINK
    hash2psobject, dict2psobject

.NOTES
    reference:
        PowerShell Scripting Weblog updated at 2011-05-16
        https://winscript.jp/powershell/227


.EXAMPLE
    # pipeline input
    [ordered] @{ Name = "John Doe"; Age = 30; City = "New York" },
    [ordered] @{ Name = "Jane Smith"; Age = 25; City = "London" } |
    Convert-DictionaryToPSCustomObject

    Name       Age City
    ----       --- ----
    John Doe    30 New York
    Jane Smith  25 London

.EXAMPLE
    # direct input
    $myDictionary = [ordered] @{ Name = "Alice"; Age = 28; City = "Tokyo" }
    Convert-DictionaryToPSCustomObject -Dictionary $myDictionary

    Name  Age City
    ----  --- ----
    Alice  28 Tokyo
#>
function Convert-DictionaryToPSCustomObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object[]] $Dictionary
        ,
        [Parameter(Mandatory=$false)]
        [Alias('r')]
        [switch] $Recurse
    )
    process {
        # check input hash type
        try {
            [System.Collections.Specialized.OrderedDictionary[]]$Hash = $Dictionary
        } catch {
            try {
                [System.Collections.Hashtable[]]$Hash = $Dictionary
            } catch {
                Write-Error $Error -ErrorAction Stop
            }
        }
        foreach ( $eHash in $Hash) {
            $oHash = [ordered] @{}
            foreach ($key in $eHash.Keys) {
                if ($eHash[$key] -as [System.Collections.Specialized.OrderedDictionary[]] -and $Recurse){
                    $oHash[$key] = $(Convert-DictionaryToPSCustomObject $eHash[$key] -Recurse)
                } elseif ($Hash[$key] -as [System.Collections.Hashtable[]] -and $Recurse){
                    $oHash[$key] = $(Convert-DictionaryToPSCustomObject $eHash[$key] -Recurse)
                } else {
                    $oHash[$key] = ($eHash[$Key])
                }
            }
        }
        [PSCustomObject]$oHash
    }
}
# set alias
[String] $tmpAliasName = "dict2psobject"
[String] $tmpCmdName   = "Convert-DictionaryToPSCustomObject"
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
