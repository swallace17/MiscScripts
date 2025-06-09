# ================================================================
# ===            Kiosk User Reset and Autologon Script         ===
# ================================================================
#
# Resets a local user account on kiosk-style systems by:
# - Force-logging off any active session
# - Deleting the user account and profile
# - Recreating the account
# - Reapplying autologon settings using Sysinternals AutoLogon
#
# Intended for use in kiosk environments requiring a consistent, clean
# user experience between sessions. 
# ================================================================


# === Configuration ===
$Username = "username"
$Password = "Password"
$Domain = $env:COMPUTERNAME
$ProfilePath = "C:\Users\$Username"
$AutoLogonPath = "C:\Tools\Autologon64.exe"

# === Step 1: Force logoff of user if logged in ===
# Check if user is logged in; if so, parse their session ID and force logoff to avoid profile deletion errors
$sessionInfo = quser | Select-String -Pattern "^$Username\s+" -ErrorAction SilentlyContinue
if ($sessionInfo) {
    try {
        $sessionId = ($sessionInfo -split '\s+')[2]
        Write-Output "Logging off session ID $sessionId for user $Username"
        logoff $sessionId
        Start-Sleep -Seconds 5
    } catch {
        Write-Warning "Failed to log off $Username: $_"
    }
}

# === Step 2: Delete user account if it exists ===
if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    try {
        Remove-LocalUser -Name $Username -ErrorAction Stop
        Write-Output "Removed local user account: $Username"
    } catch {
        Write-Warning "Failed to remove user account: $_"
    }
}

# === Step 3: Remove the profile directory if it exists ===
if (Test-Path $ProfilePath) {
    try {
        Remove-Item -Path $ProfilePath -Recurse -Force
        Write-Output "Deleted profile folder: $ProfilePath"
    } catch {
        Write-Warning "Failed to delete profile folder: $_"
    }
}

# === Step 4: Recreate the user account ===
try {
    $SecurePass = ConvertTo-SecureString $Password -AsPlainText -Force
    New-LocalUser -Name $Username `
                  -Password $SecurePass `
                  -FullName $Username `
                  -Description "$Username Kiosk Account" `
                  -UserMayNotChangePassword `
                  -PasswordNeverExpires
    Add-LocalGroupMember -Group "Users" -Member $Username
    Write-Output "Recreated user account: $Username"
} catch {
    Write-Warning "Failed to recreate user account: $_"
}

# === Step 5: Configure Sysinternals AutoLogon ===
if (Test-Path $AutoLogonPath) {
    try {
        Start-Process -FilePath $AutoLogonPath `
            -ArgumentList "$Username","$Domain","$Password","/accepteula" `
            -NoNewWindow -Wait
        Write-Output "Configured AutoLogon for $Username"
    } catch {
        Write-Warning "Failed to run AutoLogon.exe: $_"
    }
} else {
    Write-Warning "AutoLogon.exe not found at $AutoLogonPath"
}

# === Step 6: (Optional) Reboot ===
Restart-Computer -Force