
#!/bin/bash

#############################
# ___  _   ___ _____      _____  ___ ___    ___  ___  _    ___ _____   __  ___ ___ _____ _____ ___ _  _  ___ ___
#| _ \/_\ / __/ __\ \    / / _ \| _ \   \  | _ \/ _ \| |  |_ _/ __\ \ / / / __| __|_   _|_   _|_ _| \| |/ __/ __|
#|  _/ _ \\__ \__ \\ \/\/ / (_) |   / |) | |  _/ (_) | |__ | | (__ \ V /  \__ \ _|  | |   | |  | || .` | (_ \__ \
#|_|/_/ \_\___/___/ \_/\_/ \___/|_|_\___/  |_|  \___/|____|___\___| |_|   |___/___| |_|   |_| |___|_|\_|\___|___/
#############################

MAX_FAILED=5                  # 5 max failed logins before locking
LOCKOUT=180                    # 2min lockout

exemptAccount1="LyftJssAdmin"          #Exempt account used for remote management. CHANGE THIS TO YOUR EXEMPT ACCOUNT


if [ $PW_EXPIRE -lt "1" ];
then
    echo "PW EXPIRE TIME CAN NOT BE 0 or less."
    exit 1
fi

for user in $(dscl . list /Users UniqueID | awk '$2 >= 500 {print $1}'); do
    if [ "$user" != "$exemptAccount1" ]; then

    #Check if current plist is installed by comparing the current variables to the new ones

    #LOCKOUT
    currentLockOut=$(sudo pwpolicy -u "$user" -getaccountpolicies | grep "<integer>$LOCKOUT</integer>" |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )
    newLockOut="<integer>$LOCKOUT</integer>"

    #MAX_FAILED
    currentMaxFailed=$(sudo pwpolicy -u "$user" -getaccountpolicies | grep "<integer>$MAX_FAILED</integer>" |  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )
    newMaxFailed="<integer>$MAX_FAILED</integer>"


    isPlistNew=0

    if [ "$currentLockOut" == "$newLockOut" ]; then
      echo "LOCKOUT is the same"
    else
      echo "LOCKOUT is NOT the same"
      echo "current: $currentLockOut"
      echo "new: $newLockOut"
      isPlistNew=1
    fi

    if [ "$currentMaxFailed" == "$newMaxFailed" ]; then
      echo "MAX_FAILED is the same"
    else
      echo "MAX_FAILED is NOT the same"
      echo "current: $currentMaxFailed"
      echo "new: $newMaxFailed"
      isPlistNew=1
    fi

    if [ "$isPlistNew" -eq "1" ]; then

    # Creates plist using variables above
    echo "<dict>
    <key>policyCategoryAuthentication</key>
      <array>
      <dict>
        <key>policyContent</key>
        <string>(policyAttributeFailedAuthentications &lt; policyAttributeMaximumFailedAuthentications) OR (policyAttributeCurrentTime &gt; (policyAttributeLastFailedAuthenticationTime + autoEnableInSeconds))</string>
        <key>policyIdentifier</key>
        <string>Authentication Lockout</string>
        <key>policyParameters</key>
      <dict>
      <key>autoEnableInSeconds</key>
      <integer>$LOCKOUT</integer>
      <key>policyAttributeMaximumFailedAuthentications</key>
      <integer>$MAX_FAILED</integer>
      </dict>
    </dict>
    </array>
    </dict>" > /private/var/tmp/pwpolicy.plist #save the plist temp

    chmod 777 /private/var/tmp/pwpolicy.plist


        pwpolicy -u "$user" -clearaccountpolicies
        pwpolicy -u "$user" -setaccountpolicies /private/var/tmp/pwpolicy.plist
        fi
    fi
done

rm /private/var/tmp/pwpolicy.plist

echo "Password policy successfully applied. Run \"sudo pwpolicy -u <user> -getaccountpolicies\" to see it."
exit 0