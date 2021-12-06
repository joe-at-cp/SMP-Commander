#!/bin/bash

#SMP Parameters
SMP_REGISTER_URL="https://smbmgmtservice.checkpoint.com"
SMP_REGISTER_DOMAIN="mysmpdomain"
SMP_REGISTER_USERNAME="myusername"
SMP_REGISTER_PASSWORD="mypassword"

#Input parameters
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -g|--gateway)
    SMP_REGISTER_GW_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    -c|--command)
    COMMAND="$2"
    shift # past argument
    shift # past value
    ;;
    -o|--output)
    OUTPUT=1
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    HELP=1
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameter


echo '[ SMP Commander ]'
echo '---------------------------------------------------------------------------------'



if [ "$HELP" == "1" ]; then
    #Show Help
    echo ' ./Script.sh -g GATEWAY -c "my clish command"'
    exit 1
fi

if [ "$SMP_REGISTER_GW_NAME" == "" ]; then
    echo " Missing gateway object name! - Try again"
    echo ' ./smp-commander.sh -g GATEWAY -c "my clish command"'
    exit 1
fi

if [ "$COMMAND" == "" ]; then
    #No command provided -> run show-gateway and display the output then exit

    #Login
    LOGIN=$(curl -s -k -H "Content-Type: application/json" -X POST -d '{"username":"'"${SMP_REGISTER_USERNAME}"'","password":"'"${SMP_REGISTER_PASSWORD}"'","serviceDomain":"'"${SMP_REGISTER_DOMAIN}"'","app":"SMP-REST-WS"}' ${SMP_REGISTER_URL}/SMC/api/v1/login)
    SID=$(echo $LOGIN | jq .id -r)

    #Run Command
    curl -f -s -k -H "Content-Type: application/json" -H "X-chkp-sid:${SID}" -X POST -d '{"gateway":{"name":"'"${SMP_REGISTER_GW_NAME}"'"}}' ${SMP_REGISTER_URL}/SMC/api/v1/show-gateway | jq .
    exit 1
fi

if [ $OUTPUT == 1 ]; then
    NOSPACES=$(echo "$COMMAND" | sed 's/ //g')
    LOGDATE=$(date "+%F_%H-%M-%S")
    OUTPUT_FILE="${SMP_REGISTER_DOMAIN}_${SMP_REGISTER_GW_NAME}_${NOSPACES}_${LOGDATE}.log"
    
fi


#Login
LOGIN=$(curl -s -k -H "Content-Type: application/json" -X POST -d '{"username":"'"${SMP_REGISTER_USERNAME}"'","password":"'"${SMP_REGISTER_PASSWORD}"'","serviceDomain":"'"${SMP_REGISTER_DOMAIN}"'","app":"SMP-REST-WS"}' ${SMP_REGISTER_URL}/SMC/api/v1/login)
SID=$(echo $LOGIN | jq .id -r)

#Run Command
RUN_COMMAND=$(curl -f -s -k -H "Content-Type: application/json" -H "X-chkp-sid:${SID}" -X POST -d '{"gateway":{"name":"'"${SMP_REGISTER_GW_NAME}"'"},"cliScript": {"cliScript": "'"${COMMAND}"'"}}' ${SMP_REGISTER_URL}/SMC/api/v1/set-gateway-cli)

#Validate command was recieved by checking the .object.cliScript_5.script field
SHOW_GATEWAY=$(curl -f -s -k -H "Content-Type: application/json" -H "X-chkp-sid:${SID}" -X POST -d '{"gateway":{"name":"'"${SMP_REGISTER_GW_NAME}"'"}}' ${SMP_REGISTER_URL}/SMC/api/v1/show-gateway)

cliScript_5=$(echo "$SHOW_GATEWAY" | jq .object.cliScript_5.script -r)
lastConnect=$(echo "$SHOW_GATEWAY" | jq .object.lastConnect -r )
lastConnect_Converted=$(date -d "@$lastConnect")

if [ "$cliScript_5" == "$COMMAND" ]; then
    echo " - Sending command to SMP: $COMMAND"

    #Wait for Gateway to Check-In with SMP
    CHECKED_IN=0

    echo " - Waiting for Gateway to Checkin with SMP... Last check in time: $lastConnect_Converted"

    while [ $CHECKED_IN == 0 ]; do

        SHOW_GATEWAY_MONITOR=$(curl -f -s -k -H "Content-Type: application/json" -H "X-chkp-sid:${SID}" -X POST -d '{"gateway":{"name":"'"${SMP_REGISTER_GW_NAME}"'"}}' ${SMP_REGISTER_URL}/SMC/api/v1/show-gateway)
        lastConnect_Monitor=$(echo "$SHOW_GATEWAY_MONITOR" | jq .object.lastConnect -r)

        #Gateway has checked-in with SMP
        if [ "$lastConnect" != "$lastConnect_Monitor" ]; then

            script_status=$(echo "$SHOW_GATEWAY_MONITOR" | jq .object.gwScriptStatus_5.scriptRunText -r)

            echo " - Gateway Checked into SMP"
            echo "   Command output:"
            echo ""
            echo "     $script_status"
            echo ""
            
            #Save command output to a file
            if [ $OUTPUT == 1 ]; then
                echo "$script_status" > $OUTPUT_FILE
            fi
            
            break

        fi

        sleep 30s
        echo "  ..."
    done


else
    echo " - SMP failed to accept command! - Exiting"
fi
