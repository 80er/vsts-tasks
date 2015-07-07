function Initialize-DTLServiceHelper
{
    Write-Verbose "Getting the vss connection object" -Verbose
    $connection = Get-VssConnection -TaskContext $distributedTaskContext

    Set-Variable -Name connection -Value $connection -Scope "Script"
}

function Get-MachineGroup
{
    param([string]$machineGroupName,
          [string]$filters)    

    if ($Action -eq "Block")
    {
        $time = $WaitTimeInMinutes -as [INT]

        if(($time -eq $null) -or ($time -lt 0))
        {
            Write-Error(Get-LocalizedString -Key "Cannot wait for {0} minutes. Wait Time in minutes should be a positive number of minutes for which the task will wait for the machine group to get unblocked" -ArgumentList $WaitTimeInMinutes)
        }

        $getEnvironmentCommand = 
        {
            $environment = Get-Environment -EnvironmentName $machineGroupName  -Connection $connection -Filters $filters -ErrorAction Stop -Verbose
        }
        
        Write-Verbose "Getting the machine group $machineGroupName" -Verbose
        Invoke-WithRetry -Command $getEnvironmentCommand -RetryDurationInMinutes $WaitTimeInMinutes -OperationDetail "Get Environment"
        Write-Verbose "Retrieved the machine group"
    }
    else
    {
        Write-Verbose "Getting the machine group $machineGroupName" -Verbose
        $environment = Get-Environment -EnvironmentName $machineGroupName  -Connection $connection -Filters $filters -ErrorAction Stop -Verbose
        Write-Verbose "Retrieved the machine group"
    }

    return $environment
}

function Delete-MachineGroup
{
    param([string]$machineGroupName,
          [string]$filters)

    Write-Verbose "Deleting machine group $machineGroupName" -Verbose
    # If filters are not provided then it deltes entire machine group. If filters are given then it will delete all the machines satisfing the given filters.
    if($filters)
    {
        Remove-EnvironmentResources -EnvironmentName $machineGroupName -Filters $filters -Connection $connection -ErrorAction Stop -Verbose
        Write-Verbose "Removed machines of the machine group $machineGroupName" -Verbose
    }
    else
    {
        Remove-Environment -EnvironmentName $machineGroupName -Connection $connection -ErrorAction Stop
        Write-Verbose "Deleted machine group $machineGroupName" -Verbose
    } 

}

function Invoke-MachineGroupOperation
{
     param([string]$machineGroupName,
           [string]$operationName,
           [Microsoft.VisualStudio.Services.DevTestLabs.Model.ResourceV2[]]$machines)

    Write-Verbose "Invoking $operationName for the machine group $machineGroupName" -Verbose
    $operationId = Invoke-EnvironmentOperation -EnvironmentName $machineGroupName -OperationName $operationName -ResourceNames $machines.Name -Connection $connection -ErrorAction SilentlyContinue -Verbose
    Write-Verbose "Invoked $operationName for the machine group $machineGroupName" -Verbose

    return $operationId
}

function End-MachineGroupOperation
{
    param([string]$machineGroupName,
          [string]$operationName,
          [Guid]$operationId,
          [string]$error,
          [string]$status)

    Write-Verbose "Saving $operationName details for machine group $machineGroupName" -Verbose
    Complete-EnvironmentOperation -EnvironmentName $machineGroupName -EnvironmentOperationId $operationId -Status $status -Connection $connection -ErrorMessage $error -ErrorAction SilentlyContinue -Verbose
    Write-Verbose "Saved $operationName details for machine group $machineGroupName" -Verbose
}

function End-MachineOperation
{
    param([string]$machineGroupName,
          [string]$machineName,
          [string]$operationName,
          [Guid]$operationId,
          [string]$status)

    Write-Verbose "Saving $operationName details for machine $machineName in machine group $machineGroupName" -Verbose
    Complete-EnvironmentResourceOperation -EnvironmentName $machineGroupName -ResourceName $machineName -EnvironmentOperationId $operationId -Status $status -Connection $connection -ErrorAction SilentlyContinue -Verbose
    Write-Verbose "Completed $operationName for the machine $machineName in machine group $machineGroupName" -Verbose
}

function Invoke-WithRetry {
    param(    
    [Parameter(Mandatory)]$Command,
    [Parameter(Mandatory)]$RetryDurationInMinutes = 30,
    [Parameter(Mandatory)]$OperationDetail,
    $RetryDelayInSeconds = 30)
    
    $ErrorActionPreference = 'Stop'
    $currentRetry = 0
    $endTime = [System.DateTime]::UtcNow.AddMinutes($RetryDurationInMinutes)
    $success = $false

    do {
        try
        {
            $result = & $Command
            return $result
        }
        catch [System.Exception]
        {
            if ($_.Exception.GetType().FullName -eq "Microsoft.VisualStudio.Services.DevTestLabs.Client.DtlReservationAccessException")
            {
                $currentTime = [System.DateTime]::UtcNow
                $currentRetry = $currentRetry + 1
            
                if ($currentTime -gt $endTime)
                {
                    throw $_
                } 
                else 
                {             
                    Write-Warning (Get-LocalizedString -Key "Operation {0} failed: {1}. Retrying after {2} second(s)" -ArgumentList $OperationDetail, $_.Exception.Message, $RetryDelayInSeconds)
                    Start-Sleep -s $RetryDelayInSeconds            
                }
            }
            else
            {
                throw $_
            }
        }
    } while (!$success);
}