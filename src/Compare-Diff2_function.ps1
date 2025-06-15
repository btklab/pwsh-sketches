<#
.SYNOPSIS
    Compare-Diff2 (Alias: pwdiff) -- GNU diff-like file comparison.
    
    Emulates core behavior of GNU diff for comparing two text files line-by-line.

    Equivalent:
    - Reports line-level differences between two files.
    - Outputs traditional diff format (with '<' and '>' markers).
    - Automatically colorizes output for added/deleted/changed lines.

    Not Implemented:
    - Does not support diff options (-u, -c, -e, etc).
    - No intelligent block comparison or edit distance optimization.
    - No recursive directory diff.
    - No patch output format.

.LINK
    Compare-Diff2, Compare-Diff3, Compare-Diff2LCS,
    Invoke-GitBash

#>
function Compare-Diff2 {
    
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
    [string[]]$lines1 = Get-Content -Path $Path1 -Encoding utf8
    [string[]]$lines2 = Get-Content -Path $Path2 -Encoding utf8

    # Initialize pointers for traversing lines in both files.
    [int]$i = 0 # Current index for $lines1.
    [int]$j = 0 # Current index for $lines2.

    # Loop as long as there are lines remaining in either file.
    while ($i -lt $lines1.Count -or $j -lt $lines2.Count) {
        # Store start line numbers for the current chunk of differences.
        [int]$start1 = $i + 1
        [int]$start2 = $j + 1

        # Temporary arrays to store differing lines for the current chunk.
        [string[]]$chunk1 = @()
        [string[]]$chunk2 = @()
        # Flag to indicate if any line in the current chunk has changed.
        [bool]$lineChanged = $false

        # Skip common leading lines.
        # This loop advances pointers 'i' and 'j' as long as lines match in both files.
        while (
            $i -lt $lines1.Count -and $j -lt $lines2.Count -and
            ($lines1[$i] -eq $lines2[$j])
        ) {
            $i++
            $j++
        }

        # If both files have been fully processed, exit the loop.
        if ($i -ge $lines1.Count -and $j -ge $lines2.Count) {
            break
        }

        # Store previous positions to detect if no progress is made within the difference chunk loop,
        # which helps prevent infinite loops for certain edge cases.
        [int]$prevI = $i
        [int]$prevJ = $j
        # Counters for lines added to chunk1 and chunk2 respectively.
        [int]$c1 = 0
        [int]$c2 = 0

        # Loop to collect differing lines until a common line is found or end of file.
        while ($i -lt $lines1.Count -or $j -lt $lines2.Count) {
            # Get current lines from each file, or $null if end of file reached.
            $line1 = if ($i -lt $lines1.Count) { $lines1[$i] } else { $null }
            $line2 = if ($j -lt $lines2.Count) { $lines2[$j] } else { $null }

            # If lines match, it indicates the end of the current difference chunk.
            if ($line1 -eq $line2) {
                break
            }

            # Handle lines unique to file 1 (deleted lines).
            # If line1 exists AND (line2 doesn't exist OR line1 is not found anywhere in remaining lines of file2).
            if ($line1 -ne $null -and ($line2 -eq $null -or $lines2 -notcontains $line1)) {
                $chunk1 += $line1 # Add to chunk1 (deleted).
                $i++              # Advance pointer for file 1.
                $lineChanged = $true
                $c1++
            }
            # Handle lines unique to file 2 (added lines).
            # If line2 exists AND (line1 doesn't exist OR line2 is not found anywhere in remaining lines of file1).
            elseif ($line2 -ne $null -and ($line1 -eq $null -or $lines1 -notcontains $line2)) {
                $chunk2 += $line2 # Add to chunk2 (added).
                $j++              # Advance pointer for file 2.
                $lineChanged = $true
                $c2++
            }
            # Handle changed lines (lines present in both, but different content).
            # This case means both lines exist but they are not equal (as per the break condition earlier).
            else {
                $chunk1 += $line1 # Add original line.
                $chunk2 += $line2 # Add new line.
                $i++              # Advance both pointers.
                $j++
                $lineChanged = $true
                $c1++
                $c2++
            }

            # Break if no progress is made in both pointers within the differing chunk.
            # This is a safeguard against potential infinite loops for complex mismatches.
            if ($i -eq $prevI -and $j -eq $prevJ) {
                break
            }
            # Update previous positions for the next iteration's progress check.
            $prevI = $i
            $prevJ = $j
        }

        # If any changes were detected in the current chunk, format and output them.
        if ($lineChanged) {
            # Calculate end line numbers for the current difference chunk.
            [int]$end1 = $i
            [int]$end2 = $j

            # Calculate start line numbers for the output range.
            [int]$s1 = $end1 - $c1 + 1
            [int]$s2 = $end2 - $c2 + 1

            # Format the line ranges for file 1 in diff 'c' format (e.g., '1,2c3,4').
            [string]$range1 = if ( $end1 -eq $s1 ) {
                    "$($end1)"
                } elseif ($end1 -lt $s1 ) { # Handle cases where a chunk might start and end on the same conceptual line.
                    "$($end1)"
                } else {
                    "$($s1),$($end1)"
                }
            # Format the line ranges for file 2.
            [string]$range2 = if ( $end2 -eq $s2 ) {
                    "$($end2)"
                } elseif ($end2 -lt $s2 ) { # Handle cases where a chunk might start and end on the same conceptual line.
                    "$($end2)"
                } else {
                    "$($s2),$($end2)"
                }

            # Output the diff header (e.g., "1c1" or "1,2c3,4").
            if ($OffColorized) {
                Write-Output $("$range1" + "c" + "$range2")
            } else {
                Write-Host $("$range1" + "c" + "$range2") -ForegroundColor Blue
            }

            # Output lines from file 1 that were changed/deleted, prefixed with '<'.
            foreach ($line in $chunk1) {
                if ($OffColorized) {
                    Write-Output "< $line"
                } else {
                    Write-Host "< $line" -ForegroundColor Red
                }
            }

            # Output the separator '---' between deleted and added lines.
            if ($OffColorized) {
                Write-Output "---"
            } else {
                Write-Host "---" -ForegroundColor Gray
            }

            # Output lines from file 2 that were changed/added, prefixed with '>'.
            foreach ($line in $chunk2) {
                if ($OffColorized) {
                    Write-Output "> $line"
                } else {
                    Write-Host "> $line" -ForegroundColor Green
                }
            }
        }
        # If no lines changed in the current segment, simply advance pointers (should not happen if inner while loop works as expected).
        else {
            if ($i -lt $lines1.Count) { $i++ }
            if ($j -lt $lines2.Count) { $j++ }
        }
    }
}

# Alias Setup
# Define alias name and command name.
[String] $tmpAliasName = "pwdiff"
[String] $tmpCmdName   = "Compare-Diff2"
# Get the full path of the current script for error messages.
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
# Normalize path separators for Windows.
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }

# Check if the alias already exists.
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        # If the existing alias refers to this function, update it.
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName)" -ForegroundColor Green # Confirm alias update.
                    }
            } else {
                throw # Throw error if alias exists but refers to a different command.
            }
        } # If existing command is an executable (e.g., 'diff.exe'), overwrite it with this alias.
        elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName)" -ForegroundColor Green # Confirm alias update.
                }
        } else {
            throw # Throw error for other command types.
        }
    } catch {
        # Display an error if the alias conflicts with an existing command or another alias.
        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        # Clean up temporary variables.
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} # If alias does not exist, create a new one.
else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green # Confirm alias creation.
        }
    # Clean up temporary variables.
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
