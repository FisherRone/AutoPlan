#!/bin/bash

PROJECT_NAME="AutoPlan.xcodeproj"
APP_NAME="AutoPlan"                # 最终分发包的名字（不含后缀）
SCHEME="AutoPlanApp"
CONFIGURATION="Release"
OUTPUT_DIR="./build"
ENTITLEMENTS_PATH="./AutoPlan.entitlements"

cd "$(dirname "$0")"

# 清理之前的构建
echo "1️⃣ xcodebuild cleaning..."
xcodebuild clean -project "$PROJECT_NAME" -scheme "$SCHEME"

DERIVED_DATA_PATH=$(xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME" -showBuildSettings | grep -m1 "OBJROOT" | awk -F' = ' '{print $2}' | sed 's#/Build/Intermediates.noindex##')
if [ -n "$DERIVED_DATA_PATH" ]; then
    rm -rf "$DERIVED_DATA_PATH"
else
    rm -rf ~/Library/Developer/Xcode/DerivedData/AutoPlan-*
fi

# 编译项目（禁用代码签名）
echo "2️⃣ building..."
xcodebuild build \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION"

if [ $? -ne 0 ]; then
    echo "❌ build fail"
    exit 1
fi
echo "✅ 编译成功！"

# 定位生成的产品目录（更稳健的方法）
echo "3️⃣ move .app to output dir..."
BUILD_DIR=$(xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME" -showBuildSettings | awk -F' = ' '/^    BUILD_DIR =/{print $2; exit}')
if [ -z "$BUILD_DIR" ]; then
    echo "❌ cannot get build directory"
    exit 1
fi

echo "build directory: $BUILD_DIR"

APP_BUNDLE=$(find "$BUILD_DIR" -maxdepth 2 -name "${APP_NAME}.app" -type d | head -n 1)
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ .app file not found"
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
mv "$APP_BUNDLE" "$OUTPUT_DIR/"
echo "✅ .app moved to: $OUTPUT_DIR/$(basename "$APP_BUNDLE")"

# 设置复制后的 app 路径
APP_BUNDLE="$OUTPUT_DIR/$(basename "$APP_BUNDLE")"
README_PATH="${APP_BUNDLE}/Contents/README.txt"

# 生成 README.txt
echo "4️⃣ creating README.txt..."
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || echo "0.0.0")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || echo "0")

# 确保 Resources 目录存在
mkdir -p "${APP_BUNDLE}/Contents/Resources"

README_PATH="${APP_BUNDLE}/Contents/Resources/README.txt"
{
    echo "App: ${APP_NAME}"
    echo "Version: ${SHORT_VERSION} (Build: ${BUILD_NUMBER})"
    echo "Build Date: $(date '+%Y-%m-%d %H:%M:%S')"
} > "$README_PATH"

echo "✅ README.txt created in Resources."

# 进行 Ad-hoc 签名
#echo "5️⃣ Ad-hoc signing..."
#codesign -s - -f --deep --entitlements "$ENTITLEMENTS_PATH" "$APP_BUNDLE"
#codesign -s - -f --deep "$APP_BUNDLE"
#codesign -s "FishDevCertificate" -f --deep "$APP_BUNDLE"


#if [ $? -ne 0 ]; then
#    echo "❌ 签名失败"
    exit 1
#fi
#echo "✅ Ad-hoc signed."

# 打包为 zip 文件
echo "6️⃣ packaging as .zip ..."
# 获取脚本所在目录（即项目根目录），保证无论从哪执行都能找到文件
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_GUIDE="$SCRIPT_DIR/安装说明.txt"

# 检查安装说明文件是否存在，然后复制到输出目录
if [ -f "$INSTALL_GUIDE" ]; then
    cp "$INSTALL_GUIDE" "$OUTPUT_DIR/"
    echo "✅ moved 安装说明.txt to output directory."
else
    echo "⚠️ file not found: $INSTALL_GUIDE"
fi
cd "$OUTPUT_DIR"
APP_NAME_ZIP="${APP_NAME}.zip"

# 优先使用 7z，如果没有则退回系统 zip
if command -v 7z &> /dev/null; then
    7z a -tzip -mcu "$APP_NAME_ZIP" . -xr!.DS_Store
    echo "✅ packaged as .zip (using 7z)"
else
    rm -f "$APP_NAME_ZIP"
    zip -ry "$APP_NAME_ZIP" "$(basename "$APP_BUNDLE")" -x "*.DS_Store"
    echo "✅ packaging as .zip"
fi

pkill -f "AutoPlan"

echo "🎉 All finished! Distribution package: $OUTPUT_DIR/$APP_NAME_ZIP"