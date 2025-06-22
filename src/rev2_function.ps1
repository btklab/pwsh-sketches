<#
.SYNOPSIS
    Reverse columns.

    Reverses columns separated by a delimiter (default: space).
    Does not reverse strings within columns.
    Accepts input from the pipeline.

.DESCRIPTION
    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact".
    Here is the original copyright notice for "egzact":

        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE

.LINK
    rev, rev2, stair, cycle

.EXAMPLE
    "01 02 03" | rev2
    # Output: 03 02 01

.EXAMPLE
    "01 02 03" | rev2 -e
    # Output:
    # 01 02 03
    # 03 02 01

#>
function rev2 {
    Param(
        [Parameter(Mandatory=$False)]
        [Alias('e')]
        [switch] $echo, # If specified, echoes the input line before reversing.

        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [string] $Delimiter = " ", # Delimiter for splitting columns (default is space).

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$True)]
        [string[]]$Text # Input text from the pipeline.
    )
    process {
        [string] $readLine = "$_".Trim() # Get current pipeline object and trim whitespace.

        # Determine how to split the input line based on the delimiter.
        if ($Delimiter -eq '') {
            [string[]] $splitReadLine = $readLine.ToCharArray() # Split into characters if delimiter is empty.
        } else {
            [string[]] $splitReadLine = $readLine.Split($Delimiter) # Split by specified delimiter.
        }

        # If -echo switch is present, output the original line.
        if ($echo) {
            Write-Output $readLine
        }

        # Reverse the order of the split columns and join them back with the delimiter.
        [string] $writeLine = [string]::join($Delimiter, $splitReadLine[($splitReadLine.Count - 1)..0])
        Write-Output $writeLine
    }
}
