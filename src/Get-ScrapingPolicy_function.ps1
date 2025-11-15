<#
.SYNOPSIS
    Get-ScrapingPolicy - Website Scraping Policy Indicator Tool.

    Checks key technical and structural indicators of a website's policy regarding automated access (scraping) by analyzing
    the existence and content of robots.txt (including Disallow rules and Crawl-delay), the dynamic discovery of Terms of
    Service (ToS) links from the homepage HTML, and technical rate-limiting response headers. The output of specific
    disallowed paths in robots.txt is optional and controlled by a switch.

    It can process multiple URIs provided as arguments, through the
    pipeline, or from the clipboard. If no URI is provided, it
    attempts to read URIs from the clipboard (one URI per line).

    DISCLAIMER: This tool provides *indicators only*. The final decision on scraping legality and
    policy adherence must be made manually by legal or operations personnel after reviewing the full Terms of Service.

.DESCRIPTION
    The function processes one or more URLs, automatically truncating them to their root directory (scheme and hostname,
    e.g., https://github.com/btklab becomes https://github.com/). It then performs three main checks:
    1.  Robots.txt Analysis: Determines if the file exists, checks for broad "Disallow: /" directives, extracts specific
        disallowed paths, and notes any requested Crawl-delay.
    2.  Policy Link Discovery: Fetches the base URI and parses the HTML to search for anchor tags containing keywords
        like 'term', 'privacy', or 'legal' to locate the specific policy link.
    3.  Technical Hints & Status: Sends a HEAD request to the base URI, captures the HTTP status code (even on failure),
        and inspects response headers for server identity and rate-limiting indicators (e.g., X-RateLimit).

    The property 'RobotsTxtDisallowedPaths' is excluded from the default output for brevity, but can be included
    using the -IncludeDisallowedPaths switch.

    Input URLs can be provided via the pipeline or directly as arguments. The output is a collection of
    custom objects suitable for bulk review or export.

.PARAMETER Uri
    One or more strings representing the base URI (e.g., 'https://www.example.com' or 'https://www.example.com/subpath').
    The function automatically truncates the URI to its root directory (scheme and hostname) for checking.
    Can accept input from the pipeline.

.EXAMPLE
    # Simple usage with clipboard input
    ("Copy uri to clipboard first")
    Get-ScrapingPolicy

.EXAMPLE
    # Check a single website, automatically truncating the URL to its root.
    Get-ScrapingPolicy -Uri "https://github.com/btklab" | Format-List
    # The check will be performed against 'https://github.com/'

.EXAMPLE
    # Check multiple websites using a list and identify sites with a Crawl-Delay
    $Sites = @("https://www.example.org", "https://news.ycombinator.com")
    $Sites | Get-ScrapingPolicy

.EXAMPLE
    # Check URLs piped from a text file (one URL per line)
    Get-Content ".\target_sites.txt" | Get-ScrapingPolicy | Export-Csv -Path 'ScrapeAudit.csv'

.EXAMPLE
    # Check multiple URIs stored in the clipboard (URI per line) by running without arguments.
    Get-ScrapingPolicy

.NOTES
    The function uses a custom User-Agent and a mandatory 1-second delay per site to prevent accidental rate-limiting
    or server overload during the check process.

.LINK
    Get-OGP (ml), Get-ClipboardAlternative (gclipa),
    clip2file, clip2push, clip2shortcut,
    clip2img, clip2txt, clip2normalize,
    Get-ScrapingPolicy
#>
function Get-ScrapingPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$Uri,
        
        [Parameter(Mandatory=$false)]
        [switch]$Notice
    )

    begin {
        # Define a custom User-Agent to clearly identify the tool during checks.
        $userAgent = "ScrapingPolicy-Check-Bot/1.0 (Contact: Security@Example.com)"
        
        # Define comprehensive keywords for policy link discovery (Link innerText, ID, or Class attributes).
        # This regex is case-insensitive.
        $policyKeywords = '(?i)term|service|legal|privacy|use|policy|conditions|rules|imprint|disclaimer'
    }

    process {
        # If no URI is provided via parameter or pipeline (e.g., standalone execution),
        # read from the clipboard.
        if (-not $PSBoundParameters.ContainsKey('Uri')) {
            [string[]] $Uri = Get-Clipboard -Raw `
                | ForEach-Object { $_ -split "`r*`n" } `
                | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }

        # --- URI Processing Logic (Handle Pipeline Input) ---
        # Prepare an array to correctly process all URIs.
        $urisToIterate = @()

        if ($Uri) {
            # Handle cases where a single, multiline string is piped (e.g., from Get-Content -Raw).
            # $Uri is [string[]], so a single multiline string will have $Uri.Count -eq 1.
            if ($Uri.Count -eq 1 -and $Uri[0] -match "`n") {
                Write-Verbose "Detected potential multiline input in pipeline. Splitting content."
                $urisToIterate = $Uri[0] -split "`r*`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            } else {
                # Use URIs passed individually via arguments or standard pipeline (one string per object).
                $urisToIterate = $Uri
            }
        }
        # --------------------------------------------------

        foreach ($inputUri in $urisToIterate) {
            # Standardize and validate the base URI.
            $inputUri = $inputUri.Trim().TrimEnd('/')
            if (-not ($inputUri -like "http*://*")) {
                $inputUri = "https://$inputUri"
            }
            
            # --- LOGIC: TRUNCATE TO ROOT PATH (Scheme://Host) ---
            try {
                $uriObject = [uri]$inputUri
                # GetLeftPart('Scheme') includes the '://' separator.
                $baseUri = $uriObject.GetLeftPart('Scheme') + $uriObject.Host
            } catch {
                Write-Error "Invalid URI provided: '$inputUri'. Skipping."
                continue
            }
            # --------------------------------------------------------

            # Wait briefly to be respectful to the target server, especially in a loop.
            Start-Sleep -Seconds 1
            
            Write-Verbose "Checking indicators for: $baseUri (from input: $inputUri)"
            
            # Initialize the result object properties.
            $robotsInfo = @{
                Exists = $false
                DisallowForAll = $false
                DisallowedPaths = @()
                CrawlDelay = $null
            }
            $tosLink = $null
            $sampleStatus = $null
            $sampleHeaders = @{}
            $rateLimitFound = $false
            $rateLimitValue = ""
            
            # ------------------------------------------------------------------
            # 1. ROBOTS.TXT CHECK & PARSING
            # ------------------------------------------------------------------
            $robotsUri = "$baseUri/robots.txt"
            Write-Verbose "1. Checking robots.txt at: $robotsUri"
            try {
                # Use UseBasicParsing for speed and consistency, stop on error.
                $robotsReq = Invoke-WebRequest -Uri $robotsUri -Method Get -MaximumRedirection 0 -UserAgent $userAgent -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
                
                if ($robotsReq.StatusCode -eq 200) {
                    $robotsInfo.Exists = $true
                    $content = $robotsReq.Content
                    
                    # Normalize line endings, trim, and remove empty lines or comments.
                    $lines = $content -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and -not $_.StartsWith('#') }

                    $currentAgents = @()
                    foreach ($line in $lines) {
                        if ($line -match '^(?i)User-agent:\s*(.+)$') {
                            $raw = $Matches[1].Trim()
                            # A User-agent line can define multiple agents, comma or space-separated.
                            $currentAgents = ($raw -split '[,\s]+' | ForEach-Object { $_.ToLower().Trim() } | Where-Object { $_ -ne "" })
                            continue
                        }
                        
                        # Only process directives if we are inside a User-agent block.
                        if ($currentAgents.Count -gt 0) {
                            # Check if the current rule block applies to all agents ('*') or a specific (example) bot name.
                            $agentApplies = ($currentAgents -contains '*') -or ($currentAgents -contains 'yourbotname')

                            if ($agentApplies) {
                                if ($line -match '^(?i)Disallow:\s*(.*)$') {
                                    $v = $Matches[1].Trim()
                                    if ($v -eq "/") { $robotsInfo.DisallowForAll = $true }
                                    if ($v -ne "") { $robotsInfo.DisallowedPaths += $v }
                                }
                                if ($line -match '^(?i)Crawl-delay:\s*([0-9\.]+)'.Trim()) { # Allow for decimal
                                    # We cast to [int] later, but match allows for non-integer values seen in the wild.
                                    $robotsInfo.CrawlDelay = [int]$Matches[1]
                                }
                            }
                        }
                    }
                }
            } catch {
                # 404 Not Found is typical if the file doesn't exist.
                # Other errors (e.g., 503, 403) are caught and we proceed, assuming no robots.txt info.
                Write-Verbose "Robots.txt not found or inaccessible at $robotsUri"
            }
            
            # ------------------------------------------------------------------
            # 2. POLICY LINK DISCOVERY (HTML PARSING - ENHANCED)
            # ------------------------------------------------------------------
            Write-Verbose "2. Attempting to find policy link on homepage (Enhanced Search)..."
            try {
                # Fetch homepage to parse links
                $homeReq = Invoke-WebRequest -Uri $baseUri -UseBasicParsing -Method Get -MaximumRedirection 5 -UserAgent $userAgent -ErrorAction Stop -TimeoutSec 10
                
                # ENHANCEMENT: Search <a> elements where href exists AND 
                # InnerText OR id OR class contains policy keywords.
                $anchors = ($homeReq.Links | Where-Object { 
                    $_.href -and 
                    $_.href -ne '#' -and  # Exclude simple '#' anchor links
                    -not ($_.href -match '(?i)^javascript:') -and # Exclude JavaScript pseudo-links
                    (
                        $_.innerText -match $policyKeywords -or
                        $_.id -match $policyKeywords -or
                        $_.class -match $policyKeywords
                    )
                }) 

                if ($anchors -and $anchors.Count -gt 0) {
                    # Get the href of the first match
                    $tosLink = ($anchors[0].href -as [string])
                    
                    # Make relative URLs absolute
                    if ($tosLink -notmatch '^https?://') {
                        # Resolve the relative URL against the base response URI (which accounts for redirects)
                        $tosLink = ([uri] (New-Object System.Uri($homeReq.BaseResponse.ResponseUri, $tosLink))).AbsoluteUri
                    }
                }
            } catch {
                # Ignore errors during HTML fetching/parsing.
                Write-Verbose "Failed to fetch or parse homepage at $baseUri"
            }

            # ------------------------------------------------------------------
            # 3. TECHNICAL HEADERS & STATUS (WAF/BLOCK HINT)
            # ------------------------------------------------------------------
            Write-Verbose "3. Analyzing technical headers..."
            try {
                # Use HEAD request for speed; avoids downloading the body.
                $sampleResp = Invoke-WebRequest -Uri $baseUri -Method Head -MaximumRedirection 5 -UserAgent $userAgent -ErrorAction Stop -TimeoutSec 10
                $sampleHeaders = $sampleResp.Headers
                $sampleStatus = $sampleResp.StatusCode
            } catch {
                # Robustly capture status code and headers if the request failed (e.g., 403, 429)
                # This is critical for detecting blocking.
                if ($_.Exception.Response) {
                    try { $sampleStatus = [int]$_.Exception.Response.StatusCode } catch {}
                    try { $sampleHeaders = $_.Exception.Response.Headers } catch {}
                    Write-Verbose "Captured error response status: $sampleStatus"
                }
            }
            
            # Check for common Rate-Limit headers using captured headers
            $rateLimitKeys = @("X-RateLimit-Limit", "RateLimit-Limit", "Retry-After")
            if ($sampleHeaders) {
                $headerKeys = $sampleHeaders.Keys
                foreach ($key in $rateLimitKeys) {
                    # Use the -contains operator on the .Keys property for robustness
                    if ($headerKeys -contains $key) { 
                        $rateLimitFound = $true
                        # Using curly braces to safely delimit the variable name $key
                        $rateLimitValue = "${key}: $($sampleHeaders[$key])"
                        break # Only need to find one rate-limit indicator
                    }
                }
            }

            # --- Safer server header extraction before building result ---
            $serverHeaderValue = $null
            if ($sampleHeaders -and $sampleHeaders.Keys -contains "Server") {
                $sv = $sampleHeaders["Server"]
                # Header values can be arrays; join them.
                if ($sv -is [array]) {
                    $serverHeaderValue = ($sv -join ';')
                } else {
                    $serverHeaderValue = $sv.ToString()
                }
                # Clean up potential excessive whitespace
                $serverHeaderValue = $serverHeaderValue -replace '\s+', ' '
            } 
            
            # ------------------------------------------------------------------
            # FINAL RESULT ASSEMBLY
            # ------------------------------------------------------------------
            # Start building the properties hash table for the output object.
            # Use [ordered] to maintain a consistent property order.
            $resultProperties = [ordered]@{
                Uri                          = $baseUri
                RobotsTxtExists              = $robotsInfo.Exists
                RobotsTxtDisallowAll         = $robotsInfo.DisallowForAll
                RobotsTxtCrawlDelaySeconds   = $robotsInfo.CrawlDelay
                RobotsTxtDisallowedPaths     = $robotsInfo.DisallowedPaths
                TermsOfServiceLink           = $tosLink
                SampleHttpStatus             = $sampleStatus -as [string] # Ensure string output
                ServerHeader                 = $serverHeaderValue
                RateLimitHeaderFound         = $rateLimitFound
                RateLimitHeaderValue         = $rateLimitValue
                CheckTimeUtc                 = (Get-Date).ToUniversalTime().ToString("u") # ISO 8601 format
            }

            # Create the final custom object
            $result = [PSCustomObject]$resultProperties
            
            # Output the result object to the pipeline.
            $result
        }
    }

    end {
        # If -Notice is specified, print a final disclaimer.
        if ( $Notice ) {
            Write-Host ""
            Write-Host "--- Policy Indicator Tool Summary ---"
            Write-Host "NOTE: Final decision on scraping legality requires manual review of the full Terms of Service."
            Write-Host "-------------------------------------"
        }
    }
}