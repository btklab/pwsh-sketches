<#
.SYNOPSIS
    Get-YamlFromMarkdown - Extract YAML front-matter from Markdown.

    Extract YAML front-matter from Markdown text or files
    with customizable normalization.

.DESCRIPTION
    Get-YamlFromMarkdown reads Markdown input (via file path, pipeline strings, or STDIN),
    locates YAML front-matter blocks delimited by start/end markers, and returns raw
    YAML content.  You can adjust delimiters, allow multiple blocks, and apply a suite of
    normalization options (line endings, indentation, tabs → spaces, trimming empty lines).

    This design follows principles from “Readable Code”:
        • Small, clear functions
        • Self-documenting names
        • Early returns for errors
        • Single responsibility for each code block

.LINK
    Parse-YAML, Get-YamlFromMarkdown, Convert-DictionaryToPSCustomObject (dict2psobject)

.PARAMETER Path
    File path to a Markdown document.  If omitted, input is read from pipeline
    or STDIN.

.PARAMETER StartDelimiter
    String that marks the start of YAML front-matter (default '---').

.PARAMETER EndDelimiter
    String that marks the end of YAML front-matter (default '---').

.PARAMETER AllowMultiple
    Switch to extract all YAML blocks, not just the first.

.PARAMETER NormalizeLineEndings
    Switch to convert CRLF ("\r\n") to LF ("\n") in the extracted YAML.

.PARAMETER TrimIndentation
    Switch to detect and remove the common leading whitespace on all lines.

.PARAMETER TabToSpaces
    Number of spaces to replace each tab character. 0 (default) leaves tabs intact.

.PARAMETER TrimEmptyLines
    Switch to remove blank lines at the start and end of each YAML block.

.PARAMETER ReturnString
    Switch to output a single concatenated string of all blocks.  By default,
    each block is emitted as a separate string object.

.EXAMPLE
    # From file, basic extraction
    Get-YamlFromMarkdown -Path './README.md'

.EXAMPLE
    # From pipeline, normalize and trim
    Get-Content './README.md' |
    Get-YamlFromMarkdown -NormalizeLineEndings -TrimIndentation -TabToSpaces 2

.EXAMPLE
    # Extract multiple blocks, return single string
    Get-YamlFromMarkdown -Path './doc.md' -AllowMultiple -ReturnString

.NOTES
    Readable Code practices:
    – Descriptive names
    – Single-level of abstraction per block
    – Early exits on errors
    – Clear logical partitioning
#>
function Get-YamlFromMarkdown {

    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string] $Path,

        [Parameter(ValueFromPipeline)]
        [string] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $StartDelimiter = '---',

        [ValidateNotNullOrEmpty()]
        [string] $EndDelimiter   = '---',

        [switch] $AllowMultiple,
        [switch] $NormalizeLineEndings,
        [switch] $TrimIndentation,
        [int]    $TabToSpaces    = 0,
        [switch] $TrimEmptyLines,
        [switch] $ReturnString
    )

    # BEGIN: buffer for pipeline or STDIN text
    begin {
        $bufferLines = [System.Collections.Generic.List[string]]::new()
        $hasLoadedFile = $false
    }

    # PROCESS: gather input or read file
    process {
        if ($PSBoundParameters.ContainsKey('Path')) {
            # If Path is specified, read it once and skip pipeline input
            try {
                $rawContent = Get-Content -Raw -LiteralPath $Path -ErrorAction Stop
            }
            catch {
                Write-Error "Failed to read file '$Path': $_"
                return
            }
            $hasLoadedFile = $true
            return
        }

        if ($null -ne $InputObject) {
            # Collect piped-in lines
            $bufferLines.Add($InputObject)
        }
    }

    # END: assemble text, extract YAML, apply normalization, then output
    end {
        # 1. Assemble full content
        if (-not $hasLoadedFile) {
            if ($bufferLines.Count -gt 0) {
                $rawContent = $bufferLines -join "`n"
            }
            else {
                # Fallback to STDIN
                $rawContent = [Console]::In.ReadToEnd()
            }
        }

        if ([string]::IsNullOrWhiteSpace($rawContent)) {
            Write-Warning "No input supplied."
            return
        }

        # 2. Build a dynamic regex to locate YAML blocks
        $escapedStart = [regex]::Escape($StartDelimiter)
        $escapedEnd   = [regex]::Escape($EndDelimiter)
        # (?ms) = singleline + multiline: dot matches newline, ^/$ match each line
        $pattern = "(?ms)^\s*${escapedStart}\s*$\r?\n(.*?)\r?\n^\s*${escapedEnd}\s*$"

        # 3. Find matches
        if ($AllowMultiple) {
            $matches = [regex]::Matches($rawContent, $pattern)
        }
        else {
            $singleMatch = [regex]::Match($rawContent, $pattern)
            $matches = if ($singleMatch.Success) { ,$singleMatch } else { @() }
        }

        if ($matches.Count -eq 0) {
            Write-Warning "No YAML front-matter found using delimiters '$StartDelimiter'/'$EndDelimiter'."
            return
        }

        # 4. Extract, normalize, and collect blocks
        $results = [System.Collections.Generic.List[string]]::new()

        foreach ($m in $matches) {
            # Raw block content between delimiters
            $block = $m.Groups[1].Value

            # A) Normalize line endings if requested
            if ($NormalizeLineEndings) {
                $block = $block -replace "`r`n", "`n"
            }

            # B) Convert tabs to spaces if requested
            if ($TabToSpaces -gt 0) {
                $spaces = ' ' * $TabToSpaces
                $block = $block -replace "`t", $spaces
            }

            # C) Trim common leading indentation
            if ($TrimIndentation) {
                $lines = $block -split "`n"
                # Compute indent of each non-blank line
                $indents = $lines |
                    Where-Object { $_ -match '\S' } |
                    ForEach-Object {
                        ([regex]::Match($_, '^( *)')).Groups[1].Value.Length
                    }
                if ($indents) {
                    $minIndent = ($indents | Measure-Object -Minimum).Minimum
                    $lines = $lines | ForEach-Object {
                        if ($_.Length -ge $minIndent) {
                            $_.Substring($minIndent)
                        }
                        else {
                            $_
                        }
                    }
                }
                $block = $lines -join "`n"
            }

            # D) Trim blank lines at start/end
            if ($TrimEmptyLines) {
                $lines = [System.Collections.Generic.List[string]]($block -split "`n")
                while ($lines.Count -and $lines[0] -match '^\s*$') { $lines.RemoveAt(0) }
                while ($lines.Count -and $lines[-1] -match '^\s*$') { $lines.RemoveAt($lines.Count - 1) }
                $block = $lines -join "`n"
            }

            $results.Add($block)
        }

        # 5. Output results per ReturnString flag
        if ($ReturnString) {
            # Join multiple blocks with two newlines
            $results -join "`n`n"
        }
        else {
            # Emit each block as a separate string
            $results
        }
    }
}

