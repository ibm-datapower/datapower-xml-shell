#!/bin/bash
# Author: Harley Stenzel
# Purpose: Check on a DataPower appliance from within Nagios
# 
# Puts important device information (machine type, serial number, etc)
# along with deployment-specific checks (bladecenter chassis, collected
# out of band and checks for certain expected configuration) and outpusts
# it all with an exit code that Nagios understands
#
# NAGIOS_PLUGIN_DIR=/path/to/nagios/plugins
NAGIOS_PLUGIN_DIR=./
BLADECENTER_SNMP_VPD=/path/to/bladecenter-snmp-vpd/

# The magic to use when it's part of a script:
DPXMLSH_SCRIPT=true
. ${NAGIOS_PLUGIN_DIR}dpxmlsh_library.sh


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
STATE=$STATE_OK

dpxmlsh_init "$@"
if [ "$?" != "0" ]
then
  exit $STATE_CRITICAL
fi

dpxmlsh_get_status_import FirmwareVersion
if [ -z "$FirmwareVersion_MachineType" -o -z "$FirmwareVersion_ModelType" ]
then
  exit $STATE_CRITICAL
fi

# We want to know in nagios if certain configuration properties
# are present, and if they are enabled.  Certain combinations are concerning,
# but we only want to know -- these are test devices and not production.

# Here's an example of a config block that we're checking for:
# _config_IncludeConfig_net_mAdminState="enabled"
# _config_IncludeConfig_net_URL="config:dp521-net.cfg"
# _config_IncludeConfig_net_OnStartup="on"
# _config_IncludeConfig_net_InterfaceDetection="off"
# _config_IncludeConfig_std_mAdminState="enabled"
# _config_IncludeConfig_std_URL="config:dp521-std.cfg"
# _config_IncludeConfig_std_OnStartup="on"
# _config_IncludeConfig_std_InterfaceDetection="off"

dpxmlsh_get_config_import IncludeConfig

INCLUDECONFIG=""
case "$_config_IncludeConfig_net_mAdminState-$_config_IncludeConfig_std_mAdminState" in
  enabled-enabled)
    INCLUDECONFIG="config-OK"
    ;;

  enabled-disabled)
    INCLUDECONFIG="config-std-DISABLED"
    STATE=$STATE_WARNING
    ;;

  disabled-enabled)
    INCLUDECONFIG="config-net-DISABLED"
    STATE=$STATE_WARNING
    ;;

  disabled-disabled)
    INCLUDECONFIG="config-net-std-DISABLED"
    STATE=$STATE_WARNING
    ;;

  *)
    INCLUDECONFIG="config-ERROR!"
    STATE=$STATE_CRITICAL
    ;;
esac

# look up what bladecenter chasis this is in.  Empty is OK.
# This assumes that there is a directory containing smnpwalks of bladecenters
BC=$(grep  "\"$FirmwareVersion_Serial\"" $BLADECENTER_SNMP_VPD/* | grep bladeHardwareVpdSerialNumber | sed -e 's;^.*bladecenter-snmp-vpd/;;g' -e 's/mm.*:bladeHardwareVpdSerialNumber//g' -e 's/ =.*//g' | sort | uniq)

echo "$FirmwareVersion_MachineType-$FirmwareVersion_ModelType $FirmwareVersion_Serial $FirmwareVersion_XMLAccelerator $FirmwareVersion_Version $FirmwareVersion_Build $FirmwareVersion_BuildDate ${INCLUDECONFIG} ${BC}"

exit $STATE
