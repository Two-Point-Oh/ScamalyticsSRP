# Requires -Version 3.0
# 
# This Script is used to configure fixed parameters for a plugin so as they need not to be provided everytime while executing an action.
#
# Use Case -> 
# Configure Fixed parameters in a one time script run. For Ex API Key, Username, Password
# Store parameter values in encrypted form.
# 
#==========================================#
# LogRhythm SmartResponse Plugin           #
# SmartResponse Configure File             #
# Sakshi.Rawal@logrhythm.com               #
# V1.0  --  October, 2020                  #
#Modified by DosPuntoCero 4 Scamalytics SRP#
#==========================================#



[CmdletBinding()] 
Param( 
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()]
[string]$UserName, 
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()]
[string]$ApiKey,
[string]$ApiUrl
)


$ErrorActionPreference = "Stop"
# Trap for an exception during the script
Trap [Exception]
{
    if($PSItem.ToString() -eq "ExecutionFailure")
	{
		exit 1
	}
	elseif($PSItem.ToString() -eq "ExecutionSuccess")
	{
		exit
	}
	else
	{
		write-error $("Trapped: $_")
		Write-Output "Aborting Operation."
		exit
	}
}


# Function to Check and Create SmartResponse Directory
function CreateSRPDirectory
{
	if (!(Test-Path -Path $ConfigurationDirectoryPath))
	{
		New-Item -ItemType "directory" -Path $ConfigurationDirectoryPath -Force | Out-null
	}
}


# Function to Check and Create SmartResponse Config File

function CheckConfigFile
{
	if (!(Test-Path -Path $ConfigurationFilePath))
	{
		New-Item -ItemType "file" -Path $ConfigurationFilePath -Force | Out-null
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


#Function to validate Scamalytics Parameters
function ValidateInputs{
    $Url = $BaseURL+"&ip=31.167.131.204&test=1"
        
    try
	{
		$Status = (Invoke-RestMethod -Uri $Url).status
    }
	catch
	{
        $ExceptionMessage = $_.Exception.Message      
		if ($ExceptionMessage -eq "The remote server returned an error: (404) Not Found."){
			Write-Output $ExceptionMessage
			Write-Output "Most likely this is an invalid API Key\UserName combination."
			Exit 
		}
        else{
            Write-Output $ExceptionMessage
            Exit
        }
	}   

    return $Status
}


# Function to encrypt the value
function CreateHashtable
{
	$HashTable = [PSCustomObject]@{ 
								"BaseURL" = $SecureBaseURL
						}
	return $HashTable					
}

# Function to Create Hashtable for the url
function CreateConfigFile
{
	CreateHashtable | Export-Clixml -Path $ConfigurationFilePath
	Write-Output "Validations Passed."
	Write-Output "Configuration Parameters saved for Scamalytics."
}


$ConfigurationDirectoryPath = "C:\Program Files\LogRhythm\SmartResponse Plugins"
$ConfigurationFilePath = "C:\Program Files\LogRhythm\SmartResponse Plugins\ScamalyticsConfigFile.xml"

$UserName = $UserName.trim()
$ApiKey = $ApiKey.trim()
if ($ApiUrl -match '\w+'){
	$Url = $ApiUrl.trim()
	$Url = $Url.trim('/')
	$Url = $Url -replace '^https:\/\/',''
}else{
	$Url = "api11.scamalytics.com"
}
$BaseUrl = "https://$Url/$UserName/?key=$ApiKey"

CreateSRPDirectory
CheckConfigFile
Disable-SSLError

$ReturnArray = ValidateInputs

$SecureBaseURL = $BaseURL | ConvertTo-SecureString -AsPlainText -Force

CreateConfigFile
