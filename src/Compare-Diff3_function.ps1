<#
.SYNOPSIS
    Compare-Diff3 (Alias: pwdiff3) -- GNU diff3-like file comparison.
    
    Performs a basic 3-way merge similar to GNU diff3.

    This implementation replicates the basic line-by-line merge logic of GNU diff3:
    - Resolves lines when only one side (local or remote) has changed.
    - Marks conflicts when both local and remote differ from base.

    Not implemented:
    - Grouped change hunks (beyond basic block detection).
    - Conflict resolution via command-line flags.
    - Output file control and suppression of conflict markers.
    - Full GNU diff3's sophisticated LCS (Longest Common Subsequence) algorithm for optimal diffing.
    - Advanced reordering detection.

.DESCRIPTION
    Takes three file paths (base, local, remote) and compares line by line.
    Outputs merged content with conflict markers if differences are detected
    in both local and remote that differ from base.
    This version attempts to handle insertions and deletions more accurately
    by looking ahead for common lines to re-synchronize file pointers.
    Optionally, when 'Mine' branch deletes lines that 'Older' and 'Yours'
    branches retain, this script can be configured to keep the lines from
    'Older'/'Yours' instead of reflecting the deletion from 'Mine'.
    Optionally, when 'Yours' branch deletes lines that 'Older' and 'Mine'
    branches retain, this script can be configured to keep the lines from
    'Older'/'Mine' instead of reflecting the deletion from 'Yours'.

.PARAMETER Older
    Path to the base/original version of the file.

.PARAMETER Mine
    Path to the locally modified version of the file.

.PARAMETER Yours
    Path to the remotely modified version of the file.

.PARAMETER KeepOlderOnMineOrYoursDelete
    Use this switch to keep lines from the Older/MineOrYours branch when
    the Mine branch has deleted those lines, and the Older and Yours
    branches are identical for that segment. By default, the deletion from
    Mine would be reflected.

.PARAMETER KeepOlderOnMineDelete
    Use this switch to keep lines from the Older/Yours branch when
    the Mine branch has deleted those lines, and the Older and Yours
    branches are identical for that segment. By default, the deletion from
    Mine would be reflected.

.PARAMETER KeepOlderOnYoursDelete
    Use this switch to keep lines from the Older/Mine branch when
    the Yours branch has deleted those lines, and the Older and Mine
    branches are identical for that segment. By default, the deletion from
    Yours would be reflected.

.OUTPUTS
    [string[]] Merged lines

.LINK
    Compare-Diff2, Compare-Diff3, Compare-Diff2LCS,
    Invoke-GitBash


#>
function Compare-Diff3 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('fi')]
        [Alias('Base')]
        [string]$Older
        ,
        [Parameter(Mandatory=$true, Position=1)]
        [Alias('f2')]
        [Alias('My')]
        [string]$Mine
        ,
        [Parameter(Mandatory=$true, Position=2)]
        [Alias('f3')]
        [Alias('Your')]
        [string]$Yours
        ,
        [Parameter(Mandatory=$false)]
        [Alias('l')]
        [int]$lookaheadWindow = 100
        ,
        [Parameter(Mandatory=$false)]
        [Alias('k')]
        [switch]$KeepOlderOnMineOrYoursDelete
        ,
        [Parameter(Mandatory=$false)]
        [switch]$KeepOlderOnMineDelete
        ,
        [Parameter(Mandatory=$false)]
        [switch]$KeepOlderOnYoursDelete
    )

    # Helper function to read file content into a string array
    function Get-FileLines {
        param ([string]$Path)
        if (!(Test-Path -Path $Path)) {
            throw "File not found: $Path"
        }
        [string[]]$lines = Get-Content -Path $Path -Encoding utf8
        return $lines
    }

    # Helper function to compare two string arrays for exact equality
    function Compare-StringArrays {
        param (
            [string[]]$array1,
            [string[]]$array2
        )
        if ($array1.Count -ne $array2.Count) { return $false }
        for ($k = 0; $k -lt $array1.Count; $k++) {
            if ($array1[$k] -ne $array2[$k]) { return $false }
        }
        return $true
    }

    # Helper function to find the next occurrence of a line in an array, starting from an index
    # Used for lookahead to re-synchronize file pointers
    function FindNextLineIndex {
        param (
            [string[]]$lines,
            [int]$startIndex,
            [string]$targetLine,
            [int]$lookaheadLimit # Maximum lines to look ahead
        )
        for ($k = $startIndex; $k -lt [Math]::Min($lines.Count, $startIndex + $lookaheadLimit); $k++) {
            if ($lines[$k] -eq $targetLine) {
                return $k
            }
        }
        return -1 # Not found within the limit
    }

    # Read the content of all three input files into string arrays
    [string[]]$olderLines = Get-FileLines -Path $Older
    [string[]]$mineLines  = Get-FileLines -Path $Mine
    [string[]]$yoursLines = Get-FileLines -Path $Yours

    # Get file names
    [string]$olderFileName = (Resolve-Path -LiteralPath $Older -Relative).Replace('\', '/')
    [string]$mineFileName  = (Resolve-Path -LiteralPath $Mine  -Relative).Replace('\', '/')
    [string]$yoursFileName = (Resolve-Path -LiteralPath $Yours -Relative).Replace('\', '/')

    # Initialize a list to store the merged lines
    [System.Collections.Generic.List[string]]$result = @()

    # Initialize pointers for each file
    [int]$b = 0; [int]$m = 0; [int]$t = 0

    # Define a lookahead window size. This helps in finding common lines after a divergence.
    # A larger window increases accuracy but also computation time.
    [int]$lookaheadWindow = 100 # Look up to 100 lines ahead for a match

    # Main merge loop: continue as long as there are lines in any of the files
    while ($b -lt $olderLines.Count -or $m -lt $mineLines.Count -or $t -lt $yoursLines.Count) {

        # 1. Skip common prefix: Add lines that are identical across all three files
        while ($b -lt $olderLines.Count -and $m -lt $mineLines.Count -and $t -lt $yoursLines.Count -and
               $olderLines[$b] -eq $mineLines[$m] -and $mineLines[$m] -eq $yoursLines[$t]) {
            $result.Add($olderLines[$b])
            $b++; $m++; $t++
        }

        # If all files have been fully processed, break the loop
        if ($b -ge $olderLines.Count -and $m -ge $mineLines.Count -and $t -ge $yoursLines.Count) {
            break
        }

        # 2. Identify the divergent block: Find the next common line to re-synchronize
        [int]$nextCommonB = -1
        [int]$nextCommonM = -1
        [int]$nextCommonT = -1

        # Search for a line that exists in all three files further down, within the lookahead window
        for ($k = 0; $k -lt $lookaheadWindow; $k++) {
            if (($b + $k) -lt $olderLines.Count) {
                $candidateLine = $olderLines[$b + $k]
                $foundM = FindNextLineIndex -lines $mineLines -startIndex $m -targetLine $candidateLine -lookaheadLimit $lookaheadWindow
                $foundT = FindNextLineIndex -lines $yoursLines -startIndex $t -targetLine $candidateLine -lookaheadLimit $lookaheadWindow

                # If a common line is found in all three, this is our re-synchronization point
                if ($foundM -ne -1 -and $foundT -ne -1) {
                    $nextCommonB = $b + $k
                    $nextCommonM = $foundM
                    $nextCommonT = $foundT
                    break # Found a common line, stop looking further
                }
            }
        }

        # If no common line was found within the lookahead window (or at end of files),
        # process the remaining lines as one large hunk.
        if ($nextCommonB -eq -1) {
            # Collect all remaining lines from each file
            [System.Collections.Generic.List[string]]$currentBaseChunk   = @()
            [System.Collections.Generic.List[string]]$currentMineChunk   = @()
            [System.Collections.Generic.List[string]]$currentYoursChunk = @()

            while ($b -lt $olderLines.Count)   { $currentBaseChunk.Add($olderLines[$b]);   $b++ }
            while ($m -lt $mineLines.Count)   { $currentMineChunk.Add($mineLines[$m]);   $m++ }
            while ($t -lt $yoursLines.Count) { $currentYoursChunk.Add($yoursLines[$t]); $t++ }

            # Determine if it's a simple append or a conflict
            $mineChanged   = !(Compare-StringArrays -array1 $currentMineChunk -array2 $currentBaseChunk)
            $yoursChanged = !(Compare-StringArrays -array1 $currentYoursChunk -array2 $currentBaseChunk)
            $bothIdentical = (Compare-StringArrays -array1 $currentMineChunk -array2 $currentYoursChunk)

            if (!$mineChanged -and !$yoursChanged) {
                # No changes from base in either mine or Yours (should ideally be caught by common prefix)
                $result.AddRange($currentBaseChunk)
            } elseif ($mineChanged -and !$yoursChanged) {
                # Only mine changed from base, Yours is same as base.
                # If mine deleted lines that were in base, take base/Yours version.
                # Otherwise, mine modified lines, take mine's version.
                if (($KeepOlderOnMineDelete -or $KeepOlderOnMineOrYoursDelete) -and $currentMineChunk.Count -eq 0 -and $currentBaseChunk.Count -gt 0) {
                    # Mine deleted lines that were present in base. The Yours branch kept them.
                    # So, we should keep the lines from base (or Yours).
                    $result.AddRange($currentBaseChunk)
                } else {
                    # Mine modified lines (or added new ones if baseHunk was empty, but that's handled by lookahead).
                    # Take mine's version.
                    $result.AddRange($currentMineChunk)
                }
            } elseif (!$mineChanged -and $yoursChanged) {
                # Only Yours changed from base, mine is same as base.
                # If Yours deleted lines that were in base, take base/mine version.
                # Otherwise, Yours modified lines, take Yours' version.
                if (($KeepOlderOnYoursDelete -or $KeepOlderOnMineOrYoursDelete) -and $currentYoursChunk.Count -eq 0 -and $currentBaseChunk.Count -gt 0) {
                    # Yours deleted lines that were present in base. The mine branch kept them.
                    # So, we should keep the lines from base (or mine).
                    $result.AddRange($currentBaseChunk)
                } else {
                    # Yours modified lines (or added new ones if baseHunk was empty, but that's handled by lookahead).
                    # Take Yours' version.
                    $result.AddRange($currentYoursChunk)
                }
            } elseif ($mineChanged -and $yoursChanged -and $bothIdentical) {
                # Both changed identically from base, take one (mine)
                $result.AddRange($currentMineChunk)
            } else {
                # Conflict: Both changed differently from base
                $result.Add("<<<<<<< $olderFileName")
                $result.AddRange($currentBaseChunk)
                $result.Add("||||||| $mineFileName")
                $result.AddRange($currentMineChunk)
                $result.Add("=======")
                $result.AddRange($currentYoursChunk)
                $result.Add(">>>>>>> $yoursFileName")
            }
            break # All files processed from this point
        }

        # If a common line was found, collect the hunk of divergent lines before it
        [System.Collections.Generic.List[string]]$olderHunk = @()
        [System.Collections.Generic.List[string]]$mineHunk  = @()
        [System.Collections.Generic.List[string]]$yoursHunk = @()

        while ($b -lt $nextCommonB) { $olderHunk.Add($olderLines[$b]); $b++ }
        while ($m -lt $nextCommonM) { $mineHunk.Add($mineLines[$m]); $m++ }
        while ($t -lt $nextCommonT) { $yoursHunk.Add($yoursLines[$t]); $t++ }

        # Apply diff3 merge rules to the collected hunks
        $mineChanged   = !(Compare-StringArrays -array1 $mineHunk  -array2 $olderHunk)
        $yoursChanged  = !(Compare-StringArrays -array1 $yoursHunk -array2 $olderHunk)
        $bothIdentical = (Compare-StringArrays  -array1 $mineHunk  -array2 $yoursHunk)

        if (!$mineChanged -and !$yoursChanged) {
            # No change in either from base (this case should ideally be covered by the common prefix loop)
            $result.AddRange($olderHunk)
        } elseif ($mineChanged -and !$yoursChanged) {
            # Only mine changed from base, Yours is same as base.
            # If mine deleted lines that were in base, take base/Yours version.
            # Otherwise, mine modified lines, take mine's version.
            if (($KeepOlderOnMineDelete -or $KeepOlderOnMineOrYoursDelete) -and $mineHunk.Count -eq 0 -and $olderHunk.Count -gt 0) {
                # Mine deleted lines that were present in base. The Yours branch kept them.
                # So, we should keep the lines from base (or Yours).
                $result.AddRange($olderHunk)
            } else {
                # Mine modified lines (or added new ones if baseHunk was empty, but that's handled by lookahead).
                # Take mine's version.
                $result.AddRange($mineHunk)
            }
        } elseif (!$mineChanged -and $yoursChanged) {
            # Only Yours changed from base, mine is same as base.
            # If Yours deleted lines that were in base, take base/mine version.
            # Otherwise, Yours modified lines, take Yours' version.
            if (($KeepOlderOnYoursDelete -or $KeepOlderOnMineOrYoursDelete) -and $yoursHunk.Count -eq 0 -and $olderHunk.Count -gt 0) {
                # Yours deleted lines that were present in base. The mine branch kept them.
                # So, we should keep the lines from base (or mine).
                $result.AddRange($olderHunk)
            } else {
                # Yours modified lines (or added new ones if baseHunk was empty, but that's handled by lookahead).
                # Take Yours' version.
                $result.AddRange($yoursHunk)
            }
        } elseif ($mineChanged -and $yoursChanged -and $bothIdentical) {
            # Both changed identically from base, take one (mine)
            $result.AddRange($mineHunk)
        } else {
            # Conflict: Both changed differently from base
            $result.Add("<<<<<<< $olderFileName")
            $result.AddRange($olderHunk)
            $result.Add("||||||| $mineFileName")
            $result.AddRange($mineHunk)
            $result.Add("=======")
            $result.AddRange($yoursHunk)
            $result.Add(">>>>>>> $yoursFileName")
        }
        # Pointers (b, m, t) are now at the start of the next common block,
        # and the loop will continue from there.
    }

    return $result
}

# set alias
[String] $tmpAliasName = "pwdiff3"
[String] $tmpCmdName   = "Compare-Diff3"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
# is alias already exists?
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
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
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
} else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green
        }
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
