<#
.SYNOPSIS
    Unique-Object - Select unique objects from a collection of objects.

    Do not need Pre-Sort.

.LINK
    Select-Object (Microsoft.PowerShell.Utility) - PowerShell
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-object

    Group-Object (Microsoft.PowerShell.Utility) - PowerShell
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/group-object

.EXAMPLE
    # input
    "str","a","b","c","d","d","e","f","a"  `
        | ConvertFrom-Csv

    str
    ---
    a
    b
    c
    d
    d
    e
    f
    a

    # uniq
    "str","a","b","c","d","d","e","f","a" `
        | ConvertFrom-Csv `
        | Unique-Object -Property "str"

    str
    ---
    a
    b
    c
    d
    e
    f

    # uniq -Count option
    "str","a","b","c","d","d","e","f","a" `
        | ConvertFrom-Csv `
        | Unique-Object -Property "str" -Count

    str Count
    --- -----
    a       2
    b       1
    c       1
    d       2
    e       1
    f       1

#>
function Unique-Object
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, Position=0)]
        [Alias('p')]
        [String[]] $Property
        ,
        [Parameter(Mandatory=$False)]
        [Alias('a')]
        [Switch] $AllProperty
        ,
        [Parameter(Mandatory=$False)]
        [Alias('c')]
        [Switch] $Count
        ,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [PSObject] $InputObject
    )
    if ( $Count -and $AllProperty ){
        $splatting = @{
            Property = $Property
            NoElement = $False
        }
        [string[]] $OutputProperty = @()
        [string[]] $OutputProperty += "Count"
        [string[]] $OutputProperty += $Property
        [string[]] $OutputProperty += "Group"
        $input | Group-Object @splatting  | ForEach-Object {
            [string[]] $properties = $_.Values
            $newObject = $_ | Select-Object -Property "Count", "Group"
            for ($i = 0; $i -lt $properties.Count; $i++) {
                [string] $propertyName = $Property[$i]
                $newObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $properties[$i]
            }
            $newObject | Select-Object -Property $OutputProperty
            }
        return
    }
    if ( $AllProperty ){
        $splatting = @{
            Property = $Property
            NoElement = $False
        }
        [string[]] $OutputProperty = @()
        [string[]] $OutputProperty += $Property
        [string[]] $OutputProperty += "Group"
        $input | Group-Object @splatting  | ForEach-Object {
            [string[]] $properties = $_.Values
            $newObject = $_ | Select-Object -Property "Group"
            for ($i = 0; $i -lt $properties.Count; $i++) {
                [string] $propertyName = $Property[$i]
                $newObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $properties[$i]
            }
            $newObject | Select-Object -Property $OutputProperty
            }
        return
    }
    if ( $Count ){
        $splatting = @{
            Property = $Property
            NoElement = $True
        }
        [string[]] $OutputProperty = @()
        [string[]] $OutputProperty += "Count"
        [string[]] $OutputProperty += $Property
        $input | Group-Object @splatting  | ForEach-Object {
            [string[]] $properties = $_.Values
            $newObject = $_ | Select-Object -Property "Count"
            for ($i = 0; $i -lt $properties.Count; $i++) {
                [string] $propertyName = $Property[$i]
                $newObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $properties[$i]
            }
            $newObject | Select-Object -Property $OutputProperty
            }
        return
    }
    # default
    if ( $True ){
        $splatting = @{
            Property = $Property
            Unique = $True
        }
        $input | Select-Object @splatting
        return
    }
}
