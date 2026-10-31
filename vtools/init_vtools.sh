#!/system/bin/sh
# 向 /data 部署 Scene 接口：powercfg.sh + powercfg.json
# 用法：init_vtools.sh <module.prop 路径>
BASEDIR="$(dirname "$(readlink -f "$0")")"
SD=/sdcard/Android/MW_CpuSpeedController
sh "$BASEDIR/gen_json.sh" "$1" > /data/powercfg.json
cp -af "$BASEDIR/powercfg.sh" /data/powercfg.sh
chmod 755 /data/powercfg.sh
mkdir -p "$SD"
[ -s "$SD/config.txt" ] || echo balance > "$SD/config.txt"
