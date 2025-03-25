<#
.SYNOPSIS
    Split-HereString - Split a herestring into an array for line-by-line processing.

    Split an herestring into a string-array, enabling line-by-line processing.

    While PowerShell's herestring is convenient for handling multi-line strings,
    it can be difficult to process them line by line.

    This function supports both input from the pipeline and input from arguments.

    For example, you can retrieve data using Invoke-WebRequest,
    expand it into RawContent, and then process each line individually.

.EXAMPLE
    # set herestring
    $a = @"
    111
    222
    333
    "@

    # count herestring rows
    $a | Measure-Object
    Count : 1

    # convert herestring to an array
    $a | Split-HereString
    Split-HereString $a

    # count rows
    $a | Split-HereString | Measure-Object
    Count : 3

.EXAMPLE
    # Herestring cannot be searched line-by-line.

    # set herestring
    $a = @"
    111
    222
    333
    "@

    # Searching herestring results in matching the entire content.
    $a | Select-String 222

        111
        222
        333
    
    # By splitting herestring into an array,
    # you can match each line individually.
    $a | Split-HereString | Select-String 222

        222

.EXAMPLE
    # Split the RawContent obtained from Invoke-WebRequest into individual lines.  
    
    # Get RawContent
    Invoke-WebRequest -Uri https://example.com/ `
        | Select-Object -ExpandProperty RawContent `
        | Measure-Object

    Count             : 1

    # Split RawContent
    Invoke-WebRequest -Uri https://example.com/ `
        | Select-Object -ExpandProperty RawContent `
        | Split-HereString `
        | Measure-Object

    Count             : 60

.NOTES
    about_Split - Microsoft Learn
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_split

#>
function Split-HereString {
    [CmdletBinding()]
    param (
        [parameter( Mandatory=$False, ValueFromPipeline=$True )]
        [string[]] $InputObject
    )
    # set variables
    [string[]] $outputArray = @()
    if ($input.Count -gt 0){
        # case: stdin
        $outputArray = ($input.Replace("`r","")).Split("`n")
    } else {
        # case option
        foreach ( $line in $InputObject ){
            $outputArray += ($line.Replace("`r","")).Split("`n")
        }
    }
    return $outputArray
}
## set alias
#[String] $tmpAliasName = "splith"
#[String] $tmpCmdName   = "Split-HereString"
#[String] $tmpCmdPath = Join-Path `
#    -Path $PSScriptRoot `
#    -ChildPath $($MyInvocation.MyCommand.Name) `
#    | Resolve-Path -Relative
#if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
## is alias already exists?
#if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
#    try {
#        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
#            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
#                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
#                    | ForEach-Object{
#                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
#                    }
#            } else {
#                throw
#            }
#        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
#            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
#                | ForEach-Object{
#                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
#                }
#        } else {
#            throw
#        }
#    } catch {
#        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
#    } finally {
#        Remove-Variable -Name "tmpAliasName" -Force
#        Remove-Variable -Name "tmpCmdName" -Force
#    }
#} else {
#    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
#        | ForEach-Object {
#            Write-Host "$($_.DisplayName)" -ForegroundColor Green
#        }
#    Remove-Variable -Name "tmpAliasName" -Force
#    Remove-Variable -Name "tmpCmdName" -Force
#}
