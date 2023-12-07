# 查DDR频率电压

查看当前频率
 cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump | grep -e uv -e khz

查看支持的频率和电压
cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table
