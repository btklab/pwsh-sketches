<#
.SYNOPSIS
    Sponge-Property (Alias:sponge) - Buffer all input before outputting and Expand a Property.

    This function is useful for chaining pipelines to expand
    nested objects without the backtracking for parentheses.

    Basically, this function buffer standard input.

        $input -> ($input)
    
    Optionally, You can specify a property and expand it.
    (Method execution does not supported.)

        ls | sponge Name

        (equivalent to following:)
        ls | Select-Object -ExpandProperty Name

    This avoids the need to re-enter parentheses as shown below.

        (ls).Name


.EXAMPLE
    # expand property
    ls | sponge Name
    ls | Sponge-Property Name

    # equivalent to following
    (ls).Name
    ls | Select-Object -ExpandProperty Name

    # It is similar to the following output.
    ls | select Name
    ls | Select-Object -Property Name

.EXAMPLE
    # Example of chaining pipelines
    # to expand properties sequentially.
    $json = Get-Date `
        | Select-Object -Property * `
        | ConvertTo-Json `
        | ConvertFrom-Json
    
    # json data
    $json

        DisplayHint : 2
        DateTime    : Sunday, March 23, 2025 12:19:44 PM
        Date        : 2025/03/23 0:00:00
        Day         : 23
        DayOfWeek   : 0
        DayOfYear   : 82
        Hour        : 12
        Kind        : 2
        Millisecond : 666
        Microsecond : 298
        Nanosecond  : 300
        Minute      : 19
        Month       : 3
        Second      : 44
        Ticks       : 638783291846662983
        TimeOfDay   : @{Ticks=443846662983; Days=0; Hours=12; Milliseconds
                      =666; Microseconds=298; Nanoseconds=300; Minutes=19;
                       Seconds=44; TotalDays=0.513711415489583; TotalHours
                      =12.32907397175; TotalMilliseconds=44384666.2983; To
                      talMicroseconds=44384666298.3; TotalNanoseconds=4438
                      4666298300; TotalMinutes=739.744438305; TotalSeconds
                      =44384.6662983}
        Year        : 2025

    # expand property: TimeOfDay
    # (Expand properties in the pipeline without
    # the backtracking for parentheses
    $json | sponge TimeOfDay

        Ticks             : 443846662983
        Days              : 0
        Hours             : 12
        Milliseconds      : 666
        Microseconds      : 298
        Nanoseconds       : 300
        Minutes           : 19
        Seconds           : 44
        TotalDays         : 0.513711415489583
        TotalHours        : 12.32907397175
        TotalMilliseconds : 44384666.2983
        TotalMicroseconds : 44384666298.3
        TotalNanoseconds  : 44384666298300
        TotalMinutes      : 739.744438305
        TotalSeconds      : 44384.6662983
    
    # Further chaining pipelines to expand properties.
    $json | sponge TimeOfDay | sponge Ticks

        443846662983
#>        
function Sponge-Property {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$False, Position=0 )]
        [Alias('p')]
        [string] $Property
        ,
        [parameter( Mandatory=$False, ValueFromPipeline=$True )]
        [object[]] $InputObject
    )
    # create script str
    if ( $Property ){
        ($input).$Property
    } else {
        ($input)
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

