<#
.SYNOPSIS
    Compare-Diff2-LCS (Alias: pwdiffu) -- GNU diff-like comparison, roughly equivalent to 'diff -u'.
    
    This function compares two text files line-by-line using the Longest Common Subsequence (LCS) algorithm.
    It aims to provide a diff output similar to GNU diff's unified format, including automatic colorization
    unless explicitly disabled.

    Equivalent:
    - Reports line-level differences between two files using LCS.
    - Outputs a format roughly similar to GNU diff's unified ('-u') output.
    - Automatically colorizes output for added, deleted, and common lines.
    - Includes hunk headers (e.g., `@@ -1,5 +1,5 @@`) indicating line ranges.

    Not Implemented:
    - Does not support all GNU diff options.
      - e.g., specific context lines beyond 3, ignore whitespace
    - No recursive directory diff.
    - No patch output format.

.LINK
    Compare-Diff2, Compare-Diff3, Compare-Diff2LCS,
    Invoke-GitBash

#>
function Compare-Diff2LCS {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('f1', 'p1')]
        [string]$Path1, # Path to the first file for comparison.
        
        [Parameter(Mandatory=$true, Position=1)]
        [Alias('f2', 'p2')]
        [string]$Path2, # Path to the second file for comparison.
        
        [Parameter(Mandatory=$false)]
        [switch]$OffColorized # If present, output will not be colorized.
    )

    # Read all lines from both input files into arrays.
    [string[]] $lines1 = Get-Content -Path $Path1 -Encoding utf8
    [string[]] $lines2 = Get-Content -Path $Path2 -Encoding utf8

    # Output header for files and timestamps
    [string] $leftFilePath       = (Resolve-Path -LiteralPath $Path1 -Relative).Replace('\', '/')
    [string] $rightFilePath      = (Resolve-Path -LiteralPath $Path2 -Relative).Replace('\', '/')
    [string] $leftFileTimeStamp  = (Get-Item $Path1).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.ffffff')
    [string] $rightFileTimeStamp = (Get-Item $Path2).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.ffffff')
    if ($OffColorized) {
        Write-Output "--- $leftFilePath`t$leftFileTimeStamp"
        Write-Output "+++ $rightFilePath`t$rightFileTimeStamp"
    } else {
        Write-Host "--- $leftFilePath`t$leftFileTimeStamp"   -ForegroundColor Red
        Write-Host "+++ $rightFilePath`t$rightFileTimeStamp" -ForegroundColor Green
    }

    # Get the number of lines in each file.
    [int] $m = $lines1.Count # Number of lines in file 1.
    [int] $n = $lines2.Count # Number of lines in file 2.

    # Initialize the LCS table (a 2D array) with zeros.
    # $lcs[$i][$j] will store the length of the LCS of lines1[0..$i-1] and lines2[0..$j-1].
    $lcs = @()
    for ($i = 0; $i -le $m; $i++) {
        $lcs += ,(0..$n | ForEach-Object { 0 })
    }

    # Populate the LCS table using dynamic programming.
    # Iterate through each line of both files to compute LCS lengths.
    for ($i = 1; $i -le $m; $i++) {
        for ($j = 1; $j -le $n; $j++) {
            # If current lines match, extend the LCS from the previous diagonal cell.
            if ($lines1[$i - 1] -eq $lines2[$j - 1]) {
                $lcs[$i][$j] = $lcs[$i - 1][$j - 1] + 1
            }
            # If lines don't match, take the maximum LCS from either removing a line from file 1 or file 2.
            else {
                $lcs[$i][$j] = [Math]::Max($lcs[$i - 1][$j], $lcs[$i][$j - 1])
            }
        }
    }

    # Global (script-scoped) variable to collect diff entries from the recursive function.
    # Each entry will be a PSCustomObject with Type ('Common', 'Added', 'Deleted'), Line content,
    # and 1-based line numbers from file1 (LineNum1) and file2 (LineNum2).
    # LineNum1 or LineNum2 will be $null if the line does not exist in that file.
    $script:diffResult = @()

    # Recursive helper function to trace back the LCS table and collect differences.
    # It identifies added, deleted, and common lines and their original 1-based line numbers.
    function Traverse-LCSAndCollectDiffs ([int]$i, [int]$j, [int]$line1Cursor, [int]$line2Cursor) {
        # Base case: If both pointers reach the beginning, stop recursion.
        if ($i -eq 0 -and $j -eq 0) {
            return
        }
        # If lines match, it's a common line. Recurse, then add.
        if ($i -gt 0 -and $j -gt 0 -and $lines1[$i - 1] -eq $lines2[$j - 1]) {
            Traverse-LCSAndCollectDiffs ($i - 1) ($j - 1) ($line1Cursor - 1) ($line2Cursor - 1)
            $script:diffResult += [PSCustomObject]@{
                Type = 'Common'
                Line = $lines1[$i - 1]
                LineNum1 = $line1Cursor
                LineNum2 = $line2Cursor
            }
        }
        # If line2 advances (or line1 is exhausted), it's an added line.
        # This condition implies $lines2[$j-1] is part of the LCS of $lines1[0..$i-1] and $lines2[0..$j-2]
        # or it's simply an addition if $i=0.
        elseif ($j -gt 0 -and ($i -eq 0 -or $lcs[$i][$j - 1] -ge $lcs[$i - 1][$j])) {
            Traverse-LCSAndCollectDiffs $i ($j - 1) $line1Cursor ($line2Cursor - 1)
            $script:diffResult += [PSCustomObject]@{
                Type = 'Added'
                Line = $lines2[$j - 1]
                LineNum1 = $null # Not present in file1
                LineNum2 = $line2Cursor
            }
        }
        # If line1 advances (or line2 is exhausted), it's a deleted line.
        # This condition implies $lines1[$i-1] is part of the LCS of $lines1[0..$i-2] and $lines2[0..$j-1]
        # or it's simply a deletion if $j=0.
        elseif ($i -gt 0 -and ($j -eq 0 -or $lcs[$i][$j - 1] -lt $lcs[$i - 1][$j])) {
            Traverse-LCSAndCollectDiffs ($i - 1) $j ($line1Cursor - 1) $line2Cursor
            $script:diffResult += [PSCustomObject]@{
                Type = 'Deleted'
                Line = $lines1[$i - 1]
                LineNum1 = $line1Cursor
                LineNum2 = $null # Not present in file2
            }
        }
    }

    # Start the recursive diff collection from the end of both files.
    # Initial line1Cursor and line2Cursor are the total counts, as we're traversing backwards.
    Traverse-LCSAndCollectDiffs $m $n $m $n

    # --- Hunk Processing and Output ---

    [int]$contextLines = 3 # Number of common lines to show before and after changes.
    [bool[]]$isHunkLine = New-Object bool[] ($script:diffResult.Count) # Marks lines that should be part of a hunk.

    # First pass: Mark all changed lines and their surrounding context lines as part of a hunk.
    for ($i = 0; $i -lt $script:diffResult.Count; $i++) {
        if ($script:diffResult[$i].Type -ne 'Common') {
            # This is a changed line. Mark it and its context.
            for ($k = - $contextLines; $k -le $contextLines; $k++) {
                $idx = $i + $k
                if ($idx -ge 0 -and $idx -lt $script:diffResult.Count) {
                    $isHunkLine[$idx] = $true
                }
            }
        }
    }

    # Second pass: Iterate through the marked lines to extract and print hunks.
    $i = 0
    while ($i -lt $script:diffResult.Count) {
        if ($isHunkLine[$i]) {
            # This is the start of a new hunk.
            [System.Collections.Generic.List[PSObject]]$hunkBuffer = New-Object System.Collections.Generic.List[PSObject]
            [int]$hunkOldLinesCount = 0
            [int]$hunkNewLinesCount = 0

            # Find the index where this hunk actually starts in the original diffResult array
            # This is important for calculating the 'l' (start line number) in the @@ header correctly.
            [int]$hunkStartIdx = $i 

            # Collect all lines belonging to this hunk
            while ($i -lt $script:diffResult.Count -and $isHunkLine[$i]) {
                $entry = $script:diffResult[$i]
                $hunkBuffer.Add($entry)

                # Count lines for the hunk header's 's' (length) values
                if ($entry.Type -ne 'Added') { # Common or Deleted line from original file
                    $hunkOldLinesCount++
                }
                if ($entry.Type -ne 'Deleted') { # Common or Added line for new file
                    $hunkNewLinesCount++
                }
                $i++
            }
            # $i now points to the first line *after* the current hunk, or the end of the array.
            [int]$hunkEndIdx = $i # Exclusive end index for the hunk

            # Calculate the 'l' (start line number) values for the @@ header.
            # This should be the 1-based line number of the *first line in the hunk buffer*
            # as it appears in the original file (Path1) and new file (Path2).

            [int]$oldStart = 0
            [int]$newStart = 0

            # Find the first relevant LineNum1 for oldStart
            foreach ($entryInHunk in $hunkBuffer) {
                if ($entryInHunk.LineNum1 -ne $null) {
                    $oldStart = $entryInHunk.LineNum1
                    break
                }
            }
            # If hunk consists only of 'Added' lines (no LineNum1s) or empty file context
            if ($oldStart -eq 0) {
                # Look at the line *just before* the hunk to get context for oldStart
                if ($hunkStartIdx -gt 0) {
                    $prevEntry = $script:diffResult[$hunkStartIdx - 1]
                    if ($prevEntry.LineNum1 -ne $null) {
                        $oldStart = $prevEntry.LineNum1 + 1
                    } else { # Should not happen with context, but for safety
                        $oldStart = 1
                    }
                } else {
                    $oldStart = 1 # Hunk starts at the very beginning of the file (e.g., all additions)
                }
            }

            # Find the first relevant LineNum2 for newStart
            foreach ($entryInHunk in $hunkBuffer) {
                if ($entryInHunk.LineNum2 -ne $null) {
                    $newStart = $entryInHunk.LineNum2
                    break
                }
            }
            # If hunk consists only of 'Deleted' lines (no LineNum2s) or empty file context
            if ($newStart -eq 0) {
                if ($hunkStartIdx -gt 0) {
                    $prevEntry = $script:diffResult[$hunkStartIdx - 1]
                    if ($prevEntry.LineNum2 -ne $null) {
                        $newStart = $prevEntry.LineNum2 + 1
                    } else { # Should not happen with context, but for safety
                        $newStart = 1
                    }
                } else {
                    $newStart = 1 # Hunk starts at the very beginning of the new file
                }
            }
            
            # Print hunk header
            $hunkHeader = "@@ -$oldStart,$hunkOldLinesCount +$newStart,$hunkNewLinesCount @@"
            if ($OffColorized) {
                Write-Output $hunkHeader
            } else {
                Write-Host $hunkHeader -ForegroundColor DarkMagenta
            }

            # Print lines within the current hunk buffer
            foreach ($lineEntry in $hunkBuffer) {
                $prefix = switch ($lineEntry.Type) {
                    'Added'  { "+" }
                    'Deleted' { "-" }
                    'Common' { " " } # Space for common lines
                }
                $foreColor = switch ($lineEntry.Type) {
                    'Added'   { "Green" }
                    'Deleted' { "Red" }
                    default   { "White" } # Default for common lines
                }

                if ($OffColorized) {
                    Write-Output "$prefix $($lineEntry.Line)"
                } else {
                    Write-Host "$prefix $($lineEntry.Line)" -ForegroundColor $foreColor
                }
            }
        } else {
            # Not part of a hunk, skip this line.
            $i++
        }
    }
}

# Alias Setup (Original alias setup remains the same)
[String] $tmpAliasName = "pwdiffu"
[String] $tmpCmdName   = "Compare-Diff2LCS"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }

if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
                    }
            } else {
                throw
            }
        }
        elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
                }
        } else {
            throw
        }
    } catch {
        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
}
else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green
        }
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
