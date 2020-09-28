#!/bin/bash

function quit {
  rm -rf "${TEMP_DIR}"
  exit
}

###
# Setting main variables
###
IPA="/path/myapp.ipa"
MOBILEPROVISION="/path/embedded.mobileprovision"
SIGNIDENTITY="11AAB23344CC22DD3FD023372312A600AA11DA78"
BUNDLE_ID="com.mysite.myapp"

###
# Setting extra variables
###
FRIDA_URL="https://build.frida.re/frida/ios/lib/FridaGadget.dylib"

###
# Preparing the environment
##
TEMP_DIR="$(mktemp -d /tmp/ipa-patching.XXXXX)"
TOOLS_DIR="/tmp/ipa-patching-tools"
FRIDA_FILENAME="FridaGadget.dylib"
FRIDA_PATH="${TOOLS_DIR}/${FRIDA_FILENAME}"
OUTFILE="patched-app.ipa"

if [ ! -d "$TOOLS_DIR" ]; then
    if ! brew ls --versions node > /dev/null; then
        brew install node
    fi
    mkdir -p "${TOOLS_DIR}"
    cd "${TOOLS_DIR}" || quit
    npm install applesign ios-deploy
    ln -s node_modules/.bin/applesign .
    ln -s node_modules/.bin/ios-deploy .
    curl -LO https://github.com/alexzielenski/optool/releases/download/0.1/optool.zip && unzip optool.zip
    curl -LO "${FRIDA_URL}"
fi

APPLESIGN="${TOOLS_DIR}/applesign"
IOSDEPLOY="${TOOLS_DIR}/ios-deploy"
OPTOOL="${TOOLS_DIR}/optool"

###
# Extracting target ipa
###
cd "${TEMP_DIR}" || quit
unzip "${IPA}" > /dev/null

###
# Injecting Frida gadgets
###
cd Payload/*.app || quit
cp ${FRIDA_PATH} Frameworks/
EXECUTABLE=$(plutil -convert xml1 -o - Info.plist | xmllint --xpath 'string(/plist/dict/key[text()="CFBundleExecutable"]/following-sibling::string)' -)
${OPTOOL} install -c load -p "@executable_path/Frameworks/${FRIDA_FILENAME}" -t "${EXECUTABLE}"

###
# Replacing bundle id in plugins
###
cd PlugIns || quit
for PLUGIN in *; do
  if [ -d "${PLUGIN}" ]; then
    BUNDLE_NAME=$(plutil -convert xml1 -o - "${PLUGIN}/Info.plist" | xmllint --xpath 'string(/plist/dict/key[text()="CFBundleName"]/following-sibling::string)' -)
    plutil -replace CFBundleIdentifier -string "${BUNDLE_ID}.${BUNDLE_NAME}" "${PLUGIN}/Info.plist"
  fi
done

###
# Repacking
###
cd "${TEMP_DIR}" || quit
zip -qr "${OUTFILE}" Payload > /dev/null

###
# Signing
###
${APPLESIGN} -r -all -b "${BUNDLE_ID}" -B -i "${SIGNIDENTITY}" -m "${MOBILEPROVISION}" -c "${OUTFILE}"

###
# Deploying
###
unzip -o "${OUTFILE}" > /dev/null
${IOSDEPLOY} -L -W -b Payload/*.app

quit