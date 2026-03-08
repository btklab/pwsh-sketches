function Invoke-RichTree {

    <#
    .SYNOPSIS
        Invoke-RichTree (Alias: lst) -- Generates visual directory tree with regex filtering.
        
        Generates a highly optimized, colorized, and visual directory tree with regex filtering, 
        multi-column layout capabilities, and clickable hyperlinks.
        
        Constraints:
        - Modern Terminal Required: Designed for Windows Terminal or similar modern emulators. Legacy consoles (cmd.exe) may show raw escape codes unless the -Ascii switch is used.
        - Initial Overhead: The very first execution per session incurs a brief delay (<1s) to dynamically compile the embedded C# traversal engine.
        - Long Paths in Columns: Extremely deep or long paths may break the column grid alignment. Use -MaxColumnWidth to mitigate this.

    .DESCRIPTION
        The Invoke-RichTree function provides a fast and feature-rich alternative to standard tree commands. 
        It solves the common problem of PowerShell's `Get-ChildItem` being painfully slow in deep directories 
        by embedding a custom, dynamically compiled C# engine that handles file system traversal and regex matching natively.

        Core Features:
        - High Performance: Bypasses PowerShell's pipeline overhead for raw disk I/O and pattern matching.
        - Regex Search (-Grep): Advanced file/folder searching using regular expressions.
        - Inverted Search (-Invert): Exclude results matching the regex pattern.
        - Responsive Multi-Column Grid (-Columns): Optimizes vertical screen real estate.
        - Perfect Alignment: Accurately calculates true visual terminal width, explicitly accounting for zero-width ANSI codes and double-width CJK (Chinese, Japanese, Korean) characters.
        - Interactive Paths: Renders standard file paths as OSC 8 clickable hyperlinks (Ctrl+Click in modern terminals).

    .PARAMETER Path
        The root directory to begin the traversal. Defaults to the current working directory ($PWD).

    .PARAMETER Filter
        Standard file system wildcard filter (e.g., "*.log"). Applied directly during enumeration for speed.

    .PARAMETER Include
        An array of string patterns to explicitly include in the output.

    .PARAMETER Exclude
        An array of string patterns to explicitly omit from the output.

    .PARAMETER Grep
        A Regular Expression (Regex) pattern to search for within file or directory names. 
        Matches are case-insensitive by default.

    .PARAMETER Invert
        Reverses the behavior of -Grep. Only items that DO NOT match the regex pattern are returned.

    .PARAMETER ShowHidden
        Bypasses the default exclusion of hidden files and directories.

    .PARAMETER DirectoriesOnly
        Filters out all files, displaying only the directory structure.

    .PARAMETER Recurse
        Traverses all child directories recursively. If omitted, only the immediate children are shown (Depth = 1).

    .PARAMETER Depth
        Explicitly defines the maximum depth of directory traversal. Prevents memory exhaustion in massive file systems.

    .PARAMETER Ascii
        Compatibility mode. Strips all ANSI colors, emoji icons, and hyperlinks, rendering the tree with basic ASCII characters (+--, |).

    .PARAMETER NoColor
        Disables ANSI color output while retaining structure and icons.

    .PARAMETER NoIcon
        Removes folder (📁) and file (📄) emoji icons from the output.

    .PARAMETER NoLink
        Disables the generation of OSC 8 clickable hyperlinks for file paths.

    .PARAMETER Columns
        Enables a responsive multi-column layout based on the current width of the terminal window.

    .PARAMETER MaxColumnWidth
        Sets a hard cap on the width of a single column (Default: 50). This prevents a single, exceptionally long file path from collapsing the entire multi-column layout into a single column.

    .EXAMPLE
        Invoke-RichTree -Recurse
        Recursively displays the directory tree of the current location with default formatting.

    .EXAMPLE
        Invoke-RichTree -Grep "\.json$" -Invert
        Displays the tree in the current directory, completely hiding any file ending with ".json".

    .EXAMPLE
        Invoke-RichTree -Path C:\Logs -Columns -DirectoriesOnly -Depth 2
        Shows only the directory structure up to 2 levels deep inside "C:\Logs", rendering the output in a multi-column grid.

    .EXAMPLE
        Invoke-RichTree -Filter "*.txt" -Ascii | Out-File tree.txt
        Finds all text files, formats them using basic ASCII (no colors/links), and saves the tree structure directly to a text file.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Path = (Get-Location).Path,

        [Parameter(Mandatory = $False)]
        [string]$Filter = "*",

        [Parameter(Mandatory = $False)]
        [string[]]$Include,

        [Parameter(Mandatory = $False)]
        [string[]]$Exclude,

        [Parameter(Mandatory = $False)]
        [Alias('g')]
        [string]$Grep,

        [Parameter(Mandatory = $False)]
        [Alias('i', 'v')]
        [switch]$Invert,

        [switch]$ShowHidden,

        [Alias('dir')]
        [switch]$DirectoriesOnly,

        [Alias('r')]
        [switch]$Recurse,

        [Alias('dep')]
        [int]$Depth,

        [Alias('a')]
        [switch]$Ascii,

        [Alias('nc')]
        [switch]$NoColor,

        [Alias('ni')]
        [switch]$NoIcon,

        [Alias('nl')]
        [switch]$NoLink,

        [Alias('c', 'col')]
        [switch]$Columns,

        [int]$MaxColumnWidth = 50
    )

    # =========================================================================
    # 1. State Normalization & UI Configuration
    # =========================================================================

    # The 'Ascii' switch is an overarching compatibility toggle.
    # If enabled, we must strip all modern formatting to ensure safe output to text files or legacy consoles.
    if ($Ascii) { 
        $NoColor = $true 
        $NoIcon  = $true 
        $NoLink  = $true 
    }

    # Depth normalization: Ensure we have a valid integer constraint for the C# recursion.
    if ($Depth -le 0) { 
        $Depth = $Recurse ? [int]::MaxValue : 1 
    }
    
    # The C# interop requires scalar values. We flatten array inputs into CSV strings.
    # The C# engine will re-split these internally.
    $includePatternsCsv = ($Include -join ",")
    $excludePatternsCsv = ($Exclude -join ",")

    # ANSI color definitions (Reference: 256-color lookup table)
    # 39 = Bright Blue (Directories), 250 = Light Gray (Files)
    $ansiColorDir   = $NoColor ? "" : "`e[38;5;39m"
    $ansiColorFile  = $NoColor ? "" : "`e[38;5;250m"
    $ansiColorReset = $NoColor ? "" : "`e[0m"
    
    $iconDir  = $NoIcon ? "" : "📁 "
    $iconFile = $NoIcon ? "" : "📄 "

    # Define tree topology characters based on rendering mode
    $branchMiddle = $Ascii ? "+--" : "├──"
    $branchLast   = $Ascii ? "\--" : "└──"
    $verticalPipe = $Ascii ? "|  " : "│  "
    $indentSpace  = "    "

    # =========================================================================
    # 2. High-Performance C# Core Engine (Embedded)
    # 
    # Why embed C#?
    # PowerShell's native `Get-ChildItem` wraps every file in a heavy PSObject.
    # When traversing deeply nested structures (like node_modules), this causes
    # severe performance bottlenecks. Using native .NET classes via compiled C# 
    # executes in a fraction of the time.
    # =========================================================================
    
    $csharpSourceCode = @"
    using System;
    using System.IO;
    using System.Collections.Generic;
    using System.Linq;
    using System.Text.RegularExpressions;

    public static class RichTreeEngine {
        
        // Represents a logical node in our visual tree.
        // We build this in memory first to determine if branches should be drawn.
        private class FileNode {
            public FileSystemInfo Info;
            public List<FileNode> Children = new List<FileNode>();
            
            // IsDirectMatch: The item itself matches the user's search criteria.
            // ContainsMatch: A child or grandchild of this folder matches the criteria (keeps the branch alive).
            public bool IsDirectMatch;
            public bool ContainsMatch;
        }

        // Main entry point invoked by PowerShell
        public static List<string> RenderTree(
            string rootPath, int maxDepth, string filter, string includeCsv, string excludeCsv, 
            string grepPattern, bool invertGrep, bool showHidden, bool dirsOnly, bool enableLinks, 
            string colorDir, string colorFile, string colorReset,
            string iconDir, string iconFile, string branchMiddle, string branchLast, 
            string verticalPipe, string indentSpace)
        {
            var outputLines = new List<string>();
            var rootDirectory = new DirectoryInfo(rootPath);
            
            if (!rootDirectory.Exists) {
                return new List<string> { "Error: Target directory does not exist." };
            }

            // Parse comma-separated arguments back into usable arrays
            string[] includePatterns = string.IsNullOrEmpty(includeCsv) ? new string[0] : includeCsv.Split(',');
            string[] excludePatterns = string.IsNullOrEmpty(excludeCsv) ? new string[0] : excludeCsv.Split(',');
            
            // Compile Regex once for the entire traversal for performance
            Regex grepRegex = string.IsNullOrEmpty(grepPattern) ? null : new Regex(grepPattern, RegexOptions.IgnoreCase | RegexOptions.Compiled);
            
            // Phase 1: Scan disk and build the logical tree in memory
            FileNode rootNode = BuildTreeData(rootDirectory, 0, maxDepth, filter, includePatterns, excludePatterns, grepRegex, invertGrep, showHidden, dirsOnly);
            
            if (rootNode == null) {
                return outputLines; // No matches found
            }

            // Phase 2: Convert the logical tree into formatted strings
            string formattedRootName = FormatHyperlink(rootNode.Info.FullName, rootNode.Info.FullName, enableLinks);
            outputLines.Add($"{colorDir}{iconDir}{formattedRootName}{colorReset}");
            
            RenderNodeToLines(rootNode, "", enableLinks, colorDir, colorFile, colorReset, iconDir, iconFile, branchMiddle, branchLast, verticalPipe, indentSpace, outputLines);
            
            return outputLines;
        }

        private static FileNode BuildTreeData(DirectoryInfo currentDir, int currentDepth, int maxDepth, string filter, string[] includePatterns, string[] excludePatterns, Regex grepRegex, bool invertGrep, bool showHidden, bool dirsOnly) {
            var node = new FileNode { Info = currentDir };
            
            // A node matches if there is no grep pattern, OR if the grep match aligns with the invert flag logic
            bool isSelfMatch = (grepRegex == null) || (grepRegex.IsMatch(currentDir.Name) != invertGrep);
            if (isSelfMatch) {
                node.IsDirectMatch = true;
            }

            // Enforce recursion depth limit
            if (currentDepth >= maxDepth) {
                return node.IsDirectMatch ? node : null;
            }

            try {
                // Using EnumerateFileSystemInfos is lazy and highly memory-efficient compared to GetFileSystemInfos()
                foreach (var item in currentDir.EnumerateFileSystemInfos("*")) {
                    
                    // Skip hidden items unless explicitly requested
                    if (!showHidden && (item.Attributes & FileAttributes.Hidden) != 0) continue;
                    
                    // Apply explicit wildcard inclusion/exclusion
                    if (includePatterns.Length > 0 && !MatchesAnyPattern(item.Name, includePatterns)) continue;
                    if (excludePatterns.Length > 0 && MatchesAnyPattern(item.Name, excludePatterns)) continue;

                    if (item is DirectoryInfo subDirectory) {
                        FileNode childNode = BuildTreeData(subDirectory, currentDepth + 1, maxDepth, filter, includePatterns, excludePatterns, grepRegex, invertGrep, showHidden, dirsOnly);
                        if (childNode != null) { 
                            node.Children.Add(childNode); 
                            node.ContainsMatch = true; 
                        }
                    } else if (!dirsOnly) {
                        // Apply standard filter (e.g., "*.txt") to files
                        if (!IsSimpleWildcardMatch(item.Name, filter)) continue;
                        
                        bool isFileMatch = (grepRegex == null) || (grepRegex.IsMatch(item.Name) != invertGrep);
                        if (isFileMatch) {
                            node.Children.Add(new FileNode { Info = item, IsDirectMatch = true });
                            node.ContainsMatch = true;
                        }
                    }
                }
            } 
            catch (UnauthorizedAccessException) {
                // Gracefully ignore folders requiring elevated privileges
            }

            // Retain the folder only if it matches criteria itself, or serves as a path to a matching child.
            return (node.IsDirectMatch || node.ContainsMatch) ? node : null;
        }

        private static void RenderNodeToLines(FileNode parentNode, string currentPrefix, bool enableLinks, string colorDir, string colorFile, string colorReset, string iconDir, string iconFile, string branchMiddle, string branchLast, string verticalPipe, string indentSpace, List<string> outputLines) {
            
            // UX Rule: Always render folders first, then files, both sorted alphabetically.
            var sortedChildren = parentNode.Children
                .OrderByDescending(c => c.Info is DirectoryInfo)
                .ThenBy(c => c.Info.Name)
                .ToList();
            
            for (int i = 0; i < sortedChildren.Count; i++) {
                FileNode child = sortedChildren[i];
                bool isLastChild = (i == sortedChildren.Count - 1);
                
                // Determine branch topology (├── vs └──)
                string branchConnector = isLastChild ? branchLast : branchMiddle; 
                string formattedName = FormatHyperlink(child.Info.FullName, child.Info.Name, enableLinks);
                
                if (child.Info is DirectoryInfo) {
                    outputLines.Add($"{currentPrefix}{branchConnector}{colorDir}{iconDir}{formattedName}{colorReset}");
                    
                    // Calculate prefix for the next depth level
                    string nextPrefix = currentPrefix + (isLastChild ? indentSpace : verticalPipe);
                    RenderNodeToLines(child, nextPrefix, enableLinks, colorDir, colorFile, colorReset, iconDir, iconFile, branchMiddle, branchLast, verticalPipe, indentSpace, outputLines);
                } else {
                    outputLines.Add($"{currentPrefix}{branchConnector}{colorFile}{iconFile}{formattedName}{colorReset}");
                }
            }
        }

        // Generates an OSC 8 terminal hyperlink sequence
        // Format: \e]8;;file:///Path/To/File\e\DisplayText\e]8;;\e\
        private static string FormatHyperlink(string absolutePath, string displayText, bool enableLinks) {
            if (!enableLinks) return displayText;
            
            string fileUri = absolutePath.Replace('\\', '/');
            return $"\u001b]8;;file:///{fileUri}\u001b\\{displayText}\u001b]8;;\u001b\\";
        }
        
        // Helper: Translates simple file wildcards (*, ?) into Regex for matching
        private static bool IsSimpleWildcardMatch(string fileName, string filter) {
            return string.IsNullOrEmpty(filter) || filter == "*" || MatchesAnyPattern(fileName, new[] { filter });
        }

        private static bool MatchesAnyPattern(string input, string[] wildcardPatterns) {
            return wildcardPatterns.Any(pattern => {
                string regexPattern = "^" + Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".") + "$";
                return Regex.IsMatch(input, regexPattern, RegexOptions.IgnoreCase);
            });
        }
    }
"@

    # Compile the C# engine into the session.
    # We check if the type exists first to avoid compilation errors on subsequent runs within the same session.
    if (-not ([System.Management.Automation.PSTypeName]'RichTreeEngine').Type) {
        Add-Type -TypeDefinition $csharpSourceCode -Language CSharp
    }

    # =========================================================================
    # 3. Execution & Tiling Layout Engine
    # =========================================================================

    # Resolve relative paths to absolute paths to ensure OSC 8 links function correctly
    $absoluteRootPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path
    
    # Execute the C# rendering engine
    $renderedLines = [RichTreeEngine]::RenderTree(
        $absoluteRootPath, $Depth, $Filter, $includePatternsCsv, $excludePatternsCsv, 
        $Grep, $Invert.IsPresent, $ShowHidden.IsPresent, $DirectoriesOnly.IsPresent, (-not $NoLink.IsPresent), 
        $ansiColorDir, $ansiColorFile, $ansiColorReset, $iconDir, $iconFile, 
        $branchMiddle, $branchLast, $verticalPipe, $indentSpace
    )

    # Fast-exit if standard (non-column) output is requested or no files were found
    if (-not $Columns -or $renderedLines.Count -eq 0) {
        $renderedLines
        return
    }

    # --- Columnar Calculation Logic ---

    # PERFORMANCE CRITICAL: 
    # Pre-compile regular expressions used for calculating visual widths. 
    # Doing this outside the loop prevents redundant regex parsing for every line.
    $script:ansiEscapeRegex = [regex]::new('\e\[[0-9;]*m|\e\]8;;.*?\e\\|\e\]8;;\e\\', [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $script:cjkCharacterRegex = [regex]::new('[\u2e80-\u9fff\uff00-\uffef]', [System.Text.RegularExpressions.RegexOptions]::Compiled)
    
    # Helper: Calculates the true visual space a string occupies in the terminal
    function Get-VisualWidth([string]$text) {
        # 1. Strip all formatting codes that take up 0 visual space
        $plainText = $script:ansiEscapeRegex.Replace($text, '')
        
        # 2. Count Full-width CJK characters. 
        # Why? Asian characters typically occupy 2 terminal character columns instead of 1.
        $doubleWidthCharCount = $script:cjkCharacterRegex.Matches($plainText).Count
        
        return $plainText.Length + $doubleWidthCharCount
    }

    # Safely acquire terminal width. Defaults to 80 if running headless.
    $terminalWidth = try { [Console]::WindowWidth } catch { 80 }
    
    # Pass 1: Scan all lines to find the maximum required width for a single column cell
    $maxVisualWidth = 0
    foreach ($line in $renderedLines) {
        $lineWidth = Get-VisualWidth -text $line
        if ($lineWidth -gt $maxVisualWidth) { 
            $maxVisualWidth = $lineWidth 
        }
    }
    
    # Calculate grid constraints. Ensure we don't exceed the user's max column width limit.
    $targetColumnWidth = [Math]::Min($maxVisualWidth + 2, $MaxColumnWidth)
    
    # Calculate matrix dimensions
    $numberOfColumns = [Math]::Max(1, [Math]::Floor($terminalWidth / $targetColumnWidth))
    $numberOfRows    = [Math]::Ceiling($renderedLines.Count / $numberOfColumns)

    # Pass 2: Iterate through the grid matrix and render padded rows
    for ($rowIndex = 0; $rowIndex -lt $numberOfRows; $rowIndex++) {
        $currentRowString = ""
        
        for ($colIndex = 0; $colIndex -lt $numberOfColumns; $colIndex++) {
            # Calculate the 1D array index from 2D coordinates
            $dataIndex = $rowIndex + ($colIndex * $numberOfRows)
            
            if ($dataIndex -lt $renderedLines.Count) {
                $lineContent = $renderedLines[$dataIndex]
                $actualVisualWidth = Get-VisualWidth -text $lineContent
                
                # Append blank spaces to align the start of the next column perfectly
                $paddingSpaces = " " * [Math]::Max(0, ($targetColumnWidth - $actualVisualWidth))
                $currentRowString += $lineContent + $paddingSpaces
            }
        }
        # Output the constructed row to the console
        $currentRowString
    }
}

# set alias
# This block automatically sets an alias for the function upon script load.
[String] $tmpAliasName = "lst"
[String] $tmpCmdName = "Invoke-RichTree"

# Get the script's own path to inform the user if an alias conflict occurs.
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative

# Convert script path to Unix-style for display clarity if on Windows.
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }

# Check if an alias with the desired name already exists.
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        # If the existing command is an alias and refers to this function, just re-set it.
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName) (updated)" -ForegroundColor Green # Indicate alias was updated
                    }
            } else {
                # Alias exists but points to a different command; throw error.
                throw
            }
        # If the existing command is an executable (e.g., gitbash.exe), allow overriding with this alias.
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName) (overriding existing executable)" -ForegroundColor Yellow # Indicate override
                }
        } else {
            # Any other type of command conflict; throw error.
            throw
        }
    } catch {
        # Inform the user about the alias conflict and where to resolve it.
        Write-Error "Alias ""$tmpAliasName"" is already in use by ""$((Get-Command -Name $tmpAliasName).ReferencedCommand.Name)"" or another command. Please change the alias name in the script: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        # Clean up temporary variables regardless of success or failure.
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    # If no alias exists, create it.
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName) (created)" -ForegroundColor Green # Confirm alias creation
        }
    # Clean up temporary variables.
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
