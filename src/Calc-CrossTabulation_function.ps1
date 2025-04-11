<#
.SYNOPSIS
    Calc-CrossTabulation -- Cross-tabulate Data.

    Expand a long-format dataset into wide-format.
    The key column must not contain a comma and a space (", ").
    There is no need to pre-sort or deduplicate the key column.

    Usage:
        Calc-CrossTabulation
            [-r|-RowProperty] <String[]>
            [-c|-ColumnProperty] <String>
            [-v|-ValueProperty] <String>
            [-Sum]
            [-Average]
            [-Count]
            [-Max]
            [-Min]
            [-StandardDeviation]
            [-EmptyValue <Double>]
            [-ReplaceComma]
            [-Cast <"int"|"double"|"decimal">]

.LINK
    Convert-DictionaryToPSCustomObject (dict2psobject),
    Edit-Property (editprop), Get-Dataset (dataset)

.EXAMPLE
    $data = @(
        [ordered] @{ Category="A"; Product="X"; Count=10 },
        [ordered] @{ Category="A"; Product="Y"; Count=5  },
        [ordered] @{ Category="B"; Product="X"; Count=15 },
        [ordered] @{ Category="B"; Product="Z"; Count=8  },
        [ordered] @{ Category="A"; Product="X"; Count=7  }
    ) | dict2psobject

    Category Product Count
    -------- ------- -----
    A        X          10
    A        Y           5
    B        X          15
    B        Z           8
    A        X           7

    $data | Calc-CrossTabulation -r Category -c Product -v Count

    Category     X    Y    Z
    --------     -    -    -
    A        17.00 5.00 0.00
    B        15.00 0.00 8.00

#>
function Calc-CrossTabulation {
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
        [switch] $Sum
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Average
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Count
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Max
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Min
        ,
        [Parameter(Mandatory=$false)]
        [switch] $StandardDeviation
        ,
        [Parameter(Mandatory=$false)]
        [double] $EmptyValue = 0
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("int", "double", "decimal")]
        [string] $Cast
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
            $input = $input | Edit-Property -Property "$p" -Expression { $([string]($_."$p")).Replace($SplitDelimiter,$ProxyDelimiter)}
        }
    }
    $RowValues = @($input | Group-Object $RowProperty | Select-Object -ExpandProperty Name | Sort-Object)

    # Extract unique values for columns
    $ColumnValues = $input | Select-Object -ExpandProperty $ColumnProperty -Unique | Sort-Object

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
            $Values = $CrossTab[$RowValue][$ColumnValue]
            [string] $AggregateFunction = 'Sum'
            if ( $Sum ){
                $AggregateFunction = "Sum"
            } elseif ($Average) {
                $AggregateFunction = "Average"
            } elseif ($Count) {
                $AggregateFunction = "Count"
            } elseif ($Max) {
                $AggregateFunction = "Max"
            } elseif ($Min) {
                $AggregateFunction = "Min"
            } elseif ($StandardDeviation) {
                $AggregateFunction = "Std"
            }
            $Result = switch -Exact ($AggregateFunction) {
                "Sum"     {$Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum}
                "Average" {$Values | Measure-Object -Average | Select-Object -ExpandProperty Average}
                "Count"   {$Values.Count}
                "Max"     {$Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum}
                "Min"     {$Values | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum}
                "Std"     {$Values | Measure-Object -Minimum | Select-Object -ExpandProperty StandardDeviation}
                default   {$Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum} # Default to Sum
            }
            if ( $Result -eq $null ) { $Result = $EmptyValue }
            if ( $Cast ){
                $Result = switch -Exact ( $Cast ) {
                    "int"     {[int]$Result}
                    "double"  {[double]$Result}
                    "decimal" {[decimal]$Result}
                    default   {$Result} # Default to no cast
                }
            }
            $o[$ColumnValue] = $Result
        }
        [pscustomobject]$o
        $o = [ordered] @{}
    }
}
