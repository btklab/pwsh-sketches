<#
.SYNOPSIS
    tateyoko - Transpose rows and columns

        tateyoko [-d|-Delimiter <String>]
    
    Expects space-separated values as input.
    The number of columns can be irregular.

.DESCRIPTION

    The main design pattern of this command was abstracted from
    Universal Shell Programming Laboratory's "Open-usp-Tukubai",
    Here is the original copyright notice for "Open-usp-Tukubai":
    
        The MIT License Copyright (c) 2011-2023 Universal Shell Programming Laboratory
        https://github.com/usp-engineers-community/Open-usp-Tukubai/blob/master/LICENSE

.EXAMPLE
    "1 2 3","4 5 6","7 8 9"
    1 2 3
    4 5 6
    7 8 9

    PS > "1 2 3","4 5 6","7 8 9" | tateyoko
    1 4 7
    2 5 8
    3 6 9

.EXAMPLE
    "1,2,3", "4,5", "7,8,9"
    1,2,3
    4,5
    7,8,9

    "1,2,3", "4,5", "7,8,9" | tateyoko -d ","
    1,4,7
    2,5,8
    3,,9

.EXAMPLE
    "1,2,3", "4,5", "7,8,9" | tateyoko -d "," -Placeholder "NA"
    1,4,7
    2,5,8
    3,NA,9

#>
function tateyoko{
    [CmdletBinding()]
    Param (
        # Delimiter for splitting input lines into columns. Defaults to space.
        [Parameter(Mandatory=$false)]
        [Alias('d')]
        [Alias('fs')]
        [string] $Delimiter = ' ',

        # Placeholder string to use for missing fields during transposition. Defaults to an empty string.
        [Parameter(Mandatory=$false)]
        [Alias('p')]
        [string] $Placeholder = '',

        [Parameter(Mandatory=$false)]
        [Alias('t')]
        [switch] $Trim,

        # Input text, received line by line from the pipeline.
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [string[]] $Text
    )

    begin {
        # Initialize an empty array for future row processing (though RowList is used for accumulation).
        [string[]] $RowAry = @() 
        # Stores the maximum number of columns found in any input row, used for padding output.
        [int] $MaxColNum = 1
        # List to accumulate all input rows before transposing.
        $RowList = New-Object 'System.Collections.Generic.List[System.String]'
    }

    process {
        # Get the current line from the pipeline.
        [string] $readLine = [string] $_
        # Add the read line to the list of all rows.
        $RowList.Add($readLine)

        # Determine how to split the line based on the delimiter.
        if ($Delimiter -eq '') {
            # If no delimiter, treat each character as a column.
            [string[]] $ColAry = $readLine.ToCharArray()
        } else {
            # Split the line by the specified delimiter.
            [string[]] $ColAry = $readLine.Split($Delimiter)
        }

        # Update MaxColNum if the current row has more columns.
        # This ensures all columns are captured for transposition, even with irregular input.
        [int] $tmpColNum = $ColAry.Count
        if ($tmpColNum -gt $MaxColNum) {
            $MaxColNum = $tmpColNum
        }
    }

    end {
        # Iterate through each potential column, from 0 to MaxColNum-1.
        for ($i = 0; $i -lt $MaxColNum; $i++) {
            # Buffer to hold elements for the current transposed output line.
            [string[]] $LineBuf = @()
            # Iterate through each original input row.
            foreach ($row in $RowList) {
                # Re-split the row to access individual fields.
                if ($Delimiter -eq '') {
                    $fields = $row.ToCharArray()
                } else {
                    $fields = $row.Split($Delimiter)
                }
                # Check if the current row has a field at the current column index ($i).
                if ($i -lt $fields.Count) {
                    # Add the field to the output line buffer.
                    $LineBuf += $fields[$i]
                } else {
                    # If no field exists, add the specified placeholder string for alignment.
                    $LineBuf += $Placeholder
                }
            }
            # Join the elements of the buffer with the delimiter and output the transposed line.
            if ( $Trim) {
                ($LineBuf -join $Delimiter).Trim() | Write-Output
            } else {
                $LineBuf -join $Delimiter | Write-Output
            }
        }
    }
}