# How to Update Patches On windows

## Step 1:
* Open Powershell as **Administrator**
* Install SSH Service.
```
Get-Service sshd
```
* To Start SSH Automatically On Startup Run the command given below:-
```
Set-Service -Name sshd -StartupType 'Automatic'
```
* Run the command given below to set powershell as default Shell:-
 
```
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" `
>>     -Name "DefaultShell" -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
>>     -PropertyType String -Force
DefaultShell : C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
PSPath       : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH
PSParentPath : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE
PSChildName  : OpenSSH
PSDrive      : HKLM
PSProvider   : Microsoft.PowerShell.Core\Registry
```

* Restart SSH Service
```
Restart-Service sshd
```

## Step 2:.
* Clone the code from given link:-
```
https://github.com/visionsDe/devops.git
```
* go to given path below:-
```
cd /devops/ansible/
```
* Run the Command given below:-
```
ansible-playbook -i hosts update_windows.yaml
```

## SUMMARY

* Set Powershell as Default Shell.
* Restarted SSH Serivce to apply Changes.
* Cloning Repo to System.
* Running Ansible-Playbook to Patching Windows System 
