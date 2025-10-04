function Convert-Uri2Html {
    <#
    .SYNOPSIS
    Convert-Uri2Html (Alias: uri2html) -- Converts a list of URIs into a structured HTML file.
    
    # =================================================================================
    # Function: Convert-Uri2Html
    #
    # Purpose:  This function provides a streamlined way to create an HTML log file
    #           from a list of URIs. It's designed for quick, interactive use,
    #           automatically reading from the clipboard and saving to a default
    #           directory, while also supporting advanced features for customization.
    # =================================================================================

    .DESCRIPTION
    This function generates an HTML file containing a list of hyperlinks from provided URIs.
    If no URIs are specified via the -Uri parameter or pipeline, the function automatically reads them from the clipboard.
    If the output path is not specified, the HTML file is saved to a default session directory for easy management.

    Key features include:
    - Fetching Open Graph (OGP) titles to create descriptive links.
    - Adding textarea fields for user comments next to each link.
    - Appending URIs to an existing HTML file instead of overwriting.
    - Client-side JavaScript for saving and loading comments.

    .PARAMETER Uri
    An array of string URIs to be included in the HTML log.
    This parameter accepts input from the pipeline. If omitted, the function will attempt to read URIs from the system clipboard.

    .PARAMETER OutputHtml
    The file path for the output HTML file.
    If not specified, a default path is generated based on the SessionName in a standard directory (e.g., "$HOME/.pwsh-sessions/html").

    .PARAMETER SessionName
    A unique name for the session, used to generate the default filename and for identifying comments in browser storage.
    Defaults to a timestamped name like "session_yyyyMMdd_HHmmss".

    .PARAMETER Lang
    Specifies the language attribute for the HTML tag. Defaults to "en".

    .PARAMETER NoComment
    A switch parameter. If present, a <textarea> will be added next to each URI for comments.

    .PARAMETER ListStyle
    The HTML list tag to use for formatting the URIs. Can be "ol" (ordered list) or "ul" (unordered list). Defaults to "ol".

    .PARAMETER AddTitle
    A switch parameter. If present, the function will attempt to fetch the Open Graph (OGP) title for each URL to use as the link text.
    Note: This requires the Get-OGP function to be available and can increase execution time.

    .PARAMETER OverWrite
    A switch parameter. If present, forces the creation of a new HTML file, overwriting any existing file at the same path.
    By default, the function appends to existing files.
    
    .EXAMPLE
    # Scenario: Quickly save links from the clipboard.
    # 1. Copy one or more URLs to the clipboard.
    # 2. Run the command without any parameters.
    Convert-Uri2Html
    # Result: A new HTML file with a timestamped name is created in the default directory.

    .EXAMPLE
    # Create an HTML log with page titles and a custom session name.
    Convert-Uri2Html -SessionName "MyResearch" -AddTitle
    # Result: Creates "MyResearch.html" in the default directory, with links displaying their web page titles.

    .EXAMPLE
    # Append new clipboard links to an existing session file, including comment boxes.
    Convert-Uri2Html -SessionName "MyResearch" -Comment
    
    .EXAMPLE
    # Use a pipeline to process URLs and specify a custom output file.
    "https://learn.microsoft.com/powershell", "https://github.com" | Convert-Uri2Html -OutputHtml "./custom-links.html" -OverWrite
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [Alias('u')]
        [string[]]$Uri,

        [Parameter(Mandatory=$false)]
        [Alias('o')]
        [string]$OutputHtml,

        [Parameter(Mandatory=$false)]
        [Alias('n','name')]
        [string]$SessionName,

        [Parameter(Mandatory=$false)]
        [Alias('l')]
        [string]$Lang = "en",

        [Parameter(Mandatory=$false)]
        [switch]$NoComment,

        [Parameter(Mandatory=$false)]
        [Alias('dir')]
        [switch]$Directory,

        [Parameter(Mandatory=$false)]
        [Alias('style')]
        [string]$ListStyle = "ol",

        [Parameter(Mandatory=$false)]
        [Alias('t','title')]
        [switch]$AddTitle,

        [Parameter(Mandatory=$false)]
        [switch]$OverWrite
    )

    #region Initialization and Parameter Handling
    begin {
        # --- Determine Default Storage Directory ---
        # This logic is inspired by the 'Save-Session' function to provide a consistent
        # storage location for related session files.
        $defaultOutputDir = Join-Path $HOME ".pwsh-sessions"
        $cmsOutputDir     = Join-Path $HOME "cms/session"

        if (Test-Path -LiteralPath $cmsOutputDir) {
            $outputDir = $cmsOutputDir
        } else {
            $outputDir = $defaultOutputDir
        }

        if ( $Directory ) {
            Invoke-Item -LiteralPath $outputDir
            return
        }

        # Create a dedicated 'html' subdirectory to avoid mixing with other file types (e.g., JSON).
        if (-not (Test-Path -LiteralPath $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
        }
        
        # --- Set Default SessionName and OutputHtml Path ---
        # If a session name isn't provided, create a unique, timestamped one.
        if (-not $PSBoundParameters.ContainsKey('SessionName')) {
            $SessionName = "session_" + (Get-Date -Format "yyyyMMdd")
        }

        # If an output path isn't specified, build one using the determined directory and session name.
        if (-not $PSBoundParameters.ContainsKey('OutputHtml')) {
            $OutputHtml = Join-Path $outputDir "$SessionName.html"
        }
        
        # --- Read from Clipboard if No URI is Provided ---
        # To improve interactive usability, this is the default behavior. It allows
        # the user to simply run `Convert-Uri2Html` after copying URLs.
        if (-not $PSBoundParameters.ContainsKey('Uri')) {
            Write-Verbose "No -Uri parameter specified. Reading from clipboard."
            [string[]]$Uri = Get-Clipboard -Raw `
                | ForEach-Object { $_ -split "`r*`n" } `
                | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } `
                | ForEach-Object { $_.Trim() }
        }
        
        # Initialize a collection to hold processed URI objects.
        [PSCustomObject[]]$urlObjects = @()
    }
    #endregion

    #region Process URIs
    process {
        foreach ($u in $Uri) {
            if (-not [string]::IsNullOrWhiteSpace($u)) {
                # Process only valid web URLs. This avoids errors with non-URL clipboard content.
                if ($u -match '^https?://') {
                    $trimmedUri = $u.Trim()

                    # If requested, attempt to fetch the OGP title for a more descriptive link.
                    if ($AddTitle) {
                        try {
                            # Assumes a 'Get-OGP' function is available in the environment.
                            $ogp = Get-OGP -Uri $trimmedUri -Raw
                            $urlObjects += [PSCustomObject]@{ Title = $ogp[0]; Uri = $ogp[1] }
                        } catch {
                            # Gracefully handle failures (e.g., network errors, 404s, no OGP data).
                            # Fall back to using the URI itself as the title to ensure it's still added.
                            Write-Warning "Failed to fetch Open Graph data for '$trimmedUri'. Defaulting to URI. Error: $_"
                            $urlObjects += [PSCustomObject]@{ Title = $trimmedUri; Uri = $trimmedUri }
                        }
                    } else {
                        # If not fetching titles, the URI serves as both title and link.
                        $urlObjects += [PSCustomObject]@{ Title = $trimmedUri; Uri = $trimmedUri }
                    }
                } else {
                    Write-Warning "Skipping invalid or non-HTTP/S URL: $u"
                }
            }
        }
    }
    #endregion

    #region Finalize and Generate HTML
    end {
        # Abort if no valid URLs were found, preventing the creation of an empty file.
        if ($urlObjects.Count -eq 0) {
            # Use Write-Error instead of 'throw' to avoid halting a larger script's execution.
            Write-Error "No valid URLs were provided or found on the clipboard."
            return
        }

        # --- Build HTML Snippet for New Items ---
        $newItemsHtml = ""
        foreach ($obj in @($urlObjects | Get-Unique) ) {
            # If a title was fetched and it's different from the URI, display both for clarity.
            if (-not $AddTitle -or $obj.Uri -eq $obj.Title) {
                $newItemsHtml += "<li><a href='$($obj.Uri)' target='_blank'>$($obj.Title)</a><br>"
            } else {
                $newItemsHtml += "<li><a href='$($obj.Uri)' target='_blank'>$($obj.Title)</a><br>"
                $newItemsHtml += "<a href='$($obj.Uri)' target='_blank'>$($obj.Uri)</a><br>"
            }

            if ( -not $NoComment) {
                $newItemsHtml += "<textarea placeholder='Enter comment'></textarea></li>`n"
            } else {
                $newItemsHtml += "</li>`n"
            }
        }

        # --- Write to HTML File (Append or Create New) ---
        if ((Test-Path -LiteralPath $OutputHtml) -and -not $OverWrite) {
            # --- Append Mode ---
            # To properly append, we insert new items into the existing list
            # rather than just adding them to the end of the file.
            $lines = Get-Content -LiteralPath $OutputHtml

            # Find the closing list tag (e.g., </ol>) to determine the insertion point.
            $closingIndex = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "</$ListStyle>") {
                    $closingIndex = $i
                    break
                }
            }

            if ($closingIndex -ge 0) {
                # Reconstruct the file with the new items inserted before the closing tag.
                $before = $lines[0..($closingIndex - 1)]
                $after  = $lines[$closingIndex..($lines.Count - 1)]
                $newLines = $before + $newItemsHtml + $after
                $newLines | Set-Content -Encoding UTF8 $OutputHtml
            } else {
                # Fallback if the closing tag isn't found, though this is unexpected in a valid file.
                Write-Warning "Closing </$ListStyle> tag not found. Appending items at the end of the file."
                Add-Content -LiteralPath $OutputHtml -Value $newItemsHtml
            }

        } else {
            # --- Create New File Mode ---
            # The 'here-string' (@" "@) provides a clean template for the new HTML document.
            $html = @"
<!DOCTYPE html>
<html lang='$Lang'>
<head>
<meta charset='UTF-8'>
<title>Session Log - $SessionName</title>
<style>
body { font-family: Arial, sans-serif; margin: 20px; }
h1 { color: #2E8B57; }
$ListStyle { }
li { margin-bottom: 10px; }
a { text-decoration: none; color: #1E90FF; }
a:hover { text-decoration: underline; }
textarea { width: 90%; height: 40px; margin-top: 3px; }
button { margin-top: 10px; padding: 5px 10px; font-size: 14px; }
</style>
</head>
<body>
<h1>Session Log: $SessionName</h1>
<p>Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
<$ListStyle>
$newItemsHtml
</$ListStyle>
"@

            # --- Embed JavaScript for Comment Handling ---
            # This script provides client-side features for a better user experience without
            # requiring a server backend.
            if ( -not $NoComment) {
$html += @"

<button id='saveCommentsBtn'>Save Comments</button>
<button id='loadCommentsBtn'>Load Comments</button>
<input type='file' id='loadFileInput' style='display:none' />

<script>
// Use localStorage for auto-saving comments, providing persistence across page reloads.
document.querySelectorAll('textarea').forEach((ta, idx) => {
    const key = 'comment_$SessionName_' + idx;
    ta.value = localStorage.getItem(key) || '';
    ta.addEventListener('input', () => localStorage.setItem(key, ta.value));
});

// Implement file-based save to allow users to back up and share their comments.
document.getElementById('saveCommentsBtn').addEventListener('click', () => {
    const data = Array.from(document.querySelectorAll('textarea')).map((ta, idx) => ({
        index: idx,
        comment: ta.value
    }));
    const blob = new Blob([JSON.stringify(data, null, 2)], {type: 'application/json'});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = '$SessionName.json';
    a.click();
    URL.revokeObjectURL(url);
});

// Implement file-based load to restore comments from a backup.
document.getElementById('loadCommentsBtn').addEventListener('click', () => {
    document.getElementById('loadFileInput').click();
});

document.getElementById('loadFileInput').addEventListener('change', function(event) {
    const file = event.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function(e) {
        try {
            const data = JSON.parse(e.target.result);
            data.forEach((item, idx) => {
                const ta = document.querySelectorAll('textarea')[idx];
                if (ta && item.comment !== undefined) {
                    ta.value = item.comment;
                    // Also update localStorage when loading from a file.
                    localStorage.setItem('comment_$SessionName_' + idx, item.comment);
                }
            });
            alert('Comments loaded successfully!');
        } catch (err) {
            alert('Failed to load JSON: ' + err);
        }
    };
    reader.readAsText(file);
});
</script>
"@
            }

            # Close the HTML document structure.
            $html += @"

</body>
</html>
"@

            # Write the complete HTML string to the file.
            $html | Set-Content -Encoding UTF8 $OutputHtml
        }

        # --- Output File Information ---
        # Provide confirmation to the user about where the file was saved.
        #Write-Output "HTML file saved to: $($OutputHtml)"
        Get-Item -LiteralPath $OutputHtml
    }
    #endregion
}
# set alias
[String] $tmpAliasName = "uri2html"
[String] $tmpCmdName   = "Convert-Uri2Html"
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
