$VCF_INSTALLER_FQDN="sddcm01.vcf.lab"
$VCF_INSTALLER_PASSWORD="VMware1!VMware1!"

### DO NOT EDIT BEYOND HERE ###

$payload = @{
    "username" = "admin@local"
    "password" = $VCF_INSTALLER_PASSWORD
}

$body = $payload | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
}
$request = Invoke-WebRequest -Uri https://${VCF_INSTALLER_FQDN}/v1/tokens -Method POST -Body $body -Headers $headers -SkipCertificateCheck
if($request.StatusCode -eq 200) {
    $accesToken = ($request.Content | ConvertFrom-Json).accessToken
}

$headers += @{
    "Authorization" = "Bearer ${accesToken}"
}
$request = Invoke-WebRequest -Uri https://${VCF_INSTALLER_FQDN}/v1/sddcs -Method GET -Headers $headers -SkipCertificateCheck
if($request.StatusCode -eq 200) {
    # return last element which hopefully is the last successful deployment
    $sddc = ($request.Content | ConvertFrom-Json).elements | where {$_.status -eq "COMPLETED_WITH_SUCCESS"}[-1]
    $sddcId = $sddc.id
}

$request = Invoke-WebRequest -Uri https://${VCF_INSTALLER_FQDN}/v1/sddcs/${sddcId}/spec -Method GET -Headers $headers -SkipCertificateCheck
if($request.StatusCode -eq 200) {
    $sddcSpec = ($request.Content | ConvertFrom-Json)
}

# Initialize a variable to hold the total duration
$totalDuration = New-TimeSpan

$milestoneReport = foreach ($m in $sddc.milestones) {
    # Calculate duration for this specific milestone
    $duration = [datetime]$m.updateTimestamp - [datetime]$m.creationTimestamp

    # Add this duration to our total
    $totalDuration = $totalDuration.Add($duration)

    # Output the custom object for the report variable
    [PSCustomObject]@{
        Milestone     = $m.name
        Start = $m.creationTimestamp
        End = $m.updateTimestamp
        Duration = "{0:hh\:mm\:ss}" -f $duration
    }
}

# Display the individual milestones
$milestoneReport | Format-Table -AutoSize

# Display the total sum
Write-Host "------------------------------------"
Write-Host "Deployment: $($sddcSpec.vcfInstanceName) ($($sddcSpec.workflowType))" -ForegroundColor Cyan

# Custom formatting for Hours, Minutes, Seconds
$timeString = "{0} Hours {1} Minutes {2} Seconds" -f $totalDuration.Hours, $totalDuration.Minutes, $totalDuration.Seconds
Write-Host "Deployment Time: $timeString`n" -ForegroundColor Cyan