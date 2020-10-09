#!/bin/bash

function crash {
  echo "[-] Something went wrong"
  quit
}

function quit {
  echo "[+] Done"
  rm -rf "${TEMP_DIR}"
  exit
}

###
# Setting main variables
###
IPA="/path/myapp.ipa"
MOBILEPROVISION="/path/embedded.mobileprovision"
SIGN_IDENTITY="11AAB23344CC22DD3FD023372312A600AA11DA78"
BUNDLE_ID="com.mysite.myapp"

###
# Setting extra variables
###
VERBOSE=false
FRIDA_URL="https://build.frida.re/frida/ios/lib/FridaGadget.dylib"

###
# Preparing the environment
##
if $VERBOSE; then
  STDOUT=/dev/stdout
else
  STDOUT=/dev/null
fi
TEMP_DIR="$(mktemp -d /tmp/ipa-patching.XXXXX)"
TOOLS_DIR="/tmp/ipa-patching-tools"
FRIDA_FILENAME="${FRIDA_URL##*/}"
FRIDA_PATH="${TOOLS_DIR}/${FRIDA_FILENAME}"
OUTFILE="patched-app.ipa"

echo "IPA patching started..."

if [ ! -d "$TOOLS_DIR" ]; then
  echo "[+] Installing dependencies"
  {
    if ! brew ls --versions node > /dev/null; then
        brew install node || crash
    fi
    mkdir -p "${TOOLS_DIR}"
    cd "${TOOLS_DIR}" || crash
    npm install applesign ios-deploy || crash
    ln -s node_modules/.bin/applesign .
    ln -s node_modules/.bin/ios-deploy .
    curl -LO https://github.com/alexzielenski/optool/releases/download/0.1/optool.zip || crash
    unzip optool.zip
  } &> $STDOUT
fi

echo "[+] Downloading Frida Gadget"
cd "${TOOLS_DIR}" || crash
curl -sLO "${FRIDA_URL}" > /dev/null || crash

APPLESIGN="${TOOLS_DIR}/applesign"
IOSDEPLOY="${TOOLS_DIR}/ios-deploy"
OPTOOL="${TOOLS_DIR}/optool"

###
# Extracting target ipa
###
echo "[+] Extracting target IPA"
cd "${TEMP_DIR}" || crash
unzip "${IPA}" > /dev/null || crash

###
# Injecting Frida Gadget
###
echo "[+] Injecting Frida Gadget"
{
  cd Payload/*.app || crash
  cp ${FRIDA_PATH} Frameworks/
  EXECUTABLE=$(plutil -convert xml1 -o - Info.plist | xmllint --xpath 'string(/plist/dict/key[text()="CFBundleExecutable"]/following-sibling::string)' -)
  ${OPTOOL} install -c load -p "@executable_path/Frameworks/${FRIDA_FILENAME}" -t "${EXECUTABLE}" || crash
} &> $STDOUT

###
# Replacing bundle id in plugins
###
{
  cd PlugIns || crash
  for PLUGIN in *; do
    if [ -d "${PLUGIN}" ]; then
      BUNDLE_NAME=$(plutil -convert xml1 -o - "${PLUGIN}/Info.plist" | xmllint --xpath 'string(/plist/dict/key[text()="CFBundleName"]/following-sibling::string)' -)
      plutil -replace CFBundleIdentifier -string "${BUNDLE_ID}.${BUNDLE_NAME}" "${PLUGIN}/Info.plist"
    fi
  done
} > /dev/null || crash

###
# Repacking
###
echo "[+] Repacking and signing patched IPA"
cd "${TEMP_DIR}" || crash
zip -qr "${OUTFILE}" Payload > /dev/null || crash

###
# Signing
###
${APPLESIGN} -r -all -b "${BUNDLE_ID}" -B -i "${SIGN_IDENTITY}" -m "${MOBILEPROVISION}" -c "${OUTFILE}" > $STDOUT || crash

###
# Deploying
###
echo "[+] Deploying on device over USB and launch the app"
unzip -o "${OUTFILE}" > /dev/null
${IOSDEPLOY} -L -W -b Payload/*.app > $STDOUT || crash

quit