<#
.SYNOPSIS
    uniq - Reports or omits repeated lines by comparing adjacent lines.
    
    This command assumes that the input has been presorted.

.DESCRIPTION
    The uniq command compares sorted text received from the pipeline line by line.
    It can remove duplicate lines, count the occurrences of duplicates, or display only the duplicated lines.
    By default, the comparison is case-insensitive.

    Examples:

    For these examples, we'll use a file named sample.txt with the following content:
    
    apple
    apple
    orange
    orange
    orange
    grape
    apple

    1. Removing Duplicate Lines
    
    When you run uniq by itself, it removes only consecutive duplicate lines.
    
    cat sample.txt | uniq

    Output:
    
    apple
    orange
    grape
    apple

    Since the last apple is not consecutive with the first two, it remains in the output.
    
    2. Removing All Duplicate Lines (with sort)

    To remove all duplicate lines in a file, you should first sort the file and then pipe the output to uniq. This is the most common use case.
    
    cat sample.txt | sort | uniq

    Output:
    
    apple
    grape
    orange

.PARAMETER Count
    Precedes each output line with a count of its consecutive occurrences. The alias is 'c'.

.PARAMETER DuplicatedOnly
    Only displays lines that are consecutively duplicated. The alias is 'd'.

.PARAMETER UniqueOnly
    Only displays lines that are not consecutively repeated. The alias is 'u'.

.PARAMETER CaseSensitive
    When this switch is specified, the comparison of lines will be case-sensitive.

.PARAMETER InputObject
    The input object (line) passed from the pipeline.

.EXAMPLE
    cat a.txt | sort | uniq
    
    After sorting the file, it displays the content with duplicate lines removed.
    (This is similar in behavior to `Sort-Object -Unique`)
    
    Input (a.txt):
    A 1 10
    B 1 10
    A 1 10
    C 1 10

    Output:
    A 1 10
    B 1 10
    C 1 10

.EXAMPLE
    cat a.txt | sort | uniq -c
    cat a.txt | sort | uniq -Count
    
    Counts duplicate lines and displays the number of occurrences before each line.
    
    Output:
    2 A 1 10
    1 B 1 10
    1 C 1 10

.EXAMPLE
    cat a.txt | sort | uniq -d
    
    Displays only the lines that are duplicated.
    
    Output:
    A 1 10

.EXAMPLE
    'A', 'B', 'B', 'C' | sort | uniq -u
    
    Displays only the lines that are not repeated (unique lines).
    
    Output:
    A
    C

.EXAMPLE
    'a', 'A', 'b' | sort | uniq -Count -CaseSensitive

    Performs a case-sensitive count using the -CaseSensitive option.

    Output:
    1 A
    1 a
    1 b

.NOTES
    This function only compares adjacent lines, so the input must be sorted beforehand.
    Running this on unsorted input may lead to unexpected results.
#>
function uniq {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='Count')]
        [Alias('c')]
        [switch]$Count,
        
        [Parameter(Mandatory=$false, ParameterSetName='DuplicatedOnly')]
        [Alias('d')]
        [switch]$DuplicatedOnly,
        
        [Parameter(Mandatory=$false, ParameterSetName='UniqueOnly')]
        [Alias('u')]
        [switch]$UniqueOnly,
        
        [Parameter(Mandatory=$false)]
        [switch]$CaseSensitive,
        
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        $InputObject
    )

    begin {
        # Determine the comparison method based on the -CaseSensitive switch
        $comparisonType = if ($CaseSensitive) {
            [System.StringComparison]::Ordinal
        }
        else {
            [System.StringComparison]::OrdinalIgnoreCase
        }

        # Initialize flag and variables for processing the first line
        [bool]$isFirstLine = $true
        [string]$previousLine = $null
        [int]$lineCounter = 0
    }

    process {
        [string]$currentLine = [string]$InputObject

        # Process the first line
        if ($isFirstLine) {
            [string]$previousLine = $currentLine
            [int]$lineCounter = 1
            [bool]$isFirstLine = $false
            return # Move to the next line
        }

        # Compare the current line with the previous one
        if (-not [string]::Equals($currentLine, $previousLine, $comparisonType)) {
            # If the line has changed, output the result for the previous group of lines
            switch ($PsCmdlet.ParameterSetName) {
                'Count' {
                    Write-Output "$lineCounter $previousLine"
                }
                'DuplicatedOnly' {
                    if ($lineCounter -ge 2) {
                        Write-Output "$previousLine"
                    }
                }
                'UniqueOnly' {
                    if ($lineCounter -eq 1) {
                        Write-Output "$previousLine"
                    }
                }
                'Default' {
                    Write-Output "$previousLine"
                }
            }
            # Reset the counter and line for the next group
            [string]$previousLine = $currentLine
            [int]$lineCounter = 1
        }
        else {
            # If the line is the same, increment the counter
            $lineCounter++
        }
    }

    end {
        # Process the very last group of lines from the pipeline
        # (This only runs if there was at least one line of input)
        if (-not $isFirstLine) {
            switch ($PsCmdlet.ParameterSetName) {
                'Count' {
                    Write-Output "$lineCounter $previousLine"
                }
                'DuplicatedOnly' {
                    if ($lineCounter -ge 2) {
                        Write-Output "$previousLine"
                    }
                }
                'UniqueOnly' {
                    if ($lineCounter -eq 1) {
                        Write-Output "$previousLine"
                    }
                }
                'Default' {
                    Write-Output "$previousLine"
                }
            }
        }
    }
}
