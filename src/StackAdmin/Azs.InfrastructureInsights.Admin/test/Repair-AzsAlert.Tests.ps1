$loadEnvPath = Join-Path $PSScriptRoot 'loadEnv.ps1'
if (-Not (Test-Path -Path $loadEnvPath)) {
    $loadEnvPath = Join-Path $PSScriptRoot '..\loadEnv.ps1'
}
. ($loadEnvPath)
$TestRecordingFile = Join-Path $PSScriptRoot 'Repair-AzsAlert.Recording.json'
$currentPath = $PSScriptRoot
while(-not $mockingPath) {
    $mockingPath = Get-ChildItem -Path $currentPath -Recurse -Include 'HttpPipelineMocking.ps1' -File
    $currentPath = Split-Path -Path $currentPath -Parent
}
. ($mockingPath | Select-Object -First 1).FullName

InModuleScope Azs.InfrastructureInsights.Admin {

    Describe "Alerts" -Tags @('Alert', 'InfrastructureInsightsAdmin') {

        it "TestRepairAlert" -Skip:$('TestRepairAlert' -in $global:SkippedTests) {

            $global:TestName = 'TestRepairAlert'
            $ErrorActionPreference = "SilentlyContinue"

            # Test repair for a non-existing alert
            Write-Verbose "Repairing alert with an invalid name"

            Repair-AzsAlert -Name "wrongid" -Location $global:location -ErrorVariable invalidAlertErr

            if(($invalidAlertErr.Count -ne 0) -and ($invalidAlertErr[0].ErrorDetails.Message.contains("Failed to remediate alert")))
            {
                Write-Verbose "As expected the repair operation failed"
            }else
            {
                throw  $invalidAlertErr
            }

            $Alerts = Get-AzsAlert -ResourceGroupName $global:ResourceGroupName -Location $global:location

            $Alerts | Should Not Be $null

            foreach ($Alert in $Alerts)
            {
                $Alert | Should not be $null

                $Alert.State | Should not be $null

                Write-Verbose "Repairing alert $($Alert.AlertId)"

                Repair-AzsAlert -Name $Alert.AlertId -ResourceGroupName $global:ResourceGroupName -Location $global:location -ErrorVariable validAlertErr

                if($validAlertErr -ne $null){

                    if ($Alert.State -eq "Active" -and $Alert.hasValidRemediationAction -eq $true)
                    {
                        throw "Repair operation failed with $validAlertErr"
                    }
                    else
                    {
                         if($validAlertErr[0].ErrorDetails.Message.contains("failed prerequisite checks"))
                         {
                            Write-Verbose "As expected the repair operation failed"
                         }
                         else
                         {
                            throw "Repair operation failed with $validAlertErr"
                         }
                    }
                }
            }
            return
        }
    }
}