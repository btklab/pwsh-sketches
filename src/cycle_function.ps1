<#
.SYNOPSIS
    cycle - Rotates elements in a pattern, moving the leftmost field to the right.
    This effectively creates a circular shift of the elements.

.LINK
    rev2, stair

.DESCRIPTION
    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact".
    Here is the original copyright notice for "egzact":

        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE

.EXAMPLE
    "A B C D E" | cycle
      A B C D E
      B C D E A
      C D E A B
      D E A B C
      E A B C D

.EXAMPLE
    "A B C D E" | stair | stair -r

    Description:
    ====================
    Enumerates all subsets of five fields: A B C D E.

.EXAMPLE
    "A B C D E" | cycle | stair | stair -r

    Description:
    ====================
    Combining with 'cycle' enumerates all subsets of five fields (A B C D E),
    including combinations that loop from E to A (like a circular route).

.EXAMPLE
    "A B C D E" | rev2 -e | cycle | stair | stair -r

    Description:
    ====================
    Combining 'cycle' and 'rev2 -e' enumerates all subsets of five fields (A B C D E),
    including combinations that loop from E to A (like a circular route),
    and also considers reverse patterns (e.g., B to A, like inner and outer loops of a circular route).

#>
function cycle {

    begin {
        # Initialize variables
        $writeLine = ''
        $readLine = ''
        $cnt = 0
    }

    process {
        $readLine = $_
        # Clean up input string: trim leading/trailing spaces and normalize multiple spaces to single space.
        $readLine = $readLine -Replace "^\s+", ""
        $readLine = $readLine -Replace "\s+$", ""
        $readLine = $readLine -Replace '  *', ' '
        $splitReadLine = $readLine -Split ' '
        $cnt = $splitReadLine.Count

        # MAIN LOGIC: Generate all cyclic permutations
        for ($i = 0; $i -lt $cnt; $i++) {
            if ($i -eq 0) {
                # First iteration: output the original string
                $writeLine = $readLine
            } else {
                # Subsequent iterations: split and re-join to create cyclic shift
                $topStr = [string]::join(" ", $splitReadLine[($i)..($cnt - 1)])
                $endStr = [string]::join(" ", $splitReadLine[0..($i - 1)])
                $writeLine = $topStr + ' ' + $endStr
            }
            Write-Output $writeLine
        }
    }

    end {
        # No specific cleanup needed here
    }

}
