<#
    .SYNOPSIS
        Unit test for DSC_SqlAG DSC resource.
#>

# Suppressing this rule because Script Analyzer does not understand Pester's syntax.
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
# Suppressing this rule because tests are mocking passwords in clear text.
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:dscModuleName = 'SqlServerDsc'
    $script:dscResourceName = 'DSC_SqlAG'

    $env:SqlServerDscCI = $true

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Unit'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

    # Loading mocked classes
    Add-Type -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Stubs') -ChildPath 'SMO.cs')

    # Load the correct SQL Module stub
    $script:stubModuleName = Import-SQLModuleStub -PassThru

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:dscResourceName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:dscResourceName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:dscResourceName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Restore-TestEnvironment -TestEnvironment $script:testEnvironment

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscResourceName -All | Remove-Module -Force

    # Unload the stub module.
    Remove-SqlModuleStub -Name $script:stubModuleName

    # Remove module common test helper.
    Get-Module -Name 'CommonTestHelper' -All | Remove-Module -Force

    Remove-Item -Path 'env:SqlServerDscCI'
}
Describe 'SqlAG\Get-TargetResource' {
    BeforeAll {
        $mockConnectSqlServer1 = {
            # Mock the server object
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'Server1'
            $mockServerObject.NetName = 'Server1'
            $mockServerObject.DomainInstanceName = 'Server1'
            $mockServerObject.IsHadrEnabled = $true
            $mockServerObject.ServiceName = 'MSSQLSERVER'
            $mockServerObject.Version = @{
                Major = 13
            }

            # Mock the availability group replicas
            $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica1.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica1.BackupPriority = 50
            $mockAvailabilityGroupReplica1.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica1.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica1.EndpointUrl = 'TCP://Server1:5022'
            $mockAvailabilityGroupReplica1.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica1.Name = 'Server1'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingConnectionUrl = 'TCP://Server1.domain.com:1433'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica1.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica2 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica2.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica2.BackupPriority = 50
            $mockAvailabilityGroupReplica2.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica2.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica2.EndpointUrl = 'TCP://Server2:5022'
            $mockAvailabilityGroupReplica2.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica2.Name = 'Server2'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingConnectionUrl = 'TCP://Server2.domain.com:1433'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica2.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica3 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica3.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica3.BackupPriority = 50
            $mockAvailabilityGroupReplica3.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica3.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica3.EndpointUrl = 'TCP://Server3:5022'
            $mockAvailabilityGroupReplica3.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica3.Name = 'Server3'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingConnectionUrl = 'TCP://Server3.domain.com:1433'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica3.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            # Mock the availability groups
            $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
            $mockAvailabilityGroup1.Name = 'AG_AllServers'
            $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server2'
            $mockAvailabilityGroup1.LocalReplicaRole = 'Secondary'
            $mockAvailabilityGroup1.AutomatedBackupPreference = 'Secondary'
            $mockAvailabilityGroup1.FailureConditionLevel = 'OnCriticalServerError'
            $mockAvailabilityGroup1.BasicAvailabilityGroup = $true
            $mockAvailabilityGroup1.DatabaseHealthTrigger = $true
            $mockAvailabilityGroup1.DtcSupportEnabled = $true
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica2)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica3)

            $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

            $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
            $mockEndpoint.EndpointType = 'DatabaseMirroring'
            $mockEndpoint.Protocol = @{
                TCP = @{
                    ListenerPort = 5022
                }
            }

            $mockServerObject.Endpoints.Add($mockEndpoint)

            return $mockServerObject
        }

        $mockConnectSqlServer2 = {
            # Mock the server object
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'Server2'
            $mockServerObject.NetName = 'Server2'
            $mockServerObject.DomainInstanceName = 'Server2'
            $mockServerObject.IsHadrEnabled = $true
            $mockServerObject.ServiceName = 'MSSQLSERVER'
            $mockServerObject.Version = @{
                Major = 12
            }

            # Mock the availability group replicas
            $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica1.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica1.BackupPriority = 50
            $mockAvailabilityGroupReplica1.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica1.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica1.EndpointUrl = 'TCP://Server1:5022'
            $mockAvailabilityGroupReplica1.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica1.Name = 'Server1'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingConnectionUrl = 'TCP://Server1.domain.com:1433'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingList = @('Server1', 'Server2')

            $mockAvailabilityGroupReplica2 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica2.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica2.BackupPriority = 50
            $mockAvailabilityGroupReplica2.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica2.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica2.EndpointUrl = 'TCP://Server2:5022'
            $mockAvailabilityGroupReplica2.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica2.Name = 'Server2'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingConnectionUrl = 'TCP://Server2.domain.com:1433'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica2.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica3 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica3.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica3.BackupPriority = 50
            $mockAvailabilityGroupReplica3.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica3.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica3.EndpointUrl = 'TCP://Server3:5022'
            $mockAvailabilityGroupReplica3.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica3.Name = 'Server3'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingConnectionUrl = 'TCP://Server3.domain.com:1433'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica3.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            # Mock the availability groups
            $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
            $mockAvailabilityGroup1.Name = 'AG_AllServers'
            $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server2'
            $mockAvailabilityGroup1.LocalReplicaRole = 'Secondary'
            $mockAvailabilityGroup1.AutomatedBackupPreference = 'Secondary'
            $mockAvailabilityGroup1.FailureConditionLevel = 'OnCriticalServerError'
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica2)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica3)

            $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

            $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
            $mockEndpoint.EndpointType = 'DatabaseMirroring'
            $mockEndpoint.Protocol = @{
                TCP = @{
                    ListenerPort = 5022
                }
            }

            $mockServerObject.Endpoints.Add($mockEndpoint)

            return $mockServerObject
        }

        Mock -CommandName Connect-SQL -MockWith $mockConnectSqlServer1 -ParameterFilter {
            $ServerName -eq 'Server1'
        }
        Mock -CommandName Connect-SQL -MockWith $mockConnectSqlServer2 -ParameterFilter {
            $ServerName -eq 'Server2'
        }
    }

    Context 'When the Availability Group is absent' {
        It 'Should not return an Availability Group' {
            InModuleScope -ScriptBlock {
                $getTargetResourceParameters = @{
                    Name         = 'AbsentAG'
                    ServerName   = 'Server1'
                    InstanceName = 'MSSQLSERVER'
                }

                $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

                $getTargetResourceResult.Name | Should -Be 'AbsentAG'
                $getTargetResourceResult.ServerName | Should -Be 'Server1'
                $getTargetResourceResult.InstanceName | Should -Be 'MSSQLSERVER'
                $getTargetResourceResult.Ensure | Should -Be 'Absent'
                $getTargetResourceResult.IsActiveNode | Should -BeTrue
                $getTargetResourceResult.AutomatedBackupPreference | Should -BeNullOrEmpty
                $getTargetResourceResultAvailabilityMode | Should -BeNullOrEmpty
                $getTargetResourceResultBackupPriority | Should -BeNullOrEmpty
                $getTargetResourceResultConnectionModeInPrimaryRole | Should -BeNullOrEmpty
                $getTargetResourceResultConnectionModeInSecondaryRole | Should -BeNullOrEmpty
                $getTargetResourceResultFailureConditionLevel | Should -BeNullOrEmpty
                $getTargetResourceResultFailoverMode | Should -BeNullOrEmpty
                $getTargetResourceResultHealthCheckTimeout | Should -BeNullOrEmpty
                $getTargetResourceResultEndpointURL | Should -BeNullOrEmpty
                $getTargetResourceResultEndpointPort | Should -BeNullOrEmpty
                $getTargetResourceResultEndpointHostName | Should -BeNullOrEmpty
                $getTargetResourceResultVersion | Should -BeNullOrEmpty
            }

            Should -Invoke -CommandName Connect-SQL -Exactly -Times 1 -Scope It
        }
    }

    Context 'When the Availability Group is present' {
        Context 'When SQL server version is 13 and higher' {
            It 'Should return an Availability Group' {
                InModuleScope -ScriptBlock {
                    $getTargetResourceParameters = @{
                        Name         = 'AG_AllServers'
                        ServerName   = 'Server1'
                        InstanceName = 'MSSQLSERVER'
                    }

                    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

                    $getTargetResourceResult.Name | Should -Be 'AG_AllServers'
                    $getTargetResourceResult.ServerName | Should -Be 'Server1'
                    $getTargetResourceResult.InstanceName | Should -Be 'MSSQLSERVER'
                    $getTargetResourceResult.Ensure | Should -Be 'Present'
                    $getTargetResourceResult.IsActiveNode | Should -Be  'True'
                    $getTargetResourceResult.AutomatedBackupPreference | Should -Be 'Secondary'
                    $getTargetResourceResult.AvailabilityMode | Should -Be 'AsynchronousCommit'
                    $getTargetResourceResult.BackupPriority | Should -Be 50
                    $getTargetResourceResult.ConnectionModeInPrimaryRole | Should -Be 'AllowAllConnections'
                    $getTargetResourceResult.ConnectionModeInSecondaryRole | Should -Be 'AllowNoConnections'
                    $getTargetResourceResult.FailureConditionLevel | Should -Be 'OnCriticalServerError'
                    $getTargetResourceResult.FailoverMode | Should -Be 'Manual'
                    $getTargetResourceResult.HealthCheckTimeout | Should -BeNullOrEmpty
                    $getTargetResourceResult.EndpointURL | Should -Be 'TCP://Server1:5022'
                    $getTargetResourceResult.EndpointPort | Should -Be 5022
                    $getTargetResourceResult.EndpointHostName | Should -Be 'Server1'
                    $getTargetResourceResult.BasicAvailabilityGroup | Should -Be 'True'
                    $getTargetResourceResult.DatabaseHealthTrigger | Should -Be 'True'
                    $getTargetResourceResult.DtcSupportEnabled | Should -Be 'True'
                    $getTargetResourceResult.Version | Should -Be 13
                }
                Should -Invoke -CommandName Connect-SQL -Exactly -Times 1 -Scope It
            }
        }
        Context 'When SQL server version is 12' {
            It 'Should return an Availability Group' {
                InModuleScope -ScriptBlock {
                    $getTargetResourceParameters = @{
                        Name         = 'AG_AllServers'
                        ServerName   = 'Server2'
                        InstanceName = 'MSSQLSERVER'
                    }

                    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

                    $getTargetResourceResult.Name | Should -Be 'AG_AllServers'
                    $getTargetResourceResult.ServerName | Should -Be 'Server2'
                    $getTargetResourceResult.InstanceName | Should -Be 'MSSQLSERVER'
                    $getTargetResourceResult.Ensure | Should -Be 'Present'
                    $getTargetResourceResult.IsActiveNode | Should -Be  'True'
                    $getTargetResourceResult.AutomatedBackupPreference | Should -Be 'Secondary'
                    $getTargetResourceResult.AvailabilityMode | Should -Be 'AsynchronousCommit'
                    $getTargetResourceResult.BackupPriority | Should -Be 50
                    $getTargetResourceResult.ConnectionModeInPrimaryRole | Should -Be 'AllowAllConnections'
                    $getTargetResourceResult.ConnectionModeInSecondaryRole | Should -Be 'AllowNoConnections'
                    $getTargetResourceResult.FailureConditionLevel | Should -Be 'OnCriticalServerError'
                    $getTargetResourceResult.FailoverMode | Should -Be 'Manual'
                    $getTargetResourceResult.HealthCheckTimeout | Should -BeNullOrEmpty
                    $getTargetResourceResult.EndpointURL | Should -Be 'TCP://Server2:5022'
                    $getTargetResourceResult.EndpointPort | Should -Be 5022
                    $getTargetResourceResult.EndpointHostName | Should -Be 'Server2'
                    $getTargetResourceResult.BasicAvailabilityGroup | Should -BeNullOrEmpty
                    $getTargetResourceResult.DatabaseHealthTrigger | Should -BeNullOrEmpty
                    $getTargetResourceResult.DtcSupportEnabled | Should -BeNullOrEmpty
                    $getTargetResourceResult.Version | Should -Be 12
                }
                Should -Invoke -CommandName Connect-SQL -Exactly -Times 1 -Scope It
            }
        }
    }
}

Describe 'SqlAG\Set-TargetResource' {
    BeforeAll {
        $mockConnectSqlServer1 = {
            # Mock the server object
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'Server1'
            $mockServerObject.NetName = 'Server1'
            $mockServerObject.DomainInstanceName = 'Server1'
            $mockServerObject.IsHadrEnabled = $true
            $mockServerObject.ServiceName = 'MSSQLSERVER'
            $mockServerObject.Version = @{
                Major = 13
            }

            # Mock the availability group replicas
            $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica1.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica1.BackupPriority = 50
            $mockAvailabilityGroupReplica1.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica1.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica1.EndpointUrl = 'TCP://Server1:5022'
            $mockAvailabilityGroupReplica1.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica1.Name = 'Server1'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingConnectionUrl = 'TCP://Server1.domain.com:1433'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica1.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica2 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica2.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica2.BackupPriority = 50
            $mockAvailabilityGroupReplica2.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica2.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica2.EndpointUrl = 'TCP://Server2:5022'
            $mockAvailabilityGroupReplica2.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica2.Name = 'Server2'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingConnectionUrl = 'TCP://Server2.domain.com:1433'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica2.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica3 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica3.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica3.BackupPriority = 50
            $mockAvailabilityGroupReplica3.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica3.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica3.EndpointUrl = 'TCP://Server3:5022'
            $mockAvailabilityGroupReplica3.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica3.Name = 'Server3'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingConnectionUrl = 'TCP://Server3.domain.com:1433'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica3.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            # Mock the availability groups
            $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
            $mockAvailabilityGroup1.Name = 'AG_AllServers'
            $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server2'
            $mockAvailabilityGroup1.LocalReplicaRole = 'Secondary'
            $mockAvailabilityGroup1.AutomatedBackupPreference = 'Secondary'
            $mockAvailabilityGroup1.BasicAvailabilityGroup = $true
            $mockAvailabilityGroup1.DatabaseHealthTrigger = $true
            $mockAvailabilityGroup1.DtcSupportEnabled = $true
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica2)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica3)

            $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

            $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
            $mockEndpoint.EndpointType = 'DatabaseMirroring'
            $mockEndpoint.Protocol = @{
                TCP = @{
                    ListenerPort = 5022
                }
            }

            $mockServerObject.Endpoints.Add($mockEndpoint)

            return $mockServerObject
        }

        $mockConnectSqlServer2 = {
            # Mock the server object
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'Server2'
            $mockServerObject.NetName = 'Server2'
            $mockServerObject.DomainInstanceName = 'Server2'
            $mockServerObject.IsHadrEnabled = $true
            $mockServerObject.ServiceName = 'MSSQLSERVER'
            $mockServerObject.Version = @{
                Major = 12
            }

            # Mock the availability group replicas
            $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica1.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica1.BackupPriority = 50
            $mockAvailabilityGroupReplica1.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica1.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica1.EndpointUrl = 'TCP://Server1:5022'
            $mockAvailabilityGroupReplica1.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica1.Name = 'Server1'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingConnectionUrl = 'TCP://Server1.domain.com:1433'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica1.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica2 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica2.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica2.BackupPriority = 50
            $mockAvailabilityGroupReplica2.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica2.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica2.EndpointUrl = 'TCP://Server2:5022'
            $mockAvailabilityGroupReplica2.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica2.Name = 'Server2'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingConnectionUrl = 'TCP://Server2.domain.com:1433'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica2.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica3 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica3.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica3.BackupPriority = 50
            $mockAvailabilityGroupReplica3.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica3.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica3.EndpointUrl = 'TCP://Server3:5022'
            $mockAvailabilityGroupReplica3.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica3.Name = 'Server3'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingConnectionUrl = 'TCP://Server3.domain.com:1433'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica3.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            # Mock the availability groups
            $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
            $mockAvailabilityGroup1.Name = 'AG_AllServers'
            $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server2'
            $mockAvailabilityGroup1.LocalReplicaRole = 'Secondary'
            $mockAvailabilityGroup1.AutomatedBackupPreference = 'Secondary'
            $mockAvailabilityGroup1.BasicAvailabilityGroup = $true
            $mockAvailabilityGroup1.DatabaseHealthTrigger = $true
            $mockAvailabilityGroup1.DtcSupportEnabled = $true
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica2)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica3)

            $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

            $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
            $mockEndpoint.EndpointType = 'DatabaseMirroring'
            $mockEndpoint.Protocol = @{
                TCP = @{
                    ListenerPort = 5022
                }
            }

            $mockServerObject.Endpoints.Add($mockEndpoint)

            return $mockServerObject
        }

        Mock -CommandName Connect-SQL -MockWith $mockConnectSqlServer1 -ParameterFilter {
            $ServerName -eq 'Server1'
        }
        Mock -CommandName Connect-SQL -MockWith $mockConnectSqlServer2 -ParameterFilter {
            $ServerName -eq 'Server2'
        }
        Mock -CommandName Get-PrimaryReplicaServerObject -MockWith $mockConnectSqlServer1 -ParameterFilter {
            $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server1'
        }

        Mock -CommandName Get-PrimaryReplicaServerObject -MockWith $mockConnectSqlServer2 -ParameterFilter {
            $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server2'
        }
        Mock -CommandName Test-ClusterPermissions
    }
    Context 'When the desired state is Absent' {
        BeforeAll {
            Mock -CommandName Remove-SqlAvailabilityGroup
        }
        Context 'When the availability group exists' {
            It 'Should silently remove the availability group' {
                InModuleScope -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name         = 'AG_AllServers'
                        ServerName   = 'Server2'
                        InstanceName = 'MSSQLSERVER'
                        Ensure       = 'Absent'
                    }

                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Remove-SqlAvailabilityGroup -Exactly -Times 1 -Scope It
            }
        }

        Context 'When the availability group exists but the current server is not primary' {
            It 'Should throw the correct error (NotPrimaryReplica)' {
                InModuleScope -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name         = 'AG_AllServers'
                        ServerName   = 'Server1'
                        InstanceName = 'MSSQLSERVER'
                        Ensure       = 'Absent'
                    }

                    $mockErrorMessage = Get-InvalidOperationRecord -Message ($script:localizedData.NotPrimaryReplica -f $setTargetResourceParameters.ServerName, $setTargetResourceParameters.Name, 'Server2')

                    { Set-TargetResource @setTargetResourceParameters } | Should -Throw -ExpectedMessage $mockErrorMessage
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Remove-SqlAvailabilityGroup -Exactly -Times 0 -Scope It
            }

        }

        Context 'When the removal of the availability group replica fails' {
            BeforeAll {
                Mock -CommandName Remove-SqlAvailabilityGroup -MockWith {
                    throw 'FailedRemoveAvailabilityGroup'
                }
            }

            It 'Should throw the correct error (FailedRemoveAvailabilityGroup)' {
                InModuleScope -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name         = 'AG_AllServers'
                        ServerName   = 'Server2'
                        InstanceName = 'MSSQLSERVER'
                        Ensure       = 'Absent'
                    }

                    $mockErrorMessage = Get-InvalidOperationRecord -Message (
                        # Adding wildcard at the end of string so Pester ignores additional messages in the error message (e.g. the string 'Mocked error')
                    ($script:localizedData.FailedRemoveAvailabilityGroup -f $setTargetResourceParameters.Name, $setTargetResourceParameters.InstanceName) + '*'
                    )

                    { Set-TargetResource @setTargetResourceParameters } | Should -Throw -ExpectedMessage $mockErrorMessage
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Remove-SqlAvailabilityGroup -Exactly -Times 1 -Scope It
            }
        }
    }

    Context 'When HADR is not enabled' {
        BeforeAll {
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'ServerNotEnabled'
            $mockServerObject.NetName = 'ServerNotEnabled'
            $mockServerObject.IsHadrEnabled = $false
            $mockServerObject.ServiceName = 'MSSQLSERVER'

            Mock -CommandName Connect-SQL -MockWith {
                return $mockServerObject
            } -ParameterFilter {
                $ServerName -eq 'ServerNotEnabled'
            }
        }

        It 'Should throw the correct error (HadrNotEnabled)' { # cSpell: disable-line
            InModuleScope -ScriptBlock {
                $setTargetResourceParameters = @{
                    Name         = 'AG_PrimaryOnServer2'
                    ServerName   = 'ServerNotEnabled'
                    InstanceName = 'MSSQLSERVER'
                }

                $mockErrorRecord = Get-InvalidOperationRecord -Message (
                    $script:localizedData.HadrNotEnabled # cSpell: disable-line
                )

                { Set-TargetResource @setTargetResourceParameters } | Should -Throw -ExpectedMessage $mockErrorRecord
            }

            Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                $ServerName -eq 'ServerNotEnabled'
            } -Times 1 -Exactly

        }
    }

    Context 'When the database mirroring endpoint is absent' {
        BeforeAll {
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'ServerWithoutEndpoint'
            $mockServerObject.NetName = 'ServerWithoutEndpoint'
            $mockServerObject.IsHadrEnabled = $true
            $mockServerObject.ServiceName = 'MSSQLSERVER'

            Mock -CommandName Connect-SQL -MockWith {
                return $mockServerObject
            } -ParameterFilter {
                $ServerName -eq 'ServerWithoutEndpoint'
            }
        }

        It 'Should throw the correct error (DatabaseMirroringEndpointNotFound)' {
            InModuleScope -ScriptBlock {
                $setTargetResourceParameters = @{
                    Name         = 'AG_PrimaryOnServer2'
                    ServerName   = 'ServerWithoutEndpoint'
                    InstanceName = 'MSSQLSERVER'
                }

                $mockErrorRecord = Get-ObjectNotFoundRecord -Message (
                    $script:localizedData.DatabaseMirroringEndpointNotFound -f 'ServerWithoutEndpoint\MSSQLSERVER'
                )

                { Set-TargetResource @setTargetResourceParameters } | Should -Throw -ExpectedMessage $mockErrorRecord
            }

            Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                $ServerName -eq 'ServerWithoutEndpoint'
            } -Times 1 -Exactly

        }
    }

    Context 'When the desired state is present and the availability group is absent' {
        BeforeAll {
            $mockReplicaObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockReplicaObject.AvailabilityMode = 'AsynchronousCommit'
            $mockReplicaObject.BackupPriority = 50
            $mockReplicaObject.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockReplicaObject.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockReplicaObject.EndpointUrl = 'TCP://Server1:5022'
            $mockReplicaObject.FailoverMode = 'Manual'
            $mockReplicaObject.Name = 'Server1'
            $mockReplicaObject.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            Mock -CommandName New-SqlAvailabilityReplica -MockWith {
                return $mockReplicaObject
            } -ParameterFilter {
                $Name -eq 'Server1'
            }
            Mock -CommandName Remove-SqlAvailabilityGroup
            Mock -CommandName New-SqlAvailabilityGroup
            Mock -CommandName Update-AvailabilityGroup
        }

        It 'Should create the availability group' {
            InModuleScope -ScriptBlock {
                $setTargetResourceParameters = @{
                    Name                          = 'AG_PrimaryOnServer2'
                    ServerName                    = 'Server1'
                    InstanceName                  = 'MSSQLSERVER'
                    Ensure                        = 'Present'
                    AvailabilityMode              = 'AsynchronousCommit'
                    BackupPriority                = 50
                    ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                    ConnectionModeInSecondaryRole = 'AllowNoConnections'
                    EndpointHostName              = 'Server1'
                    FailureConditionLevel         = 'OnServerUnresponsive'
                    FailoverMode                  = 'Manual'
                    SeedingMode                   = 'Manual'
                }

                { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw
            }

            Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                $ServerName -eq 'Server1'
            } -Times 1 -Exactly

            Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                $ServerName -eq 'Server2'
            } -Times 0 -Exactly

            Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server1'
            }

            Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server2'
            }

            Should -Invoke -CommandName New-SqlAvailabilityReplica -Exactly -Times 1 -Scope It
            Should -Invoke -CommandName New-SqlAvailabilityGroup -Exactly -Times 1 -Scope It
            Should -Invoke -CommandName Remove-SqlAvailabilityGroup -Scope It -Times 0 -Exactly
            Should -Invoke -CommandName Test-ClusterPermissions -Exactly -Times 1 -Scope It
            Should -Invoke -CommandName Update-AvailabilityGroup -Scope It -Times 0 -Exactly
        }

        Context 'When the endpoint hostname is not defined' {
            It 'Should create the availability group replica' {
                InModuleScope -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name                          = 'AG_PrimaryOnServer2'
                        ServerName                    = 'Server1'
                        InstanceName                  = 'MSSQLSERVER'
                        Ensure                        = 'Present'
                        AvailabilityMode              = 'AsynchronousCommit'
                        BackupPriority                = 50
                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                        ConnectionModeInSecondaryRole = 'AllowNoConnections'
                        EndpointHostName              = ''
                        FailoverMode                  = 'Manual'
                        SeedingMode                   = 'Manual'
                    }

                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server1'
                }

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server2'
                }

                Should -Invoke -CommandName New-SqlAvailabilityReplica -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName New-SqlAvailabilityGroup -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Remove-SqlAvailabilityGRoup -Scope It -Times 0 -Exactly
                Should -Invoke -CommandName Test-ClusterPermissions -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Update-AvailabilityGroup -Scope It -Times 0 -Exactly
            }
        }

        Context 'When the availability group replica fails to create' {
            BeforeAll {
                Mock -CommandName New-SqlAvailabilityReplica {
                    throw 'Mocked error'
                }
            }

            It 'Should throw the correct error' {
                InModuleScope -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name                          = 'AG_PrimaryOnServer2'
                        ServerName                    = 'Server2'
                        InstanceName                  = 'MSSQLSERVER'
                        Ensure                        = 'Present'
                        AvailabilityMode              = 'AsynchronousCommit'
                        BackupPriority                = 50
                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                        ConnectionModeInSecondaryRole = 'AllowNoConnections'
                        EndpointHostName              = ''
                        FailoverMode                  = 'Manual'
                        SeedingMode                   = 'Manual'
                    }

                    $mockErrorRecord = Get-InvalidOperationRecord -Message (
                        # Adding wildcard at the end of string so Pester ignores additional messages in the error message (e.g. the string 'Mocked error')
                        ($script:localizedData.FailedCreateAvailabilityGroupReplica -f $setTargetResourceParameters.ServerName, $setTargetResourceParameters.InstanceName) + '*'
                    )

                    { Set-TargetResource @setTargetResourceParameters } | Should -Throw -ExpectedMessage $mockErrorRecord
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server1'
                }

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server2'
                }

                Should -Invoke -CommandName New-SqlAvailabilityReplica -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName New-SqlAvailabilityGroup -Exactly -Times 0 -Scope It
                Should -Invoke -CommandName Remove-SqlAvailabilityGRoup -Scope It -Times 0 -Exactly
                Should -Invoke -CommandName Test-ClusterPermissions -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Update-AvailabilityGroup -Scope It -Times 0 -Exactly
            }
        }

        Context 'When the availability group fails to create' {
            BeforeAll {
                Mock -CommandName New-SqlAvailabilityGroup {
                    throw 'Mocked error'
                }
            }

            It 'Should throw the correct error' {
                InModuleScope -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name                          = 'AG_PrimaryOnServer2'
                        ServerName                    = 'Server1'
                        InstanceName                  = 'MSSQLSERVER'
                        Ensure                        = 'Present'
                        AvailabilityMode              = 'AsynchronousCommit'
                        BackupPriority                = 50
                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                        ConnectionModeInSecondaryRole = 'AllowNoConnections'
                        EndpointHostName              = ''
                        FailoverMode                  = 'Manual'
                        SeedingMode                   = 'Manual'
                    }

                    $mockErrorRecord = Get-InvalidOperationRecord -Message (
                        # Adding wildcard at the end of string so Pester ignores additional messages in the error message (e.g. the string 'Mocked error')
                        ($script:localizedData.FailedCreateAvailabilityGroup -f $setTargetResourceParameters.Name, $setTargetResourceParameters.InstanceName) + '*'
                    )

                    { Set-TargetResource @setTargetResourceParameters } | Should -Throw -ExpectedMessage $mockErrorRecord
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server1'
                }

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server2'
                }

                Should -Invoke -CommandName New-SqlAvailabilityReplica -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName New-SqlAvailabilityGroup -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Remove-SqlAvailabilityGRoup -Scope It -Times 0 -Exactly
                Should -Invoke -CommandName Test-ClusterPermissions -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Update-AvailabilityGroup -Scope It -Times 0 -Exactly
            }
        }
    }

    Context 'When the desired state is present and the availability group is present' {
        Context 'When Availability Group property <MockPropertyName> is not in desired state' -ForEach @(
            @{
                MockPropertyName  = 'AutomatedBackupPreference'
                MockPropertyValue = 'None'
            }
            @{
                MockPropertyName  = 'FailureConditionLevel'
                MockPropertyValue = 'OnAnyQualifiedFailureCondition'
            }
            @{
                MockPropertyName  = 'HealthCheckTimeout'
                MockPropertyValue = 10
            }
            @{
                MockPropertyName  = 'BasicAvailabilityGroup'
                MockPropertyValue = $false
            }
            @{
                MockPropertyName  = 'DatabaseHealthTrigger'
                MockPropertyValue = $false
            }
            @{
                MockPropertyName  = 'DtcSupportEnabled'
                MockPropertyValue = $false
            }
        ) {
            BeforeAll {
                Mock -CommandName Remove-SqlAvailabilityGroup
                Mock -CommandName Update-AvailabilityGroup
                Mock -CommandName New-SqlAvailabilityReplica
                Mock -CommandName New-SqlAvailabilityGroup
                Mock -CommandName Update-AvailabilityGroupReplica
            }

            It 'Should set the property to the desired state' {
                InModuleScope -Parameters $_ -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name                          = 'AG_AllServers'
                        ServerName                    = 'Server1'
                        InstanceName                  = 'MSSQLSERVER'
                        Ensure                        = 'Present'
                        AvailabilityMode              = 'AsynchronousCommit'
                        BackupPriority                = 50
                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                        ConnectionModeInSecondaryRole = 'AllowNoConnections'
                        EndpointHostName              = 'Server1'
                        FailoverMode                  = 'Manual'
                        SeedingMode                   = 'Manual'
                    }

                    $setTargetResourceParameters.$MockPropertyName = $MockPropertyValue

                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server1'
                }

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 1 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server2'
                }


                Should -Invoke -CommandName New-SqlAvailabilityReplica -Exactly -Times 0 -Scope It
                Should -Invoke -CommandName New-SqlAvailabilityGroup -Exactly -Times 0 -Scope It
                Should -Invoke -CommandName Remove-SqlAvailabilityGRoup -Scope It -Times 0 -Exactly
                Should -Invoke -CommandName Test-ClusterPermissions -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Update-AvailabilityGroup -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Update-AvailabilityGroupReplica -Exactly -Times 0 -Scope It
            }
        }

        Context 'When Availability Group replica property <MockPropertyName> is not in desired state' -ForEach @(
            @{
                MockPropertyName  = 'AvailabilityMode'
                MockPropertyValue = 'SynchronousCommit'
            }
            @{
                MockPropertyName  = 'BackupPriority'
                MockPropertyValue = 60
            }
            @{
                MockPropertyName  = 'ConnectionModeInPrimaryRole'
                MockPropertyValue = 'AllowReadWriteConnections'
            }
            @{
                MockPropertyName  = 'ConnectionModeInSecondaryRole'
                MockPropertyValue = 'AllowReadIntentConnectionsOnly'
            }
            @{
                MockPropertyName  = 'FailoverMode'
                MockPropertyValue = 'Automatic'
            }
            @{
                MockPropertyName  = 'EndpointHostName'
                MockPropertyValue = 'Server2'
            }
            @{
                MockPropertyName  = 'SeedingMode'
                MockPropertyValue = 'Automatic'
            }
        ) {
            BeforeAll {
                Mock -CommandName Remove-SqlAvailabilityGroup
                Mock -CommandName Update-AvailabilityGroup
                Mock -CommandName New-SqlAvailabilityReplica
                Mock -CommandName New-SqlAvailabilityGroup
                Mock -CommandName Update-AvailabilityGroupReplica
            }

            It 'Should set the property to the desired state' {
                InModuleScope -Parameters $_ -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name                          = 'AG_AllServers'
                        ServerName                    = 'Server1'
                        InstanceName                  = 'MSSQLSERVER'
                        Ensure                        = 'Present'
                        AvailabilityMode              = 'AsynchronousCommit'
                        BackupPriority                = 50
                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                        ConnectionModeInSecondaryRole = 'AllowNoConnections'
                        EndpointHostName              = 'Server1'
                        FailoverMode                  = 'Manual'
                        SeedingMode                   = 'Manual'
                    }

                    $setTargetResourceParameters.$MockPropertyName = $MockPropertyValue

                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw
                }

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server1'
                } -Times 1 -Exactly

                Should -Invoke -CommandName Connect-SQL -Scope It -ParameterFilter {
                    $ServerName -eq 'Server2'
                } -Times 0 -Exactly

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 0 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server1'
                }

                Should -Invoke -CommandName Get-PrimaryReplicaServerObject -Scope It -Time 1 -Exactly -ParameterFilter {
                    $AvailabilityGroup.PrimaryReplicaServerName -eq 'Server2'
                }


                Should -Invoke -CommandName New-SqlAvailabilityReplica -Exactly -Times 0 -Scope It
                Should -Invoke -CommandName New-SqlAvailabilityGroup -Exactly -Times 0 -Scope It
                Should -Invoke -CommandName Remove-SqlAvailabilityGRoup -Scope It -Times 0 -Exactly
                Should -Invoke -CommandName Test-ClusterPermissions -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Update-AvailabilityGroup -Exactly -Times 0 -Scope It
                Should -Invoke -CommandName Update-AvailabilityGroupReplica -Exactly -Times 1 -Scope It
            }
        }

        Context 'When the endpoint port differ from the port in the replica''s endpoint URL' {
            BeforeAll {
                Mock -CommandName Update-AvailabilityGroupReplica

                Mock -CommandName Connect-Sql -ParameterFilter {
                    $ServerName -eq 'Server10'
                } -MockWith {
                    # Mock the server object
                    $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
                    $mockServerObject.Name = 'Server10'
                    $mockServerObject.NetName = 'Server10'
                    $mockServerObject.IsHadrEnabled = $true
                    $mockServerObject.ServiceName = 'MSSQLSERVER'
                    $mockServerObject.DomainInstanceName = 'Server10'

                    # Mock the availability group replicas
                    $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
                    $mockAvailabilityGroupReplica1.EndpointUrl = 'TCP://Server10:1234'
                    $mockAvailabilityGroupReplica1.Name = 'Server10'

                    # Mock the availability groups
                    $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
                    $mockAvailabilityGroup1.Name = 'AG_AllServers'
                    $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server10'
                    $mockAvailabilityGroup1.LocalReplicaRole = 'Primary'
                    $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
                    $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

                    $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
                    $mockEndpoint.EndpointType = 'DatabaseMirroring'
                    $mockEndpoint.Protocol = @{
                        TCP = @{
                            ListenerPort = 5022
                        }
                    }

                    $mockServerObject.Endpoints.Add($mockEndpoint)

                    return $mockServerObject
                }
            }

            It 'Should set the replica''s endpoint URL to use the same port as the endpoint' {
                InModuleScope -Parameters $_ -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name             = 'AG_AllServers'
                        ServerName       = 'Server10'
                        InstanceName     = 'MSSQLSERVER'
                        Ensure           = 'Present'
                        EndpointHostName = 'Server10'
                    }

                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw
                }

                Should -Invoke -CommandName Update-AvailabilityGroupReplica -Exactly -Times 1 -Scope It
            }
        }

        Context 'When the endpoint protocol differ from the protocol in the replica''s endpoint URL' {
            BeforeAll {
                Mock -CommandName Update-AvailabilityGroupReplica

                Mock -CommandName Connect-Sql -ParameterFilter {
                    $ServerName -eq 'Server10'
                } -MockWith {
                    # Mock the server object
                    $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
                    $mockServerObject.Name = 'Server10'
                    $mockServerObject.NetName = 'Server10'
                    $mockServerObject.IsHadrEnabled = $true
                    $mockServerObject.ServiceName = 'MSSQLSERVER'
                    $mockServerObject.DomainInstanceName = 'Server10'

                    # Mock the availability group replicas
                    $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
                    $mockAvailabilityGroupReplica1.EndpointUrl = 'UDP://Server10:5022'
                    $mockAvailabilityGroupReplica1.Name = 'Server10'

                    # Mock the availability groups
                    $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
                    $mockAvailabilityGroup1.Name = 'AG_AllServers'
                    $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server10'
                    $mockAvailabilityGroup1.LocalReplicaRole = 'Primary'
                    $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
                    $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

                    $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
                    $mockEndpoint.EndpointType = 'DatabaseMirroring'
                    $mockEndpoint.Protocol = @{
                        TCP = @{
                            ListenerPort = 5022
                        }
                    }

                    $mockServerObject.Endpoints.Add($mockEndpoint)

                    return $mockServerObject
                }
            }

            It 'Should set the replica''s endpoint URL to use the same port as the endpoint' {
                InModuleScope -Parameters $_ -ScriptBlock {
                    $setTargetResourceParameters = @{
                        Name             = 'AG_AllServers'
                        ServerName       = 'Server10'
                        InstanceName     = 'MSSQLSERVER'
                        Ensure           = 'Present'
                        EndpointHostName = 'Server10'
                    }

                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw
                }

                Should -Invoke -CommandName Update-AvailabilityGroupReplica -Exactly -Times 1 -Scope It
            }
        }
    }
}

Describe 'SqlAG\Test-TargetResource' {
    BeforeAll {
        $mockConnectSqlServer1 = {
            # Mock the server object
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'Server1'
            $mockServerObject.NetName = 'Server1'
            $mockServerObject.DomainInstanceName = 'Server1'
            $mockServerObject.IsHadrEnabled = $true
            $mockServerObject.ServiceName = 'MSSQLSERVER'
            $mockServerObject.Version = @{
                Major = 13
            }

            # Mock the availability group replicas
            $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica1.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica1.BackupPriority = 50
            $mockAvailabilityGroupReplica1.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica1.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica1.EndpointUrl = 'TCP://Server1:5022'
            $mockAvailabilityGroupReplica1.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica1.Name = 'Server1'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingConnectionUrl = 'TCP://Server1.domain.com:1433'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica1.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica2 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica2.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica2.BackupPriority = 50
            $mockAvailabilityGroupReplica2.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica2.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica2.EndpointUrl = 'TCP://Server2:5022'
            $mockAvailabilityGroupReplica2.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica2.Name = 'Server2'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingConnectionUrl = 'TCP://Server2.domain.com:1433'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica2.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica3 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica3.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica3.BackupPriority = 50
            $mockAvailabilityGroupReplica3.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica3.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica3.EndpointUrl = 'TCP://Server3:5022'
            $mockAvailabilityGroupReplica3.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica3.Name = 'Server3'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingConnectionUrl = 'TCP://Server3.domain.com:1433'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica3.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            # Mock the availability groups
            $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
            $mockAvailabilityGroup1.Name = 'AG_AllServers'
            $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server2'
            $mockAvailabilityGroup1.LocalReplicaRole = 'Secondary'
            $mockAvailabilityGroup1.AutomatedBackupPreference = 'Secondary'
            $mockAvailabilityGroup1.BasicAvailabilityGroup = $true
            $mockAvailabilityGroup1.DatabaseHealthTrigger = $true
            $mockAvailabilityGroup1.DtcSupportEnabled = $true
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica2)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica3)

            $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

            $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
            $mockEndpoint.EndpointType = 'DatabaseMirroring'
            $mockEndpoint.Protocol = @{
                TCP = @{
                    ListenerPort = 5022
                }
            }

            $mockServerObject.Endpoints.Add($mockEndpoint)

            return $mockServerObject
        }

        $mockConnectSqlServer2 = {
            # Mock the server object
            $mockServerObject = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server
            $mockServerObject.Name = 'Server2'
            $mockServerObject.NetName = 'Server2'
            $mockServerObject.DomainInstanceName = 'Server2'
            $mockServerObject.IsHadrEnabled = $true
            $mockServerObject.ServiceName = 'MSSQLSERVER'
            $mockServerObject.Version = @{
                Major = 12
            }

            # Mock the availability group replicas
            $mockAvailabilityGroupReplica1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica1.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica1.BackupPriority = 50
            $mockAvailabilityGroupReplica1.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica1.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica1.EndpointUrl = 'TCP://Server1:5022'
            $mockAvailabilityGroupReplica1.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica1.Name = 'Server1'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingConnectionUrl = 'TCP://Server1.domain.com:1433'
            $mockAvailabilityGroupReplica1.ReadOnlyRoutingList = @('Server1', 'Server2')

            $mockAvailabilityGroupReplica2 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica2.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica2.BackupPriority = 50
            $mockAvailabilityGroupReplica2.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica2.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica2.EndpointUrl = 'TCP://Server2:5022'
            $mockAvailabilityGroupReplica2.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica2.Name = 'Server2'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingConnectionUrl = 'TCP://Server2.domain.com:1433'
            $mockAvailabilityGroupReplica2.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica2.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            $mockAvailabilityGroupReplica3 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica
            $mockAvailabilityGroupReplica3.AvailabilityMode = 'AsynchronousCommit'
            $mockAvailabilityGroupReplica3.BackupPriority = 50
            $mockAvailabilityGroupReplica3.ConnectionModeInPrimaryRole = 'AllowAllConnections'
            $mockAvailabilityGroupReplica3.ConnectionModeInSecondaryRole = 'AllowNoConnections'
            $mockAvailabilityGroupReplica3.EndpointUrl = 'TCP://Server3:5022'
            $mockAvailabilityGroupReplica3.FailoverMode = 'Manual'
            $mockAvailabilityGroupReplica3.Name = 'Server3'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingConnectionUrl = 'TCP://Server3.domain.com:1433'
            $mockAvailabilityGroupReplica3.ReadOnlyRoutingList = @('Server1', 'Server2')
            $mockAvailabilityGroupReplica3.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Manual

            # Mock the availability groups
            $mockAvailabilityGroup1 = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup
            $mockAvailabilityGroup1.Name = 'AG_AllServers'
            $mockAvailabilityGroup1.PrimaryReplicaServerName = 'Server2'
            $mockAvailabilityGroup1.LocalReplicaRole = 'Secondary'
            $mockAvailabilityGroup1.AutomatedBackupPreference = 'Secondary'
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica1)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica2)
            $mockAvailabilityGroup1.AvailabilityReplicas.Add($mockAvailabilityGroupReplica3)

            $mockServerObject.AvailabilityGroups.Add($mockAvailabilityGroup1)

            $mockEndpoint = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Endpoint
            $mockEndpoint.EndpointType = 'DatabaseMirroring'
            $mockEndpoint.Protocol = @{
                TCP = @{
                    ListenerPort = 5022
                }
            }

            $mockServerObject.Endpoints.Add($mockEndpoint)

            return $mockServerObject
        }

        Mock -CommandName Connect-SQL -MockWith $mockConnectSqlServer1 -ParameterFilter {
            $ServerName -eq 'Server1'
        }
        Mock -CommandName Connect-SQL -MockWith $mockConnectSqlServer2 -ParameterFilter {
            $ServerName -eq 'Server2'
        }
    }
    Context 'When the system is in the desired state' {
        Context 'When the Availability Group should be absent' {
            It 'Should return $true' {
                InModuleScope -ScriptBlock {
                    $testTargetResourceParameters = @{
                        Name         = 'AbsentAG'
                        ServerName   = 'Server1'
                        InstanceName = 'MSSQLSERVER'
                        Ensure       = 'Absent'
                    }
                    Test-TargetResource @testTargetResourceParameters | Should -BeTrue
                }
                Should -Invoke -CommandName Connect-SQL -Exactly -Times 1
            }
        }
        Context 'When the Availability Group should be present' {
            It 'Should return $true' {
                InModuleScope -ScriptBlock {
                    $testTargetResourceParameters = @{
                        Name         = 'AG_AllServers'
                        ServerName   = 'Server1'
                        InstanceName = 'MSSQLSERVER'
                        Ensure       = 'Present'
                    }
                    Test-TargetResource @testTargetResourceParameters | Should -BeTrue
                }
                Should -Invoke -CommandName Connect-SQL -Exactly -Times 1
            }
        }
    }

    Context 'When the system is not in the desired state' {
        Context 'When the Availability Group should be absent' {
            It 'Should return $false' {
                InModuleScope -ScriptBlock {
                    $testTargetResourceParameters = @{
                        Name         = 'AG_AllServers'
                        ServerName   = 'Server1'
                        InstanceName = 'MSSQLSERVER'
                        Ensure       = 'Absent'
                    }
                    Test-TargetResource @testTargetResourceParameters | Should -BeFalse
                }
                Should -Invoke -CommandName Connect-SQL -Exactly -Times 1
            }
        }
        Context 'When the Availability Group should be present' {
            It 'Should return $false' {
                InModuleScope -ScriptBlock {
                    $testTargetResourceParameters = @{
                        Name         = 'AbsentAG'
                        ServerName   = 'Server1'
                        InstanceName = 'MSSQLSERVER'
                    }
                    Test-TargetResource @testTargetResourceParameters | Should -BeFalse
                }
                Should -Invoke -CommandName Connect-SQL -Exactly -Times 1
            }
        }
    }

    Context 'When enforcing the state shall happen only when the node is the active node' {
        BeforeAll {
            Mock -CommandName Get-TargetResource -MockWith {
                @{
                    Name         = 'AG_AllServers'
                    ServerName   = 'Server1'
                    InstanceName = 'MSSQLSERVER'
                    Ensure       = 'Present'
                    EndpointPort = '5022'
                    EndpointUrl  = 'TCP://Server1:5022'
                    IsActiveNode = $false
                }
            }
        }

        It 'Should return $true' {
            InModuleScope -ScriptBlock {
                $testTargetResourceParameters = @{
                    Ensure                  = 'Absent'
                    Name                    = 'AG_AllServers'
                    ServerName              = 'Server1'
                    InstanceName            = 'MSSQLSERVER'
                    ProcessOnlyOnActiveNode = $true
                }

                Test-TargetResource @testTargetResourceParameters | Should -BeTrue
            }

            Should -Invoke -CommandName Get-TargetResource -Exactly -Times 1 -Scope It
        }
    }

    Context 'When property <MockPropertyName> is not in desired state' -ForEach @(
        @{
            MockPropertyName  = 'AutomatedBackupPreference'
            MockPropertyValue = 'None'
        }
        @{
            MockPropertyName  = 'AvailabilityMode'
            MockPropertyValue = 'SynchronousCommit'
        }
        @{
            MockPropertyName  = 'BackupPriority'
            MockPropertyValue = 60
        }
        @{
            MockPropertyName  = 'ConnectionModeInPrimaryRole'
            MockPropertyValue = 'AllowReadWriteConnections'
        }
        @{
            MockPropertyName  = 'ConnectionModeInSecondaryRole'
            MockPropertyValue = 'AllowReadIntentConnectionsOnly'
        }
        @{
            MockPropertyName  = 'FailureConditionLevel'
            MockPropertyValue = 'OnAnyQualifiedFailureCondition'
        }
        @{
            MockPropertyName  = 'FailoverMode'
            MockPropertyValue = 'Automatic'
        }
        @{
            MockPropertyName  = 'HealthCheckTimeout'
            MockPropertyValue = 10
        }
        @{
            MockPropertyName  = 'EndpointHostName'
            MockPropertyValue = 'Server2'
        }
        @{
            MockPropertyName  = 'BasicAvailabilityGroup'
            MockPropertyValue = $false
        }
        @{
            MockPropertyName  = 'DatabaseHealthTrigger'
            MockPropertyValue = $false
        }
        @{
            MockPropertyName  = 'DtcSupportEnabled'
            MockPropertyValue = $false
        }
        @{
            MockPropertyName  = 'SeedingMode'
            MockPropertyValue = 'Automatic'
        }
    ) {
        It 'Should return $false' {
            InModuleScope -Parameters $_ -ScriptBlock {
                $testTargetResourceParameters = @{
                    Name                    = 'AG_AllServers'
                    ServerName              = 'Server1'
                    InstanceName            = 'MSSQLSERVER'
                    ProcessOnlyOnActiveNode = $true
                }

                $testTargetResourceParameters.$MockPropertyName = $MockPropertyValue

                Test-TargetResource @testTargetResourceParameters | Should -BeFalse
            }

            Should -Invoke -CommandName Connect-SQL -Exactly -Times 1
        }
    }
    Context 'When endpoint port differ from the endpoint URL port' {
        BeforeAll {
            Mock -CommandName Get-TargetResource -MockWith {
                @{
                    Name         = 'AG_AllServers'
                    ServerName   = 'Server1'
                    InstanceName = 'MSSQLSERVER'
                    Ensure       = 'Present'

                    # Read properties
                    EndpointPort = '5022'
                    EndpointUrl  = 'TCP://Server1:1433'
                    IsActiveNode = $true
                }
            }
        }

        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                $testTargetResourceParameters = @{
                    Name                    = 'AG_AllServers'
                    ServerName              = 'Server1'
                    InstanceName            = 'MSSQLSERVER'
                    ProcessOnlyOnActiveNode = $true
                }

                Test-TargetResource @testTargetResourceParameters | Should -BeFalse
            }

            Should -Invoke -CommandName Get-TargetResource -Exactly -Times 1 -Scope It
        }
    }

    Context 'When endpoint protocol differ from the endpoint URL protocol' {
        BeforeAll {
            Mock -CommandName Get-TargetResource -MockWith {
                @{
                    Name         = 'AG_AllServers'
                    ServerName   = 'Server1'
                    InstanceName = 'MSSQLSERVER'
                    Ensure       = 'Present'

                    # Read properties
                    EndpointPort = '5022'
                    EndpointUrl  = 'UDP://Server1:5022'
                    IsActiveNode = $true
                }
            }
        }

        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                $testTargetResourceParameters = @{
                    Name                    = 'AG_AllServers'
                    ServerName              = 'Server1'
                    InstanceName            = 'MSSQLSERVER'
                    ProcessOnlyOnActiveNode = $true
                }

                Test-TargetResource @testTargetResourceParameters | Should -BeFalse
            }

            Should -Invoke -CommandName Get-TargetResource -Exactly -Times 1 -Scope It
        }
    }
}
