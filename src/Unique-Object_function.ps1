<#
.SYNOPSIS
    Unique-Object

    Pre-Sorted property needed.

    $obj `
        | Sort-Object -Property "Property" -Stable `
        | Unique-Object -Property "Property" [-Count]

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
        | Sort-Object -Property "str" -Stable `
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
        | Sort-Object -Property "str" -Stable `
        | Unique-Object -Property "str" -Count

    str Count
    --- -----
    a       2
    b       1
    c       1
    d       2
    e       1
    f       1

    # Oops! forgot to pre-sort property
    "str","a","b","c","d","d","e","f","a" `
        | ConvertFrom-Csv `
        | Unique-Object -Property "str" -Count

    str Count
    --- -----
    a       1
    b       1
    c       1
    d       2
    e       1
    f       1
    a       1 <--- Undesired result

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
        [Alias('c')]
        [Switch] $Count
        ,
        [Parameter(Mandatory=$False)]
        [Alias('a')]
        [Switch] $AllProperty
        ,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [PSObject] $InputObject
    )
    begin {
        # init variables
        [bool] $isFirstItem = $True
        [string] $oldVal = $Null
        [string] $newVal = $Null
        [int] $Counter = 0
    }
    process {
        [string] $propKeyStr = ''
        foreach ($p in $Property){
            $propKeyStr += $InputObject.$p
        }
        [string] $newVal = $propKeyStr
        if ( $isFirstItem ){
            # the first record
        } else {
            # the second and subsequent records
            if ( $newVal -eq $oldVal){
                # pass
            } else {
                if ( $Count ){
                    $preItem | Add-Member -MemberType NoteProperty -Name "Count" -Value $Counter
                }
                $preItem
                # init variables
                [int] $Counter = 0
                [bool] $isFirstItem = $True
            }
        }
        [string] $oldVal = $newVal
        if ( $isFirstItem ){
            if ( $AllProperty ){
                $preItem = $InputObject
            } else {
                $preItem = $InputObject | Select-Object -Property $Property
            }
            $isFirstItem = $False
        }
        $Counter++
    }
    end {
            if ( $Count ){
                $preItem | Add-Member -MemberType NoteProperty -Name "Count" -Value $Counter
            }
            $preItem
    }
}

