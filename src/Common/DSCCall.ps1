# Consolidated resource for MOF generation
# IISObject must include WebsiteName + WebAppPool - Get-Website -> foreach($i in $sites) {(inv-cmd -comp $serv -scr {get-website $i}).applicationpool}
# SQLObject must include SqlVersion, SqlRole, ServerInstance, Database

param(

    [Parameter(Mandatory=$true,Position=0)]
    [String]
    $ComputerName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("2012R2","2016",'10')]
    [String]
    $OsVersion,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [String]
    $OrgSettingsFilePath,

    [Parameter(Mandatory=$false)]
    [String[]]
    $SkipRules,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [String]
    $LogPath

)

DynamicParam {
    $ParameterName = 'Role'
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $ParameterAttribute.Mandatory = $true
    $AttributeCollection.Add($ParameterAttribute)
    $roleSet = @(Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role)
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)
    $AttributeCollection.Add($ValidateSetAttribute)
    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string[]], $AttributeCollection)
    $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
    return $RuntimeParameterDictionary
}


Begin
{
    #Bound the dynamic parameter to a new Variable
    $Role = $PSBoundParameters[$ParameterName]
}

process
{

    if($null -ne $LogPath -and $LogPath -ne "")
    {
        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Starting mof generation for $ComputerName"
    }

    Configuration PowerSTIG
    {
        Import-DscResource -ModuleName PowerStig -ModuleVersion 3.2.0

        Node $ComputerName
        {
            # Org Settings will always be passed. Log file will be used.
            # Question will be if skip rule will be
            # if Skip rule is not empty/null do 1 else do 2
            Switch($Role){
                "WindowsServer-DC" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DomainController Configuration"
                    WindowsServer DomainController
                    {
                        OsVersion       = $OsVersion
                        OsRole          = 'DC'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsServer-DC" -OSVersion $osVersion)
                        OrgSettings     = $OrgSettingsFilePath
                    }
                    
                }
                "WindowsDNSServer" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DNS Configuration"
                    WindowsDnsServer DNS
                    {
                        OsVersion       = $OsVersion
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsDNSServer" -OSVersion $osVersion)
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "WindowsServer-MS" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding MemberServer Configuration"
                    WindowsServer MemberServer
                    {
                        OsVersion       = $OsVersion
                        OsRole          = 'MS'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsServer-MS" -OSVersion $osVersion)
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "InternetExplorer" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding InternetExplorer Configuration"
                    InternetExplorer IE
                    {
                        BrowserVersion  = '11'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "InternetExplorer")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "WindowsFirewall" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding FireWall Configuration"
                    WindowsFirewall Firewall
                    {
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsFirewall")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "WindowsClient" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Windows10 Configuration"
                    WindowsClient Client
                    {
                        OsVersion       = '10'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsClient" -OSVersion "10")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "OracleJRE" {
                    #HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Runtime Environment\1.8
                    if($ComputerName -eq $env:COMPUTERNAME)
                    {
                        if(Test-Path "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8")
                        {
                            $installPath = (Get-ItemProperty "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8").javahome
                        }
                        elseif(Test-Path "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8")
                        {
                            $installPath = (Get-ItemProperty "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8").javahome
                        }
                        else
                        {
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][ERROR]: Unable to determine Java install path."
                            Return
                        }
                    }
                    else
                    {
                        if(Invoke-Command -ComputerName $ComputerName -ScriptBlock {Test-Path "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8"})
                        {
                            $installPath = (Invoke-Command -ComputerName $ComputerName -ScriptBlock {(Get-ItemProperty "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8").javahome})
                        }
                        elseif(Invoke-Command -ComputerName $ComputerName -ScriptBlock {Test-Path "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8"})
                        {
                            $installPath = (Invoke-Command -ComputerName $ComputerName -ScriptBlock {(Get-ItemProperty "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8").javahome})
                        }
                        else
                        {
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][ERROR]: Unable to determine Java install path."
                            Return
                        }

                    }

                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Testing Path to OracleJRE deployment.config file."
                    if($ComputerName -eq $env:COMPUTERNAME)
                    {
                        if(Test-Path "$installPath\lib\deployment.config")
                        {
                            $confPath = "$installPath\lib\deployment.config"
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exists. Checking for content."
                        }
                        elseif(Test-Path "$env:WINDIR\Sun\Java\Deployment\deployment.config")
                        {
                            $confPath = "$env:WINDIR\Sun\Java\Deployment\deployment.config"
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exists. Checking for content."
                        }
                        else
                        {
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Warning]: deployment.config file does not exist. Creating file in $installPath"
                            $confPath = "$installPath\lib\deployment.config"
                            New-Item $confPath -ItemType File
                        }
                        $depConfCont = Get-Content $confPath
                    }
                    else
                    {
                        if(Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($installPath)Test-Path "$installPath\lib\deployment.config"} -ArgumentList $installPath)
                        {
                            $confPath = "$installPath\lib\deployment.config"
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exist. Checking for content."
                        }
                        elseif(Invoke-Command -ComputerName $ComputerName -ScriptBlock {Test-Path "$env:WINDIR\Sun\Java\Deployment\deployment.config"})
                        {
                            $confPath = "$env:WINDIR\Sun\Java\Deployment\deployment.config"
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exist. Checking for content."
                        }
                        else
                        {
                            Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Warning]: deployment.config file does not exist. Creating file in $installPath"
                            $confPath = "$installPath\lib\deployment.config"
                            Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($confPath)New-Item $confPath -ItemType File} -ArgumentList $confPath
                        }
                        $depConfCont = Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($confPath)Get-Content $confPath} -ArgumentList $confPath
                    }

                    if($depConfCont -eq 0)
                    {
                        $OracleJREXML   = Get-Content "$((get-module PowerSTIG).ModuleBase)\StigData\Processed\OracleJRE-8-1.5.xml"
                        $PropertiesPath = ($OracleJREXML.DISASTIG.FileContentRule.Rule | Where-Object {$_.value -like "*deployment.properties"} | Select-Object -expandproperty Value).replace("file:///","")
                        if($ComputerName -eq $env:COMPUTERNAME)
                        {
                            Add-content $ConfPath -Value "1"
                            
                        }
                        else
                        {
                            Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($confPath)Add-Content -Path $confPath -Value "1"} -ArgumentList $confPath
                        }
                    }
                    else
                    {
                        if(($depConfCont | Where-Object {$_ -like "deployment.system.config*" -and $_ -notlike "deployment.system.config.mandatory*"}) -ne 0)
                        {
                            $PropertiesPath = (($depConfCont | Where-Object {$_ -like "deployment.system.config*" -and $_ -notlike "deployment.system.config.mandatory*"}) -split "=")[1].replace("file:///","")
                        }
                        else
                        {
                            $OracleJREXML   = Get-Content "$((get-module PowerSTIG).ModuleBase)\StigData\Processed\OracleJRE-8-1.5.xml"
                            $PropertiesPath = ($OracleJREXML.DISASTIG.FileContentRule.Rule | Where-Object {$_.value -like "*deployment.properties"} | Select-Object -expandproperty Value).replace("file:///","")    
                        }
                    }

                    if($ComputerName -eq $env:ComputerName)
                    {
                        if(-not (Test-Path $PropertiesPath))
                        {
                            New-Item -Path $PropertiesPath -ItemType File -Force | out-null
                        }

                        $PropertiesCont = Get-Content $PropertiesPath
                        if($PropertiesCont.count -eq 0)
                        {
                            Add-Content $PropertiesPath -Value "1"
                        }
                    }
                    else
                    {
                        if(-not(Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($PropertiesPath)Test-Path $PropertiesPath} -ArgumentList $PropertiesPath))
                        {
                            Invoke-Command -ComputerName $Computername -ScriptBlock {param($PropertiesPath)New-Item $PropertiesPath -ItemType File -Force} -ArgumentList $PropertiesPath | out-null
                        }

                        $PropertiesCont = Invoke-Command -ComputerName $Computername -ScriptBlock {param($PropertiesPath)Get-Content $PropertiesPath} -ArgumentList $PropertiesPath
                        if($PropertiesCont.count -eq 0)
                        {
                            Invoke-Command -ComputerName $Computername -ScriptBlock {param($PropertiesPath)Add-Content $PropertiesPath -Value "1"} -ArgumentList $PropertiesPath
                        }
                    }


                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: Adding OracleJRE Configuration"
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: ConfigPath = $confPath"
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: PropertiesPath = $PropertiesPath"
                    OracleJRE JRE
                    {
                        ConfigPath      = $confPath
                        PropertiesPath  = $PropertiesPath
                        StigVersion     = (Get-PowerStigXMLVersion -Role "OracleJRE")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "IISServer" {
                    #continue until this is finalized - must find app pool website relationships
                    Return
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding IIS Configuration"
                    IisServer IIS-Server-$ComputerName
                    {
                        StigVersion     = (Get-PowerStigXMLVersion -Role "IISServer")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                    IisSite IIS-Site-$WebsiteName
                    {
                        WebsiteName     = $WebsiteName
                        WebAppPool      = $WebAppPool
                        StigVersion     = (Get-PowerStigXMLVersion -Role "IISSite")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "SqlServer-2012-Database" {
                    #continue until finalized, must find instance and database relationships
                    Return
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding SQL Configuration"
                    SqlServer Sql-$Database
                    {
                        SqlVersion      = $SqlVersion
                        SqlRole         = $SqlRole
                        ServerInstance  = $SqlInstance
                        Database        = $Database
                        StigVersion     = (Get-PowerStigXMLVersion -Role "SqlServer-2012-Database")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "Outlook2013" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Outlook2013 Configuration"
                    Office Outlook
                    {
                        OfficeApp       = "Outlook2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Outlook2013")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "PowerPoint2013"{
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding PowerPoint2013 Configuration"
                    Office PowerPoint
                    {
                        OfficeApp       = "PowerPoint2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "PowerPoint2013")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "Excel2013" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Excel2013 Configuration"
                    Office Excel
                    {
                        OfficeApp       = "Excel2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Excel2013")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "Word2013" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Word2013 Configuration"
                    Office Word
                    {
                        OfficeApp       = "Word2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Word2013")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "Outlook2016" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Outlook2016 Configuration"
                    Office Outlook
                    {
                        OfficeApp       = "Outlook2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Outlook2016")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "PowerPoint2016"{
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding PowerPoint2016 Configuration"
                    Office PowerPoint
                    {
                        OfficeApp       = "PowerPoint2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "PowerPoint2016")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "Excel2016" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Excel2016 Configuration"
                    Office Excel
                    {
                        OfficeApp       = "Excel2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Excel2016")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "Word2016" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Word2016 Configuration"
                    Office Word
                    {
                        OfficeApp       = "Word2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Word2016")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "FireFox" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding FireFox Configuration"
                    
                    try
                    {
                        $installDirectory = (Get-PowerStigFireFoxDirectory -ComputerName $ComputerName)
                    }
                    catch
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ComputerName][FireFoxDSC][ERROR]:$_"
                        Return
                    }

                    if($null -eq $installDirectory -or $installDirectory -eq "")
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ComputerName][FireFoxDSC][ERROR]:Could not find FireFox install directory."
                        Return
                    }
                    
                    FireFox Firefox
                    {
                        StigVersion         = (Get-PowerStigXMLVersion -Role "FireFox")
                        InstallDirectory    = $installDirectory
                        OrgSettings         = $OrgSettingsFilePath
                    }
                }
                "DotNetFramework" {
                    Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DotNet Configuration"
                    DotNetFramework DotNet
                    {
                        FrameworkVersion    = 'DotNet4'
                        StigVersion         = (Get-PowerStigXMLVersion -Role "DotNetFramework")
                        OrgSettings         = $OrgSettingsFilePath
                    }
                }
            }
        
        }
    }

    PowerSTIG
}