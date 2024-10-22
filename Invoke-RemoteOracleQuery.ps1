function Invoke-RemoteOracleQuery {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RemoteComputer,

        [Parameter(Mandatory = $true)]
        [string]$SqlQuery,

        [Parameter(Mandatory = $true)]
        [string]$DataSource,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$OracleCredential,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    # Script block to run on the remote machine
    $ScriptBlock = {
        param($SqlQuery, $DataSource, $OracleCredential)

        try {
            # Attempt to load the Oracle Data Provider
            Add-Type -AssemblyName 'Oracle.ManagedDataAccess' -ErrorAction Stop
        } catch {
            Write-Error "Failed to load Oracle.ManagedDataAccess assembly. Ensure that the Oracle Data Provider for .NET is installed on the remote machine."
            return
        }

        try {
            # Extract credentials
            $securePassword = $OracleCredential.Password
            $unsecurePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            )
            $userId = $OracleCredential.UserName

            # Build the Oracle connection string using the secure credentials
            $OracleConnectionString = "Data Source=$DataSource;User Id=$userId;Password=$unsecurePassword;"

            # Create and open the Oracle connection
            $connection = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($OracleConnectionString)
            $connection.Open()

            # Create and execute the Oracle command
            $command = $connection.CreateCommand()
            $command.CommandText = $SqlQuery
            $reader = $command.ExecuteReader()

            $results = @()
            while ($reader.Read()) {
                $row = @{}
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    $columnName = $reader.GetName($i)
                    $row[$columnName] = $reader.GetValue($i)
                }
                $results += [PSCustomObject]$row
            }

            # Clean up
            $reader.Close()
            $connection.Close()

            # Return the results
            return $results
        } catch {
            Write-Error "An error occurred while executing the SQL query: $_"
        }
    }

    # Invoke the script block on the remote computer
    if ($Credential) {
        Invoke-Command -ComputerName $RemoteComputer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $SqlQuery, $DataSource, $OracleCredential
    } else {
        Invoke-Command -ComputerName $RemoteComputer -ScriptBlock $ScriptBlock -ArgumentList $SqlQuery, $DataSource, $OracleCredential
    }
}
