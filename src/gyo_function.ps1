<#
.SYNOPSIS
    gyo - Count rows
    
    gyo [file]...

    If file is not specified, it is read from
    the pipeline input.

    If file is specified, the number of lines is
    outut along with the filename.

.DESCRIPTION

    The main design pattern of this command was abstracted from
    Universal Shell Programming Laboratory's "Open-usp-Tukubai",
    Here is the original copyright notice for "Open-usp-Tukubai":
    
        The MIT License Copyright (c) 2011-2023 Universal Shell Programming Laboratory
        https://github.com/usp-engineers-community/Open-usp-Tukubai/blob/master/LICENSE

.LINK
    gyo, retu

.EXAMPLE
    1..10 | gyo
    10

.EXAMPLE
    gyo gyo*.ps1
    70 gyo_function.ps1

#>
function gyo {
    begin {
        [bool] $stdinFlag    = $False
        [bool] $readFileFlag = $False
        [int] $readRowCounter = 0

        if($args.Count -eq 0){
            # No args: get input from pipeline
            [bool] $stdinFlag = $True
        }else{
            # With args: all args are treated as file
            [bool] $readFileFlag = $True
            [int] $fileArryStartCounter = 0
        }

        if (-not ("FastLineCounter" -as [type])) {
            Add-Type -TypeDefinition @"
            using System;
            using System.IO;

            public static class FastLineCounter {
                public static long CountLines(string path) {
                    long count = 0;
                    // Optimize I/O using a 64 KB fixed buffer and sequential scan.
                    using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 65536, FileOptions.SequentialScan)) {
                        if (fs.Length == 0) return 0;
                        
                        byte[] buffer = new byte[65536];
                        int bytesRead;
                        bool endsWithNewline = false;
                        
                        while ((bytesRead = fs.Read(buffer, 0, buffer.Length)) > 0) {
                            for (int i = 0; i < bytesRead; i++) {
                                // Count LF (\n = byte 10), supporting both CRLF and LF environments.
                                if (buffer[i] == 10) { 
                                    count++;
                                }
                            }
                            endsWithNewline = (buffer[bytesRead - 1] == 10);
                        }
                        
                        // Correction when the final line does not end with a newline character.
                        if (!endsWithNewline) {
                            count++;
                        }
                    }
                    return count;
                }
            }
"@
        }
    }
    process {
        if($stdinFlag){ $readRowCounter++ }
    }
    end {
        if($readFileFlag){
            for($i = $fileArryStartCounter; $i -lt $args.Count; $i++){
                # Add the -File switch to ignore directories.
                $fileList = Get-ChildItem $args[$i] -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
                
                foreach($fileFullPath in $fileList){
                    $dispFileName = Split-Path -Leaf $fileFullPath
                    try {
                        # Invoke the high-speed counting routine implemented in C#.
                        $fileGyoNum = [FastLineCounter]::CountLines($fileFullPath)
                        Write-Output "$fileGyoNum $dispFileName"
                    } catch {
                        Write-Error "Failed to read the file.: $dispFileName - $_"
                    }
                }
            }
        }else{
            Write-Output $readRowCounter
        }
    }
}
