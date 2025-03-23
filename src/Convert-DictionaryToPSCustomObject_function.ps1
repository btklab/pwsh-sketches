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
    @{ Name = "John Doe"; Age = 30; City = "New York" },
    @{ Name = "Jane Smith"; Age = 25; City = "London" } |
    Convert-DictionaryToPSCustomObject

    Output:

    Name       Age City
    ----       --- ----
    John Doe    30 New York
    Jane Smith  25 London

.EXAMPLE
    # direct input
    $myDictionary = @{ Name = "Alice"; Age = 28; City = "Tokyo" }
    Convert-DictionaryToPSCustomObject -Dictionary $myDictionary

    Output:

    Name  Age City
    ----  --- ----
    Alice  28 Tokyo
#>
function Convert-DictionaryToPSCustomObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable] $Dictionary
        ,
        [Parameter(Mandatory=$false)]
        [Alias('r')]
        [switch] $Recurse
    )
    process {
        $Object = [PSCustomObject]::new()
        foreach ($Key in $Dictionary.Keys) {
            if($Dictionary[$key] -as [System.Collections.Hashtable[]] -and $Recurse){
                $Object | Add-Member -MemberType "NoteProperty" -Name $Key -Value $(Convert-DictionaryToPSCustomObject $Dictionary[$key] -Recurse)
            } else {
                $Object | Add-Member -MemberType "NoteProperty" -Name $Key -Value ($Dictionary[$Key])
            }
        }
        Write-Output $Object
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
