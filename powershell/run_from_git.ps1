


function RunFromGit
{
    param (
        [Parameter(Mandatory = $true)][string]$script, # Path of file in github repo
        $outfile, # File to execute (probably same as above sans dirs)
        $automation_name, # Used for temp dir names
        [string]$github_api_url = 'https://api.github.com/repos/BlockheadVFX-IT/boilerplates/contents', # If you are using a proxy change this
        [string]$github_raw_url = 'https://raw.githubusercontent.com/BlockheadVFX-IT', # If you are using a proxy change this
        [bool]$load_helpers = $true,
        [bool]$user_mode = $false, # If running as logged on user instead of system user, will change working dir to $env:LOCALAPPDATA
        [string]$pub_branch = 'main' # used to swap to different test branches if you want
    )

    $prev_cwd = Get-Location

    if ($load_helpers)
    {
        # If you want to add more helpers, include their names here and upload them to the 
        # powershell/helpers/ folder for the public github repo
        $helper_files = @('create_shortcut.ps1', 'check_installed.ps1', 'set_env_var.ps1', 'set_reg_key.ps1', 'uninstall_program.ps1')
        $base_url = "$github_raw_url/tactical-public/$pub_branch/powershell/helpers"

        foreach ($file in $helper_files)
        {
            Write-Host "Sourcing $file..."
            . ([Scriptblock]::Create((Invoke-WebRequest -Uri "$base_url/$file" -UseBasicParsing).Content))
        }
    }

    
    # Preconfigured variables:
    if ($user_mode)
    {
        $trmm_dir = "$env:LOCALAPPDATA\Temp" # In usermode ProgramData is not writeable by most users
    }
    else
    {
        $trmm_dir = 'C:\ProgramData\TacticalRMM' # Otherwise use this dir
    }

    # Get the install script from github
    # Start by getting the PAT from S3 to access our private repo
    Write-Host 'Getting personal access token from S3...'
    # pat URL encoded with b64 here just to avoid getting grabbed by scrapers
    $pat_url_b64 = 'aHR0cHM6Ly90YW5nZWxvYnVja2V0bmluamEuczMuYXAtc291dGhlYXN0LTIuYW1hem9uYXdzLmNvbS90cm1tX2dpdGh1Yl9wYXQucGF0'    ##converted so that RL could be hidden 
    $pat_url = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pat_url_b64))          ##command to decode the above random string
    $pat = Invoke-WebRequest -Uri $pat_url -UseBasicParsing | Select-Object -ExpandProperty Content              ##downloads the PAT file form the URL and gets contents of that file 
    $pat = [Text.Encoding]::UTF8.GetString($pat)
    echo $pat
   


        # Now we have the PAT, request the file from the repo
        Write-Host "Getting $script from github..."
        Invoke-WebRequest -Uri "$github_api_url/$([system.uri]::EscapeDataString($script))" -Headers $headers -OutFile $outfile -UseBasicParsing
        if (Test-Path $outfile)
        {
            Write-Host "$outfile downloaded successfully"
        }
        else
        {
            Write-Host "$outfile not downloaded"
        }

        # We've got the script, now to run it...
        $process_error = $false
        try
        {
            Write-Host "Running $outfile ..."
            & ".\$outfile" 2>&1 | Out-String
            $result = $LASTEXITCODE
            Write-Host "$outfile done, cleaning up..."
        }
        catch
        {
            # We will throw any errors later, after we have cleaned up dirs
            $process_error = $_.Exception 
        }
        
       

        # Clean up 
        Set-Location "$trmm_dir"
        Remove-Item "$trmm_dir\$automation_name" -Force -Recurse
        if (Test-Path "$trmm_dir\$automation_name")
        {
            Write-Host "Failed to clean up $trmm_dir\$automation_name"
        }
        else
        {
            Write-Host "Cleaned up $trmm_dir\$automation_name"
        }
        Write-Host $result
    }

    Set-Location $prev_cwd
    if ($process_error)
    {
        throw $process_error
    }
    else
    {
        return $result
    }
}


function Format-InvalidPathCharacters
{
    param (
        [string]$path
    )

    # Define a regex pattern to match non-standard characters
    $invalidCharsPattern = '[\\/:*?"<>|]'

    # Replace non-standard characters with an underscore
    $escapedPath = [regex]::Replace($path, $invalidCharsPattern, '_')

    return $escapedPath
}