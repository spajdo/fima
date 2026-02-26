#!/bin/bash

# ---------------------Colors---------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
COLOR_RESET='\033[0m'

# ---------------------Logging---------------------
echoX() {
    local message="$1"
    echo "###########"
    echo "# $message "
    echo "###########"
}

echoLog(){
    local message="$1"
    echo "INFO: $message " 
}

echoDebug(){
    local message="$1"
    echo -e "${BLUE}DEBUG: ${message}${COLOR_RESET}"
}

echoError(){
    local message="$1"
    echo -e "${RED}ERROR: ${message}${COLOR_RESET}"
}

# ---------------------Dialogs---------------------
dialogYN() {
    local message="$1"
    local input

    echo -n -e "${MAGENTA}DIALOG: ${message} [Enter/n]: ${COLOR_RESET}" >&2
    read -sn1 input #hidden one character input

    if [[ $input =~ ^(n|N|no|No|NO)$ ]]; then
        echo "No" >&2
        echo 0
    else
        echo "Yes" >&2
        echo 1
    fi
}

# ---------------------App management---------------------
runAppBusy(){
    appName="$1"
    if [ "$#" -ne 2 ]; then
        processName=$appName
    else
        processName="$2"
    fi
    echoDebug "Trying to run app '$appName' with process name '$processName'"

    isRunning=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")

    if [ "$isRunning" = "false" ]; then
        # Tell the application to run
        osascript -e "tell application \"$appName\" to launch" \
                # -e "tell application \"Finder\" to set visible of process \"$appName\" to false" #you should not use finder to control GUI
        
        # Repeat to wait until running app is finished so other commands can be processed
        while :; do
                appAllive=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")
                echoDebug "Is '$processName' allive: '$appAllive'"
                if [ "$appAllive" = "true" ]; then
                    break
                fi
                sleep 0.2
            done
        
        echoLog "Launch '$appName'"
    fi
}

killAppBusy(){
    appName="$1"
    if [ "$#" -ne 2 ]; then
        processName=$appName
    else
        processName="$2"
    fi

    isRunning=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")

    if [ "$isRunning" = "true" ]; then
        # Tell the application to quit
        osascript -e "tell application id (id of application \"$appName\") to quit"
        #osascript -e 'tell application "Terminal" to quit without saving'
        
        # Repeat to wait until killig app is finished so other commands can be processed
        while :; do
                appAllive=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")
                if [ "$appAllive" = "false" ]; then
                    break
                fi
                sleep 0.2
            done
        
        echoLog "Quit '$appName'"
    fi
}

stopAppBusyOrKill(){
    appName="$1"
    if [ "$#" -ne 2 ]; then
        processName=$appName
    else
        processName="$2"
    fi

    isRunning=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")

    if [ "$isRunning" = "true" ]; then
        # Tell the application to quit
        osascript -e "tell application id (id of application \"$appName\") to quit saving no"
        #osascript -e 'tell application "Terminal" to quit without saving'
        
        # Repeat to wait until killig app is finished so other commands can be processed
        maxElapsedTime="3.0"
        elapsedTime="0.0"
        while :; do
                if (( $(echo "$elapsedTime < $maxElapsedTime" | bc -l) )); then
                    killall "$appName" #killall -KILL "$appName" - in case of true force kill
                    elapsedTime=0
                fi

                appAllive=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")
                if [ "$appAllive" = "false" ]; then
                    break
                fi
                elapsedTime=$(echo "$elapsedTime + 0.2" | bc)
                sleep 0.2
            done
        
        echoLog "Quit '$appName'"
    fi
}

runApp(){
    appName="$1"
    if [ "$#" -ne 2 ]; then
        processName=$appName
    else
        processName="$2"
    fi

    isRunning=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")

    if [ "$isRunning" = "false" ]; then
    osascript -e "tell application \"$appName\" to launch" \
                # -e "tell application \"Finder\" to set visible of process \"$appName\" to false" #you should not use finder to control GUI
    echoLog "Launch '$appName'"
    fi
}

runOrKillApp(){
    appName="$1"
    if [ "$#" -ne 2 ]; then
        processName=$appName
    else
        processName="$2"
    fi

    isRunning=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")

    if [ "$isRunning" = "true" ]; then
    osascript -e "tell application id (id of application \"$appName\") to quit"
    echoLog "Quit '$appName'"
    else
    osascript -e "tell application \"$appName\" to launch" \
                # -e "tell application \"Finder\" to set visible of process \"$appName\" to false" #you should not use finder to control GUI
    echoLog "Launch '$appName'"
    fi
}

killApp(){
    appName="$1"
    if [ "$#" -ne 2 ]; then
        processName=$appName
    else
        processName="$2"
    fi

    isRunning=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$processName\"")

    if [ "$isRunning" = "true" ]; then
    osascript -e "tell application id (id of application \"$appName\") to quit"
    #osascript -e 'tell application "Terminal" to quit without saving'
    echo "Quit"
    fi
}

# ---------------------File functions---------------------
# Function to read all properties from the file and define them in script in format 'prop_$key'
getPropertiesFromFile() {
    local file="$1"

    # Check if the properties file exists
    if [[ ! -f "$file" ]]; then
        echoError "Properties file '$file' not found!"
        exit 1
    fi

    while IFS='=' read -r key value; do
        # Ignore commented lines and empty lines, add 'prop_' prefix to property
        if [[ ! "$key" =~ ^# && "$key" ]]; then
            fixedKey="prop_$(echo $key | tr '.' '_')"
            eval ${fixedKey}=\${value}
        fi
    done < "$file"
}