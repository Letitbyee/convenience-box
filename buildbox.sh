#!/bin/bash
# 便捷工具箱 —— 出包脚本（不用 Gradle）
#
# 依赖：JDK 17、Android SDK build-tools 34（aapt2 / d8 / zipalign / apksigner）、python3
# 用法：
#   ANDROID_HOME=~/Android/sdk KS=~/my.jks KS_PASS=你的口令 KS_ALIAS=别名 ./buildbox.sh
# 签名自备：本仓库不含任何 keystore 或口令。
set -e

: "${ANDROID_HOME:?请设置 ANDROID_HOME}"
: "${KS:?请设置 KS 指向你自己的 keystore}"
: "${KS_PASS:?请设置 KS_PASS（用 env 传，别留在命令行历史里）}"
KS_ALIAS="${KS_ALIAS:-$(basename "$KS" .jks)}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BT="$ANDROID_HOME/build-tools/34.0.0"
AJ="$ANDROID_HOME/platforms/android-34/android.jar"
APP="$ROOT/app"
OUT="$ROOT/dist"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/classes" "$W/dex" "$OUT"

cd "$APP"
echo "== 1/6 编译资源 =="
"$BT/aapt2" compile --dir res -o "$W/res.zip"
echo "== 2/6 链接 =="
"$BT/aapt2" link -o "$W/base.apk" -I "$AJ" --manifest AndroidManifest.xml -A assets \
  --min-sdk-version 24 --target-sdk-version 34 "$W/res.zip"
echo "== 3/6 javac =="
javac -nowarn -Xlint:-options -source 8 -target 8 -classpath "$AJ" -d "$W/classes" java/com/cc/conveniencebox/MainActivity.java
echo "== 4/6 d8（所有 class 都要喂进去，漏了内部类装上会闪退） =="
find "$W/classes" -name '*.class' > "$W/classlist.txt"
echo "    送进 d8 的 class 数: $(wc -l < "$W/classlist.txt")"
"$BT/d8" --lib "$AJ" --min-api 24 --output "$W/dex" @"$W/classlist.txt"
echo "== 5/6 合并 dex =="
python3 - "$W" <<'PYEOF'
import sys, zipfile, os
w = sys.argv[1]
with zipfile.ZipFile(os.path.join(w, "unsigned.apk"), "w", zipfile.ZIP_DEFLATED) as out:
    with zipfile.ZipFile(os.path.join(w, "base.apk")) as zin:
        for it in zin.infolist():
            out.writestr(it, zin.read(it.filename))
    out.write(os.path.join(w, "dex", "classes.dex"), "classes.dex")
print("merged")
PYEOF
echo "== 6/6 zipalign + 签名 =="
"$BT/zipalign" -f -p 4 "$W/unsigned.apk" "$W/aligned.apk"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" --out "$OUT/convenience-box.apk" "$W/aligned.apk"
rm -f "$OUT/convenience-box.apk.idsig"
echo "== 校验 =="
"$BT/apksigner" verify --print-certs "$OUT/convenience-box.apk" | head -3
"$BT/aapt2" dump badging "$OUT/convenience-box.apk" | head -2
ls -la "$OUT/convenience-box.apk"
