<#
.SYNOPSIS
    Map-Object -- Cross-tabulation of strings.

    The key column must not contain a comma and a space (", ").

    Usage:
        Map-Object
            [-r|-RowProperty] <String[]>
            [-c|-ColumnProperty] <String>
            [-v|-ValueProperty] <String >
            [-EmptyValue <String>]
            [-ReplaceComma]

.LINK
    Convert-DictionaryToPSCustomObject (dict2psobject),
    Edit-Property (editprop), Replace-ForEach,
    fillrety, addt, addl, addr

.EXAMPLE
    $data = @(
        [ordered]@{ Category="A"; Product="X"; Count="C.1" },
        [ordered]@{ Category="A"; Product="Y"; Count="C.5" },
        [ordered]@{ Category="A"; Product="X"; Count="C.1" }
        [ordered]@{ Category="B"; Product="Z"; Count="C.8" }
        [ordered]@{ Category="A"; Product="X"; Count="C.7" }
    ) | dict2psobject

    Category Product Count
    -------- ------- -----
    A        X       C.1
    A        Y       C.5
    A        X       C.1
    B        Z       C.8
    A        X       C.7

    # Map the data to a cross-tabulation format
    $data `
        | Map-Object -r Category -c Count -v Product `
        | ft

    Category C.1  C.5 C.7 C.8
    -------- ---  --- --- ---
    A        X, X Y   X
    B                     Z

    # Unmap the data to a cross-tabulation format
    $data `
        | Map-Object -r Category -c Count -v Product `
        | UnMap-Object -r Category -VariableColumnPrefix 'C.' -VariableColumnName "Count" `
        | ft

    Category Count Value
    -------- ----- -----
    A        C.1   X, X
    A        C.5   Y
    A        C.7   X
    A        C.8
    B        C.1
    B        C.5
    B        C.7
    B        C.8   Z


#>
function Map-Object {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('r')]
        [string[]] $RowProperty
        ,
        [Parameter(Mandatory=$true, Position=1)]
        [Alias('c')]
        [string] $ColumnProperty
        ,
        [Parameter(Mandatory=$true, Position=2)]
        [Alias('v')]
        [string] $ValueProperty
        ,
        [Parameter(Mandatory=$false)]
        [string] $EmptyValue = $Null
        ,
        [Parameter(Mandatory=$false)]
        [switch] $ReplaceComma
        ,
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObject
    )
    # set variable
    [string] $SplitDelimiter = ", "
    [string] $ProxyDelimiter = '@p@r@o@x@y@'
    # Combine multiple RowProperty values to create row keys
    if ( $ReplaceComma) {
        foreach ( $p in $RowProperty ) {
            $input = $input `
                | Edit-Property `
                    -Property "$p" `
                    -Expression { $([string]($_."$p")).Replace($SplitDelimiter,$ProxyDelimiter) }
        }
    }
    $RowValues = @(
        $input `
            | Group-Object $RowProperty `
            | Select-Object -ExpandProperty Name `
            | Sort-Object
            )

    # Extract unique values for columns
    $ColumnValues = $input `
        | Select-Object -ExpandProperty $ColumnProperty -Unique `
        | Sort-Object

    # Hashtable to store the cross-tabulation results
    $CrossTab = @{}

    # Create hashtables for each row key
    foreach ($RowValue in $RowValues) {
        Write-Debug "RowValue: $RowValue"
        $CrossTab[$RowValue] = @{}
    }
    #$CrossTab["$($RowValues -join $SplitDelimiter)"] = @{}
    #Write-Debug "RowValue: $($RowValues -join $SplitDelimiter)"

    # Aggregate data and store it in the cross-tabulation table
    foreach ($Item in $input) {
        # Combine values of multiple RowProperty to create the row key
        [string] $RowKey = @($RowProperty | ForEach-Object {$Item.$_}) -join $SplitDelimiter
        [string] $RowKey = $RowKey
        $Column = $Item.$ColumnProperty
        $Value = $Item.$ValueProperty
        Write-Debug $RowKey
        Write-Debug $($CrossTab[$RowKey])
        if (-not $CrossTab[$RowKey].ContainsKey($Column)) {
            $CrossTab[$RowKey][$Column] = @()
        }
        $CrossTab[$RowKey][$Column] += $Value
    }

    # Display the results
    $o = [ordered] @{}
    [int] $i = 0
    foreach ($RowValue in $CrossTab.Keys | Sort-Object) {
        #$o[($RowProperty -join ", ")] = $RowValue
        foreach ($elm in @($RowProperty -split $SplitDelimiter )) {
            $o[$elm] = [string](@($RowValues -split $SplitDelimiter)[$i])
            if ( $ReplaceComma) {
                $o[$elm] = [string]($o[$elm]).Replace($SplitDelimiter,$ProxyDelimiter)
            }
            $o[$elm] = [string]($o[$elm]).Replace($ProxyDelimiter,$SplitDelimiter)
            $i++
        }
        foreach ($ColumnValue in $ColumnValues) {
            [string[]] $Values = $CrossTab[$RowValue][$ColumnValue]
            [string] $Result = $Values -Join $SplitDelimiter
            if ( $Result.Count -eq 0 ) {
                [string] $Result = $EmptyValue
            }
            $o[$ColumnValue] = $Result
        }
        [pscustomobject]$o
        $o = [ordered] @{}
    }
}
