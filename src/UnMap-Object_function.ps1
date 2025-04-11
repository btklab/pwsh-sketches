<#
.SYNOPSIS
    UnMap-Object -- Converts wide-format data into long-format data.

    Converts wide-format data into long-format data for easier
    analysis and visualization.
    It supports specifying multiple row identifiers and dynamically
    pivots columns based on prefixes or explicitly defined column
    names.

    Usage:
        UnMap-Object
            [-r|-RowIdentifier] <String[]>
            [-c|-VariableColumns <String[]>]
            [-p|-VariableColumnPrefix <String>]
            [-ValueColumnName <String>]
            [-VariableColumnName <String>]

.LINK
    Convert-DictionaryToPSCustomObject (dict2psobject)

.EXAMPLE
    # Sample data (wide format like a cross-tabulation result)
    $WideDataTable = @(
        [ordered]@{ ID = 1; Product_X = 10; Product_Y = 5; Category_A = 20; Category_B = 15; Category_C = 1 },
        [ordered]@{ ID = 2; Product_X = 7;  Product_Y = 12; Category_A = 25; Category_B = 18 },
        [ordered]@{ ID = 3; Product_X = 18; Product_Y = 3;  Category_A = 30; Category_B = 22 }
    ) | dict2psobject

    # Output
    $WideDataTable | ft

    ID Product_X Product_Y Category_A Category_B Category_C
    -- --------- --------- ---------- ---------- ----------
     1        10         5         20         15          1
     2         7        12         25         18
     3        18         3         30         22

    Write-Host "Convert by detecting columns with a prefix:"

    $WideDataTable `
        | UnMap-Object `
            -RowIdentifier "ID" `
            -VariableColumnPrefix "Product_" `
            -DeletePrefix `
        | Format-Table

    ID Product_ Value
    -- -------- -----
     1 X           10
     1 Y            5
     2 X            7
     2 Y           12
     3 X           18
     3 Y            3

.EXAMPLE
    Write-Host "Convert by directly specifying column names:"

    $WideDataTable `
        | UnMap-Object `
            -RowIdentifier "ID","Product_X","Category_A" `
            -VariableColumns "Category_A", "Category_B", "Category_C" `
            -VariableColumnName "CategoryName" `
        | Format-Table

    ID Product_X Category_A CategoryName Value
    -- --------- ---------- ------------ -----
     1        10         20 Category_A      20
     1        10         20 Category_B      15
     1        10         20 Category_C       1
     2         7         25 Category_A      25
     2         7         25 Category_B      18
     3        18         30 Category_A      30
     3        18         30 Category_B      22

.EXAMPLE
    Write-Host "Convert by combining prefix detection and direct specification:"

    $WideDataTable `
        | UnMap-Object `
            -RowIdentifier "ID" `
            -VariableColumnPrefix "Product_" `
            -VariableColumns "Category_A" `
            -ValueColumnName "Value" `
            -VariableColumnName "ProdAndCat" `
        | Format-Table
    
    ID ProdAndCat Value
    -- ---------- -----
     1 Category_A    20
     1 X             10
     1 Y              5
     2 Category_A    25
     2 X              7
     2 Y             12
     3 Category_A    30
     3 X             18
     3 Y              3

#>
function UnMap-Object {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('r')]
        [string[]]$RowIdentifier
        ,
        [Parameter(Mandatory=$false)]
        [Alias('c')]
        [string[]]$VariableColumns
        ,
        [Parameter(Mandatory=$false)]
        [Alias('p')]
        [string]$VariableColumnPrefix
        ,
        [Parameter(Mandatory=$false)]
        [string]$ValueColumnName = "Value"
        ,
        [Parameter(Mandatory=$false)]
        [string]$VariableColumnName
        ,
        [Parameter(Mandatory=$false)]
        [switch]$DeletePrefix
        ,
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]]$InputObject
    )
    begin {
        # test parameters
        if ( -not $VariableColumnPrefix -and $VariableColumns.Count -eq 0 ) {
            Write-Error "Either -VariableColumnPrefix or -VariableColumns must be specified." -ErrorAction Stop
            return
        }
    }
    process{
        [object] $Row = $_
        # Add columns detected by prefix
        $ColumnsToPivot = @()
        if ($VariableColumnPrefix) {
            $ColumnsToPivot += $Row.PSObject.Properties `
                | Where-Object {$_.Name -like "$VariableColumnPrefix*"} `
                | Select-Object -ExpandProperty Name
        }
        # set value column name
        if ( $VariableColumnName ){
            # pass
        } elseif  ( $VariableColumnPrefix ) {
            $VariableColumnName = $VariableColumnPrefix
        } else {
            # default
            $VariableColumnName = "Variable"
        }
        # Add directly specified columns
        if ($VariableColumns) {
            $ColumnsToPivot += $VariableColumns
        }
        # Create a list of columns to process, removing duplicates
        $UniqueColumnsToPivot = $ColumnsToPivot | Sort-Object -Unique
        foreach ($ColumnName in $UniqueColumnsToPivot) {
            if ($Row.PSObject.Properties.Name -contains $ColumnName) {
                $Variable = if ($VariableColumnPrefix -and $ColumnName -like "$VariableColumnPrefix*") {
                    if ( $DeletePrefix ) {
                        $ColumnName.Substring($VariableColumnPrefix.Length)
                    } else {
                        $ColumnName
                    }
                } elseif ($VariableColumns -contains $ColumnName) {
                    $ColumnName # Use the column name as is if specified directly
                } else {
                    continue # Skip if it doesn't meet either condition
                }
                $Value = $Row.$ColumnName
                $o = [ordered] @{}
                foreach ( $r in $RowIdentifier ) {
                    $o[$r] = $Row.$r
                }
                $o[$VariableColumnName] = $Variable
                $o[$ValueColumnName] = $Value
                [PSCustomObject] $o
            }
        }
    }
}
