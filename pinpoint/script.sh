ttl=$1

SOFTWARE=/root/pinpoint/hbase-create.hbase

sed -i "/AgentInfo/s/TTL => .[[:digit:]]*/TTL => ${AGENTINFO_TTL:-$ttl}/g" $SOFTWARE
sed -i "/AgentStatV2/s/TTL => .[[:digit:]]*/TTL => ${AGENTSTATV2_TTL:-$ttl}/g" $SOFTWARE
sed -i "/ApplicationStatAggre/s/TTL => .[[:digit:]]*/TTL => ${APPSTATAGGRE_TTL:-$ttl}/g" $SOFTWARE
sed -i "/ApplicationIndex/s/TTL => .[[:digit:]]*/TTL => ${APPINDEX_TTL:-$ttl}/g" $SOFTWARE
sed -i "/AgentLifeCycle/s/TTL => .[[:digit:]]*/TTL => ${AGENTLIFECYCLE_TTL:-$ttl}/g" $SOFTWARE
sed -i "/AgentEvent/s/TTL => .[[:digit:]]*/TTL => ${AGENTEVENT_TTL:-$ttl}/g" $SOFTWARE
sed -i "/StringMetaData/s/TTL => .[[:digit:]]*/TTL => ${STRINGMETADATA_TTL:-$ttl}/g" $SOFTWARE
sed -i "/ApiMetaData/s/TTL => .[[:digit:]]*/TTL => ${APIMETADATA_TTL:-$ttl}/g" $SOFTWARE
sed -i "/SqlMetaData_Ver2/s/TTL => .[[:digit:]]*/TTL => ${SQLMETADATA_TTL:-$ttl}/g" $SOFTWARE
sed -i "/TraceV2/s/TTL => .[[:digit:]]*/TTL => ${TRACEV2_TTL:-$ttl}/g" $SOFTWARE
sed -i "/ApplicationTraceIndex/s/TTL => .[[:digit:]]*/TTL => ${APPTRACEINDEX_TTL:-$ttl}/g" $SOFTWARE
sed -i "/ApplicationMapStatisticsCaller_Ver2/s/TTL => .[[:digit:]]*/TTL => ${APPMAPSTATCALLERV2_TTL:-$ttl}/g" $SOFTWARE
sed -i "/ApplicationMapStatisticsCallee_Ver2/s/TTL => .[[:digit:]]*/TTL => ${APPMAPSTATCALLEV2_TTL:-$ttl}/g" $SOFTWARE
sed -i "/ApplicationMapStatisticsSelf_Ver2/s/TTL => .[[:digit:]]*/TTL => ${APPMAPSTATSELFV2_TTL:-$ttl}/g" $SOFTWARE
sed -i "/HostApplicationMap_Ver2/s/TTL => .[[:digit:]]*/TTL => ${HOSTAPPMAPV2_TTL:-$ttl}/g" $SOFTWARE

#sed -i "s/create/alter/g" hbase-update-ttl.hbase
#sed -i "/AgentInfo/s/TTL => .[[:digit:]]*/TTL => ${AGENTINFO_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/AgentStatV2/s/TTL => .[[:digit:]]*/TTL => ${AGENTSTATV2_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/ApplicationStatAggre/s/TTL => .[[:digit:]]*/TTL => ${APPSTATAGGRE_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/ApplicationIndex/s/TTL => .[[:digit:]]*/TTL => ${APPINDEX_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/AgentLifeCycle/s/TTL => .[[:digit:]]*/TTL => ${AGENTLIFECYCLE_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/AgentEvent/s/TTL => .[[:digit:]]*/TTL => ${AGENTEVENT_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/StringMetaData/s/TTL => .[[:digit:]]*/TTL => ${STRINGMETADATA_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/ApiMetaData/s/TTL => .[[:digit:]]*/TTL => ${APIMETADATA_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/SqlMetaData_Ver2/s/TTL => .[[:digit:]]*/TTL => ${SQLMETADATA_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/TraceV2/s/TTL => .[[:digit:]]*/TTL => ${TRACEV2_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/ApplicationTraceIndex/s/TTL => .[[:digit:]]*/TTL => ${APPTRACEINDEX_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/ApplicationMapStatisticsCaller_Ver2/s/TTL => .[[:digit:]]*/TTL => ${APPMAPSTATCALLERV2_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/ApplicationMapStatisticsCallee_Ver2/s/TTL => .[[:digit:]]*/TTL => ${APPMAPSTATCALLEV2_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/ApplicationMapStatisticsSelf_Ver2/s/TTL => .[[:digit:]]*/TTL => ${APPMAPSTATSELFV2_TTL:-$ttl}/g" hbase-update-ttl.hbase
#sed -i "/HostApplicationMap_Ver2/s/TTL => .[[:digit:]]*/TTL => ${HOSTAPPMAPV2_TTL:-$ttl}/g" hbase-update-ttl.hbase

