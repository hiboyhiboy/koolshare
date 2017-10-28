#!/bin/sh

cp -r /tmp/speedup/* /koolshare/
chmod a+x /koolshare/scripts/speedup*

# add icon into softerware center
dbus set softcenter_module_speedup_install=1
dbus set softcenter_module_speedup_version=1.1
dbus set softcenter_module_speedup_description="家庭云提速电信宽带"

