# ipa-patching.sh

The `ipa-patching.sh` script patches the app's IPA and signs the code to load `FridaGadget.dylib` on start without jailbreak.

# Dependencies

Script requires [brew](https://github.com/Homebrew/brew)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

# Usage

Before patching IPA, you need to set a number of variables.

## Main variables

- `IPA` - path to the IPA file that needs to be patched.
- `MOBILEPROVISION` - path to your .mobileprovision file, how to generate it see [here](https://0xn3va.gitbook.io/cheat-sheets/ios-application/getting-started/ipa-patching).
- `SIGN_IDENTITY` - your code sign identity, can be found like this:

    ```bash
    $ security find-identity -v -p codesigning
    
    1) 11AA22BB*** "Apple Development: *****@icloud.com (ABCDEF1234)"
         1 valid identities found
    
    # 11AA22BB*** - code sign identity
    ```

- `BUNDLE_ID` - your bundle id from .mobileprovision file.
- `FRIDA_URL` - link to Frida's gadget, supports `file://` scheme for local files. You can find up-to-date gadgets at [https://github.com/frida/frida/releases](https://github.com/frida/frida/releases)

## Extra variables

- `VERBOSE` - verbose mode.

## Patching

After all the variables are set, just run the script.

```bash
./ipa-patching.sh
```
