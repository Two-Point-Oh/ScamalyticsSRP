#================================================#
# LogRhythm SmartResponse Plugin                 #
# Scamalytics - SmartResponse   				 #
# LogRhythm Community DosPuntoCero               #
# v1  --  Jan, 2023                              #
#================================================#

[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True)]
   [string]$IpAddress,
   [Parameter(Mandatory=$False)]
   [string]$Test
)

# Trap for an exception during the script
Trap [Exception]
{
    if($PSItem.ToString() -eq "ExecutionFailure")
	{
		exit 1
	}
    else
	{
		Write-Error $("Trapped: $_")
		Write-Output "Aborting Operation."
		exit
	}
}

# Function to Disable SSL Certificate Error and Enable Tls12

function Disable-SSLError
{
	# Disabling SSL certificate error
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


    # Forcing to use TLS1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

	#Function to Call the Scamalytics API
function ApiCall {

	Try {
		
		$ApiCallUri = $BaseUrl + "&ip=$IpAddress"
		
		if ($Test){
			$ApiCallUri += "&test=1"
		}
	
		$Output = Invoke-RestMethod -Uri $ApiCallUri
		#$Output = (Invoke-WebRequest -Uri $ApiCallUri).Content.split(',')
		
		Write-Output $Output
				
	} Catch {
		
		Write-Output "Unexpected Error/Response"
		Write-Error "Trapped: $_"
		Throw "ExecutionFailure"
	
	}
}

function Get-ConfigFileData([string]$FilePath) {
	try{
		if (!(Test-Path -Path $FilePath)){
			Write-Error "Error: Config File Not Found. Please run 'Create Configuration File' action."
			throw "Configurion File Not Found"
		}
		else{
			$ConfigFileContent = Import-Clixml -Path $FilePath

	        #Convert PSObject into HashTable
            $ConfigContent = @{}
            $ConfigFileContent.psobject.properties | ForEach-Object { $ConfigContent[$_.Name] = $_.Value }

            #Create a hashtable for configuration file content
            $ConfigHash = @{}
            $ConfigContent.Keys | ForEach-Object {
                $key = $_
                $keyvalue = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConfigContent.$key))
                $ConfigHash.Add($key, $keyvalue)
            }
            return $ConfigHash
        }
	}
	catch{
		$message = $_.Exception.message
		if($message -eq "Configuration File Not Found"){
			throw "ConfigurationFileNotFound"
		}
		else{
			Write-Error $message
			throw "ExecutionFailure"
		}
	}
}

function CheckIp([string]$ip){
	if ($ip -eq '0.0.0.0'){
		Write-Output "$ip`? Really?"
		Exit 0
	}
	if (($ip -match '^10\.') -or ($ip -match '^172\.(1[7-9]{1}|2\d|3(0|1))\.') -or ($ip -match '^192\.168\.')){
		Write-Output "$ip is a private IP address."
		Exit 0
	}
	
	$ip.split('.') | %{
		if (([int]$_) -gt 255){
			Write-Output "$ip is not a valid IP Address"
			Exit 0
		}
	}
}

Disable-SSLError

CheckIp $IpAddress

$ConfigurationFilePath = "C:\Program Files\LogRhythm\SmartResponse Plugins\ScamalyticsConfigFile.xml"

Try {
    $ConfigItems = Get-ConfigFileData -FilePath $ConfigurationFilePath
} Catch {
    If ( $_.Exception.Message -eq "ConfigurationFileNotFound" ) {
        Write-Output "Config File Not Found. Please run 'Create Configuration File' action."
		throw "ExecutionFailure"
    } Else {
        Write-Output "User does not have access to Config File."
		throw "ExecutionFailure"
    }
}

# Call function

	$BaseUrl = $ConfigItems.BaseUrl
	$BaseUrl = $BaseUrl.Trim()
	
	ApiCall
