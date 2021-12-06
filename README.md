# SMP-Commander
Have you ever wanted to actually run commads on your SMB devices that are managed in SMP without pulling your hair out? This script should help you.

## Usage
./smp-commander.sh -g GATEWAY -c "show hosts" -o

-g | --gateway     Gateway Object Name. <br>
-c | --command     CLISH Command to Execute on Gateway. The show-gateway api call with run if no command is provided. <br>
-o | --output      Save Command Output to Log File. <br>
