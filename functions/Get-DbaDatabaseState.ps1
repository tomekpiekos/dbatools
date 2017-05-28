Function Get-DbaDatabaseState {
<#
.SYNOPSIS
Gets various options for databases, hereby called "states"

.DESCRIPTION
Gets some common "states" on databases:
 - "RW" options : READ_ONLY or READ_WRITE
 - "Status" options : ONLINE, OFFLINE, EMERGENCY
 - "Access" options : SINGLE_USER, RESTRICTED_USER, MULTI_USER

Returns an object with SqlInstance, Database, RW, Status, Access

.PARAMETER SqlInstance
The SQL Server that you're connecting to

.PARAMETER SqlCredential
Credential object used to connect to the SQL Server as a different user

.PARAMETER Database
The database(s) to process - this list is autopopulated from the server. If unspecified, all databases will be processed.

.PARAMETER ExcludeDatabase
The database(s) to exclude - this list is autopopulated from the server

.NOTES
Author: niphlod
Website: https://dbatools.io
Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

.LINK
https://dbatools.io/Get-DbaDatabaseState

.EXAMPLE
Get-DbaDatabaseState -SqlInstance sqlserver2014a

Gets options for all databases of the sqlserver2014a instance

.EXAMPLE
Get-DbaDatabaseState -SqlInstance sqlserver2014a -Database HR, Accounting

Gets options for both HR and Accounting database of the sqlserver2014a instance

.EXAMPLE
Get-DbaDatabaseState -SqlInstance sqlserver2014a -Exclude HR

Gets options for all databases of the sqlserver2014a instance except HR

.EXAMPLE
'sqlserver2014a', 'sqlserver2014b' | Get-DbaDatabaseState

Gets options for all databases of sqlserver2014a and sqlserver2014b instances

#>
	[CmdletBinding()]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstanceParameter[]]$SqlInstance,
		[Alias("Credential")]
		[PSCredential][System.Management.Automation.CredentialAttribute()]
		$SqlCredential,
		[Alias("Databases")]
		[object[]]$Database,
		[object[]]$Exclude
	)
	
	begin {
		$UserAccessHash = @{
			'Single' = 'SINGLE_USER'
			'Restricted' = 'RESTRICTED_USER'
			'Multiple' = 'MULTI_USER'
		}
		$ReadOnlyHash = @{
			$true = 'READ_ONLY'
			$false = 'READ_WRITE'
		}
		$StatusHash = @{
			'Offline' = 'OFFLINE'
			'Normal' = 'ONLINE'
			'EmergencyMode' = 'EMERGENCY'
		}
		
		function Get-DbState($db) {
			$base = [PSCustomObject]@{
				'Access' = ''
				'Status' = ''
				'RW' = ''
			}
			$base.RW = $ReadOnlyHash[$db.ReadOnly]
			$base.Access = $UserAccessHash[$db.UserAccess.toString()]
			foreach ($status in $StatusHash.Keys) {
				if ($db.Status -match $status) {
					$base.Status = $StatusHash[$status]
					break
				}
			}
			return $base
		}
		
	}
	process {
		foreach ($instance in $SqlInstance) {
			Write-Verbose "Connecting to $instance"
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential
			}
			catch {
				Write-Warning "Can't connect to $instance"
				Continue
			}
			$all_dbs = $server.Databases
			$dbs = $all_dbs | Where-Object { @('master', 'model', 'msdb', 'tempdb', 'distribution') -notcontains $_.Name }
			
			if ($database.count -gt 0) {
				$dbs = $dbs | Where-Object { $database -contains $_.Name }
			}
			if ($exclude.count -gt 0) {
				$dbs = $dbs | Where-Object { $exclude -notcontains $_.Name }
			}
			foreach ($db in $dbs) {
				$db_status = Get-DbState $db
				
				[PSCustomObject]@{
					SqlInstance = $server.Name
					InstanceName = $server.ServiceName
					ComputerName = $server.NetName
					DatabaseName = $db.Name
					RW = $db_status.RW
					Status = $db_status.Status
					Access = $db_status.Access
					Database = $db
				} | Select-DefaultView -ExcludeProperty Database
			}
		}
	}
}

