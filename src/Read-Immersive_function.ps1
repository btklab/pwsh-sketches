function Read-Immersive {
    <#
    .SYNOPSIS
        Read-Immersive (Alias: reader) - Open web pages in "immersive reader" mode 
        across different browsers (Edge, Firefox, Chrome, Safari).
    
    .DESCRIPTION
        This function takes one or more URIs and opens them using 
        the most immersive reading experience available in the chosen browser.
    
        Supported browsers:
          - Microsoft Edge: Opens using the "read:" protocol (Immersive Reader)
          - Firefox: Opens using "about:reader?url=" syntax (Reader View)
          - Chrome / Safari: Opens the normal page; user must manually 
            enable Reader Mode (no public scheme available)
    
        Input sources:
          - Pipeline
          - Function argument(s)
          - Clipboard (default if no input provided)
    
        Behavior:
          - Automatically skips invalid or non-URL text lines
          - If no argument or pipeline input is provided, reads from clipboard
          - Auto-adds "https://" if scheme is missing
    
    .EXAMPLE
        Read-Immersive "https://example.com" -Browser Edge
    
        Opens the page directly in Microsoft Edge Immersive Reader mode.
    
    .EXAMPLE
        Get-Content .\urls.txt | Read-Immersive -Browser Firefox
    
        Opens all valid URLs from the text file in Firefox's Reader View.
        Invalid lines are automatically skipped.
    
    .EXAMPLE
        Read-Immersive
    
        Reads the clipboard text and opens any valid URLs 
        in the default Edge Immersive Reader mode.
    
    .NOTES
        Author: btklab
        Philosophy: Follows the principles of "Readable Code" — 
                    each step should reveal intent clearly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet('Edge','Firefox','Chrome','Safari','Default')]
        [Alias('b')]
        [string]$Browser = 'Edge',
        
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias('u')]
        [string[]]$Uri
    )

    begin {
        # Initialize storage for all URIs to process
        [string[]] $uris = @()
    }

    process {
        # --- Step 1: Collect input from all possible sources ---
        if ($Uri) {
            $uris += $Uri
        }
    }

    end {
        # --- Step 2: Fallback to clipboard if no URIs provided ---
        if (-not $uris -or $uris.Count -eq 0) {
            try {
                $clip = Get-Clipboard -Raw -ErrorAction Stop
                if ($clip) {
                    # Split clipboard text by newlines, trim, and collect
                    $uris = $clip -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    Write-Verbose "Read $($uris.Count) line(s) from clipboard."
                }
            } catch {
                Write-Error "Failed to read clipboard: $_"
                return
            }
        }

        # --- Step 3: Validate and filter URIs ---
        $validUris = @()
        foreach ($line in $uris) {
            # Skip empty or non-URL lines
            if ($line -match '^(https?:\/\/|www\.)') {
                # Add https:// if missing scheme
                if ($line -notmatch '^[a-zA-Z][a-zA-Z0-9+\-.]*:') {
                    $line = "https://$line"
                }
                $validUris += $line
            } else {
                Write-Verbose "Skipping invalid or non-URL line: '$line'"
            }
        }

        if ($validUris.Count -eq 0) {
            Write-Verbose "No valid URLs found in input."
            return
        }

        # --- Step 4: Open each URI in the selected browser ---
        foreach ($u in $validUris) {

            switch ($Browser) {

                'Edge' {
                    # Microsoft Edge Immersive Reader: prefix "read:"
                    $target = if ($u -like 'read:*') { $u } else { "read:$u" }
                    Write-Verbose "Opening Edge Immersive Reader: $target"

                    if ($IsWindows) {
                        Start-Process -FilePath 'msedge' -ArgumentList $target -ErrorAction SilentlyContinue
                    } elseif ($IsMacOS) {
                        Start-Process -FilePath 'open' -ArgumentList '-a','Microsoft Edge',$target -ErrorAction SilentlyContinue
                    } else {
                        Start-Process $target -ErrorAction SilentlyContinue
                    }
                }

                'Firefox' {
                    # Firefox Reader View: about:reader?url=<encoded>
                    $enc = [System.Uri]::EscapeDataString($u)
                    $target = "about:reader?url=$enc"
                    Write-Verbose "Opening Firefox Reader View: $target"

                    if ($IsWindows) {
                        Start-Process -FilePath 'firefox' -ArgumentList $target -ErrorAction SilentlyContinue
                    } elseif ($IsMacOS) {
                        Start-Process -FilePath 'open' -ArgumentList '-a','Firefox',$target -ErrorAction SilentlyContinue
                    } else {
                        Start-Process $target -ErrorAction SilentlyContinue
                    }
                }

                'Chrome' {
                    # Chrome does not provide a Reader Mode URL scheme
                    # Open normally; user can manually activate Reader Mode
                    Write-Verbose "Opening Chrome (manual reader mode): $u"
                    if ($IsWindows) {
                        Start-Process -FilePath 'chrome' -ArgumentList $u -ErrorAction SilentlyContinue
                    } elseif ($IsMacOS) {
                        Start-Process -FilePath 'open' -ArgumentList '-a','Google Chrome',$u -ErrorAction SilentlyContinue
                    } else {
                        Start-Process $u -ErrorAction SilentlyContinue
                    }
                }

                'Safari' {
                    # Safari Reader Mode cannot be triggered by URL;
                    # open the page and rely on manual Reader activation
                    Write-Verbose "Opening Safari (manual reader mode): $u"
                    if ($IsMacOS) {
                        Start-Process -FilePath 'open' -ArgumentList '-a','Safari',$u -ErrorAction SilentlyContinue
                    } else {
                        Write-Warning "Safari is supported on macOS only."
                    }
                }

                'Default' {
                    # Fallback: Let system choose the default browser
                    Write-Verbose "Opening default browser: $u"
                    Start-Process -FilePath $u -ErrorAction SilentlyContinue
                }
            }
        }

        # --- Step 5: Summary feedback ---
        Write-Host "Opened $($validUris.Count) page(s) in $Browser mode." -ForegroundColor Green
    }
}

# set alias
[String] $tmpAliasName = "reader"
[String] $tmpCmdName   = "Read-Immersive"
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

