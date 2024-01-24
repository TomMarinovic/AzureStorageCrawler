Function IterateStorageAccounts
{
    [CmdletBinding()]
    Param(
         [Parameter(Mandatory=$false,
        HelpMessage="Path for file output.")]
        [string]$OutputFile,

        [Parameter(Mandatory=$false,
        HelpMessage="Specific permutations file to use.")]
        [string]$Permutations = "$PSScriptRoot\targets.txt",

        [Parameter(Mandatory=$false,
        HelpMessage="Specific folders file to use.")]
        [string]$Folders = "$PSScriptRoot\permutations.txt"
    )

    $domain = '.blob.core.windows.net'
    $runningList = @()
    $lookupResult = ""

    $linecount = Get-Content $Permutations | Measure-Object -Line | Select-Object -ExpandProperty Lines
    $iter = 0
    Write-Host "Starting Search - "

    # Check Permutations
    foreach ($word in (Get-Content $Permutations)) {
        # Track the progress
        $iter++
        $lineprogress = ($iter / $linecount) * 100
        Write-Progress -Status 'Progress..' -Activity "Enumerating Storage Accounts based off of target.txt on $word" -PercentComplete $lineprogress

        $lookup = ($word + $domain).ToLower()
        Write-Verbose "Resolving - $lookup"
        try {
            ($lookupResult = Resolve-DnsName $lookup -ErrorAction Stop -Verbose:$false | Select-Object -ExpandProperty Name | Select-Object -First 1) | Out-Null
        }
        catch {}
        if ($lookupResult -ne "") {
            $runningList += $lookup
            $currentTimestamp = (Get-Date -Format "dd/MM/yyyy HH:mm")
            Write-Host "Found Storage Account - $lookup - $currentTimestamp"
            $lookup += " - $currentTimestamp"
            if ($OutputFile) {
                $lookup >> $OutputFile
            }
        }
        $lookupResult = ""
    }

    Write-Verbose ("DNS Brute-Force Complete " + (Get-Date -Format "dd/MM/yyyy HH:mm"))
    Write-Verbose ("Starting Container Enumeration" + (Get-Date -Format "dd/MM/yyyy HH:mm"))

    # Extra New Line for Readability
    Write-Host ""

    # Get line counts for number of storage accounts for status
    $foldercount = Get-Content $Folders | Measure-Object -Line | Select-Object -ExpandProperty Lines

    # Go through the valid blob storage accounts and confirm Anonymous Access / List files
    foreach ($subDomain in $runningList) {
        $iter = 0

        # Read in file
        $folderContent = Get-Content $Folders

        # Folder Names to guess for containers
        foreach ($folderName in $folderContent) {
            # Track the progress
            $iter++
            $subfolderprogress = ($iter / $foldercount) * 100

            Write-Progress -Status 'Progress..' -Activity "Enumerating Containers for $subDomain Storage Account" -PercentComplete $subfolderprogress

            $dirGuess = ($subDomain + "/" + $folderName).ToLower()
            # URL for confirming container
            $uriGuess = "https://" + $dirGuess + "?restype=container"
            try {
                $status = (Invoke-WebRequest -Uri $uriGuess -ErrorAction Stop -UseBasicParsing).StatusCode
                # 200 Response Confirms the Container
                if ($status -eq 200) {
                    $currentTimestamp = (Get-Date -Format "MM/dd/yyyy HH:mm")
                    Write-Host "Found Container - $dirGuess - $currentTimestamp"
                    $Outguess = "$dirguess + $currentTimestamp"
                    if ($OutputFile) {
                        $Outguess >> $OutputFile
                    }
                    # URL for listing publicly available files
                    $uriList = "https://" + $dirGuess + "?restype=container&comp=list"
                    $FileList = (Invoke-WebRequest -Uri $uriList -Method Get).Content
                    # Microsoft includes these characters in the response, Thanks...
                    [xml]$xmlFileList = $FileList -replace "ï»¿"
                    $foundURL = $xmlFileList.EnumerationResults.Blobs.Blob.Name

                    # Parse the XML results
                    if ($foundURL.Length -gt 1) {
                        foreach ($url in $foundURL) {
                            Write-Host -ForegroundColor Cyan "`tPublic File Available: https://$dirGuess/$url - $currentTimestamp"
                            if ($OutputFile) {
                                $url >> $OutputFile
                            }
                        }
                    } else {
                        Write-Host -ForegroundColor Cyan "`tEmpty Public Container Available: $uriList - $currentTimestamp"
                        if ($OutputFile) {
                            $uriList >> $OutputFile
                        }
                    }
                }
            }
            catch {}
        }
    }
    Write-Verbose ("Container Enumeration Complete - " + (Get-Date -Format "dd/MM/yyyy HH:mm"))
}
