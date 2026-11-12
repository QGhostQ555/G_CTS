#!/system/bin/sh
# 输出 Scene 识别用的 powercfg.json；版本信息取自 module.prop
p="$1"
ver=$(sed -n 's/^version=//p' "$p" | head -n1 | tr -d '\r"')
code=$(sed -n 's/^versionCode=//p' "$p" | head -n1 | tr -d '\r"')
cat <<JSON
{
    "name": "G_CTS",
    "author": "Ghost (based on MoWei)",
    "version": "${ver:-v6.0}",
    "versionCode": ${code:-1},
    "features": {
        "strict": true,
        "pedestal": true
    },
    "module": "MW_CpuSpeedController",
    "state": "/sdcard/Android/MW_CpuSpeedController/config.txt",
    "entry": "/data/powercfg.sh",
    "projectUrl": "https://github.com/QGhostQ555/G_CTS"
}
JSON
