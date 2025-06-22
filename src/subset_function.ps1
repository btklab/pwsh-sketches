<#
.SYNOPSIS
    subset - Generates all field subsets.

    subset [fs=<String>]

    fs: Specifies the field separator. Defaults to a single space.

.DESCRIPTION

    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact",
    Here is the original copyright notice for "egzact":
    
        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE

.EXAMPLE
    PS> "A B C D" | subset
    A
    B
    C
    D
    A B
    A C
    B C
    A D
    B D
    C D
    A B C
    A B D
    A C D
    B C D
    A B C D

#>
function subset {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$InputObject, # Corresponds to pipeline input
        
        [string]$fs = ' ' # Field separator. Defaults to a single space.
    )

    begin {
        # Helper function to generate combinations
        function Get-CombinationsInternal {
            param (
                [array]$Elements,
                [int]$K,
                [int]$StartIndex = 0,
                [array]$CurrentCombination = @(),
                [string]$Separator # Separator to join the results
            )

            # If the current combination length reaches K, output it
            if ($CurrentCombination.Count -eq $K) {
                ($CurrentCombination | Where-Object { $_ }) -join $Separator
                return
            }

            # If the end of Elements is reached, terminate
            if ($StartIndex -ge $Elements.Count) {
                return
            }

            # Case: Include the current element
            $newCombination = $CurrentCombination + $Elements[$StartIndex]
            Get-CombinationsInternal -Elements $Elements -K $K -StartIndex ($StartIndex + 1) -CurrentCombination $newCombination -Separator $Separator

            # Case: Exclude the current element (start from the next element)
            Get-CombinationsInternal -Elements $Elements -K $K -StartIndex ($StartIndex + 1) -CurrentCombination $CurrentCombination -Separator $Separator
        }
    }

    process {
        foreach ($line in $InputObject) {
            # Split the input string by the separator
            $fields = $line.Split($fs, [System.StringSplitOptions]::RemoveEmptyEntries)

            # Total number of fields
            $n = $fields.Count

            # Generate and output all combinations from length 1 to n
            for ($k = 1; $k -le $n; $k++) {
                Get-CombinationsInternal -Elements $fields -K $k -Separator $fs
            }
        }
    }

    end {
        # End processing (nothing specific here for now)
    }
}
