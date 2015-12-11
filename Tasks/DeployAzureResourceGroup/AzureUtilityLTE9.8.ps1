# This file implements IAzureUtility for Azure PowerShell version <= 0.9.8

function Create-AzureResourceGroupIfNotExist
{
    param([string]$resourceGroupName,
    [string]$location)

    if([string]::IsNullOrEmpty($resourceGroupName) -eq $false)
    {
        try
        {
            Write-Verbose -Verbose "[Azure Resource Manager]Getting resource group:$resourceGroupName"
            $azureResourceGroup = Get-AzureResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction silentlyContinue
            Write-Verbose -Verbose "[Azure Resource Manager]Got resource group:$resourceGroupName"
        }
        catch
        {
            #Ignoring the exception
        }
   	}

    if(!$azureResourceGroup -and [string]::IsNullOrEmpty($location) -eq $false)
    {
        Write-Verbose -Verbose "[Azure Resource Manager]Creating resource group $resourceGroupName in $location"

        $response = New-AzureResourceGroup -Name $resourceGroupName -Location $location -Verbose -ErrorAction Stop

        Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Created resource group '{0}'" -ArgumentList $resourceGroupName)
    }
}

function Deploy-AzureResourceGroup
{
    param([string]$csmFile,
          [System.Collections.Hashtable]$csmParametersObject,
          [string]$resourceGroupName,
          [string]$overrideParameters)
	
	Switch-AzureMode AzureResourceManager

    Write-Host "[Azure Resource Manager]Creating resource group deployment with name $resourceGroupName"      
	
    if (!$csmParametersObject)
    {
	    $finalCommand = "`$azureResourceGroupDeployment = New-AzureResourceGroupDeployment -Name `"$resourceGroupName`" -ResourceGroupName `"$resourceGroupName`" -TemplateFile `"$csmFile`" $overrideParameters -Verbose -ErrorAction silentlycontinue -ErrorVariable deploymentError"
    }
    else
    {	
        $finalCommand = "`$azureResourceGroupDeployment = New-AzureResourceGroupDeployment -Name `"$resourceGroupName`" -ResourceGroupName `"$resourceGroupName`" -TemplateFile `"$csmFile`" -TemplateParameterObject `$csmParametersObject $overrideParameters -Verbose -ErrorAction silentlycontinue -ErrorVariable deploymentError"
    }
    Write-Verbose -Verbose "$finalCommand"
    Invoke-Expression -Command $finalCommand
	
	@{"azureResourceGroupDeployment" = $($azureResourceGroupDeployment); "deploymentError" = $($deploymentError)}
}

function Get-AllVmInstanceView
{
    param([string]$resourceGroupName)
	
	Switch-AzureMode AzureResourceManager

	$VmInstanceViews = @{}
    if ([string]::IsNullOrEmpty($resourceGroupName) -eq $false)
    {
        Write-Verbose -Verbose "[Azure Resource Manager]Getting resource group $resourceGroupName"
        $azureResourceGroup = Get-AzureResourceGroup -ResourceGroupName $resourceGroupName -Verbose -ErrorAction Stop
        Write-Verbose -Verbose "[Azure Resource Manager]Got resource group $resourceGroupName"
        Set-Variable -Name azureResourceGroup -Value $azureResourceGroup -Scope "Global"

        $azureResourceGroupResources = $azureResourceGroup.Resources |  Where-Object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"}

        foreach($resource in $azureResourceGroupResources)
        {
            $name = $resource.Name
            Write-Verbose -Verbose "[Azure Resource Manager]Getting VM $name from resource group $resourceGroupName"
            $vmInstanceView = Get-AzureVM -Name $resource.Name -ResourceGroupName $resourceGroupName -Status -Verbose -ErrorAction Stop
            Write-Verbose -Verbose "[Azure Resource Manager]Got VM $name from resource group $resourceGroupName"
			$VmInstanceViews.Add($name, $vmInstanceView)
		}
	}
	return $VmInstanceViews
}

function Get-AzureVMsInResourceGroup
{
    param([string]$resourceGroupName)

    Switch-AzureMode AzureResourceManager
    try
    {
        Write-Verbose -Verbose "[Azure Call]Getting resource group:$resourceGroupName RM virtual machines type resources"
        $azureVMResources = Get-AzureVM -ResourceGroupName $resourceGroupName -Verbose
        Write-Verbose -Verbose "[Azure Call]Got resource group:$resourceGroupName RM virtual machines type resources"
        Set-Variable -Name azureVMResources -Value $azureVMResources -Scope "Global"
    }
    catch [Microsoft.WindowsAzure.Commands.Common.ComputeCloudException],[System.MissingMethodException], [System.Management.Automation.PSInvalidOperationException]
    {
        Write-Verbose $_.Exception.Message -Verbose
        throw (Get-LocalizedString -Key "Ensure resource group '{0}' exists and has atleast one virtual machine in it" -ArgumentList $resourceGroupName)
    }
    catch
    {
        throw
    }

    return $azureVMResources
}

function Start-Machine
{
    param([string]$resourceGroupName,
          [string]$machineName)

    Switch-AzureMode AzureResourceManager

    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Starting machine '{0}'" -ArgumentList $machineName)
    $response = Start-AzureVM -Name $machineName -ResourceGroupName $resourceGroupName -ErrorAction Stop -Verbose
    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Started machine '{0}' from Azure provider" -ArgumentList $machineName)

    return $response
}

function Stop-Machine
{
    param([string]$resourceGroupName,
          [string]$machineName)

    Switch-AzureMode AzureResourceManager

    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Stopping machine '{0}'" -ArgumentList $machineName)
    $response = Stop-AzureVM -Name $machineName -ResourceGroupName $resourceGroupName -Force -ErrorAction Stop -Verbose
    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Stopped machine '{0}' from Azure provider" -ArgumentList $machineName)

    return $response
}

function Delete-Machine
{
    param([string]$resourceGroupName,
          [string]$machineName)

    Switch-AzureMode AzureResourceManager
    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Deleting machine '{0}'" -ArgumentList $machineName)
    $response = Remove-AzureVM -Name $machineName -ResourceGroupName $resourceGroupName -Force -ErrorAction Stop -Verbose
    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Deleted machine '{0}' from Azure provider" -ArgumentList $machineName)

    return $response
}

function Delete-ResourceGroup
{
    param([string]$resourceGroupName)

    Switch-AzureMode AzureResourceManager

    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Deleting resource group '{0}'" -ArgumentList $resourceGroupName)
    Remove-AzureResourceGroup -Name $resourceGroupName -Force -ErrorAction Stop -Verbose
    Write-Host (Get-LocalizedString -Key "[Azure Resource Manager]Deleted resource group '{0}'" -ArgumentList $resourceGroupName)
}

function Get-AzureClassicVMsDetailsInResourceGroup
{
    param([string]$resourceGroupName)

	Switch-AzureMode AzureServiceManagement
    Write-Verbose -Verbose "[Azure Call]Getting resource group:$resourceGroupName classic virtual machines type resources"
    $azureClassicVMResources = Get-AzureVM -ServiceName $resourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Write-Verbose -Verbose "[Azure Call]Got resource group:$resourceGroupName classic virtual machines type resources"
	
	[hashtable]$classicVMsDestails = @{}
	
	if($azureClassicVMResources)
	{
	    Write-Verbose -Verbose "Trying to get FQDN and WinRM HTTPS Port for the classic azureVM resources from resource Group $resourceGroupName"
		foreach($azureClassicVm in $azureClassicVMResources)
        {
            $resourceName = $azureClassicVm.Name

            Write-Verbose -Verbose "[Azure Call]Getting classic virtual machine:$resourceName details in resource group $resourceGroupName"
            $azureClassicVM = Get-AzureVM -ServiceName $resourceGroupName -Name $resourceName -Verbose
            Write-Verbose -Verbose "[Azure Call]Got classic virtual machine:$resourceName details in resource group $resourceGroupName"
            
            Write-Verbose -Verbose "[Azure Call]Getting classic virtual machine:$resourceName PowerShell endpoint in resource group $resourceGroupName"
            $azureClassicVMEndpoint = $azureClassicVM | Get-AzureEndpoint -Name PowerShell
            Write-Verbose -Verbose "[Azure Call]Got classic virtual machine:$resourceName PowerShell endpoint in resource group $resourceGroupName"

            $fqdnUri = [System.Uri]$azureClassicVM.DNSName
            $resourceFQDN = $fqdnUri.Host
			$resourceWinRmHttpsPort = $azureClassicVMEndpoint.Port
            Write-Verbose -Verbose "FQDN value for resource $resourceName is $resourceFQDN"
            Write-Verbose -Verbose "WinRM HTTPS Port for resource $resourceName is $resourceWinRmHttpsPort"
			$resourceProperties = @{}
            $resourceProperties.Name = $resourceName
            $resourceProperties.fqdn = $resourceFQDN
            $resourceProperties.winRMHttpsPort = $resourceWinRmHttpsPort
			$classicVMsDestails.Add($resourceName, $resourceProperties)
        }
	}
	
	return $classicVMsDestails
}

function Get-AzureVMsConnectionDetailsInResourceGroup
{
    param([string]$resourceGroupName)

	[hashtable]$ResourcesDestails = @{}
	[hashtable]$LoadBalancerDestails = @{}
	
	Switch-AzureMode AzureResourceManager
    $azureVMResources = Get-AzureVMsInResourceGroup -resourceGroupName $resourceGroupName
	$ResourcesDestails.Add("azureVMResources", $azureVMResources)
	if($azureVMResources)
	{
	    Write-Verbose -Verbose "[Azure Call]Getting network interfaces in resource group $resourceGroupName"
        $networkInterfaceResources = Get-AzureNetworkInterface -ResourceGroupName $resourceGroupName -Verbose
        Write-Verbose -Verbose "[Azure Call]Got network interfaces in resource group $resourceGroupName"
        $ResourcesDestails.Add("networkInterfaceResources", $networkInterfaceResources)

        Write-Verbose -Verbose "[Azure Call]Getting public IP Addresses in resource group $resourceGroupName"
        $publicIPAddressResources = Get-AzurePublicIpAddress -ResourceGroupName $resourceGroupName -Verbose
        Write-Verbose -Verbose "[Azure Call]Got public IP Addresses in resource group $resourceGroupName"
        $ResourcesDestails.Add("publicIPAddressResources", $publicIPAddressResources)

        Write-Verbose -Verbose "[Azure Call]Getting load balancers in resource group $resourceGroupName"
        $lbGroup = Get-AzureResource -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Network/loadBalancers" -Verbose
        Write-Verbose -Verbose "[Azure Call]Got load balancers in resource group $resourceGroupName"
		
		if($lbGroup)
        {		    
            foreach($lb in $lbGroup)
            {
			    $lbDetails = @{}
                Write-Verbose -Verbose "[Azure Call]Getting load balancer in resource group $resourceGroupName"
                $loadBalancer = Get-AzureLoadBalancer -Name $lb.Name -ResourceGroupName $resourceGroupName -Verbose
                Write-Verbose -Verbose "[Azure Call]Got load balancer in resource group $resourceGroupName"
				
				Write-Verbose "[Azure Call]Getting LoadBalancer Frontend Ip Config" -Verbose
                $frontEndIPConfigs = Get-AzureLoadBalancerFrontendIpConfig -LoadBalancer $loadBalancer
                Write-Verbose "[Azure Call]Got LoadBalancer Frontend Ip Config" -Verbose
				
				Write-Verbose "[Azure Call]Getting Azure LoadBalancer Inbound NatRule Config" -Verbose
                $inboundRules = Get-AzureLoadBalancerInboundNatRuleConfig -LoadBalancer $loadBalancer
                Write-Verbose "[Azure Call]Got Azure LoadBalancer Inbound NatRule Config" -Verbose
				
				$lbDetails.Add("frontEndIPConfigs", $frontEndIPConfigs)
				$lbDetails.Add("inboundRules", $inboundRules)	
                $LoadBalancerDestails.Add($lb.Name, $lbDetails)				
			}
			
			$ResourcesDestails.Add("loadBalancerResources", $LoadBalancerDestails)
		}		
	}

    return $ResourcesDestails
}
