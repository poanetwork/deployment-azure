# How to setup bootnode

## 1. Create azure account
If you already have Microsoft Azure account, you should [login to it](https://login.microsoftonline.com/) and then skip this section.  
To signup to Microsoft Azure follow [this link](https://account.azure.com/signup) and click "Create a new Microsoft account". Follow the steps of the registration process. You will need to provide and verify your email address and your credit card information.  
After registration is complete, do not sign out.

## 2. Generate SSH keys
SSH keys is a pair of cryptographic keys that will be used to access your virtual machine. Each pair consists of a _public key_ and a _private key_. Both of them will be stored on your current laptop/PC in separate files. Public key will then be copied to the virtual machine and used to verify your identity when you try to access it. As a consequence, the first connection can be made only from your current laptop/PC. While public key may be shared with anybody, you should never share your private key. Later, if need be, you'll be able to create additional key pairs on your other devices and access the virtual machine from them as well.

### Mac OS X
1. Open "Finder", choose Utilities from the "Go" menu.
2. Find the "Terminal.app" in the "Utilities" window.
3. Double-click to open the "Terminal.app".
4. Enter the following command in the terminal window and hit ENTER
```
ssh-keygen -t rsa
```
![SSH-term](https://raw.githubusercontent.com/oraclesorg/test-templates/dev/Docs/gen_ssh_term.png)

5. You'll be prompted to indicate where to store the keys. Accept the default location by hitting ENTER.
6. Next you'll be prompted for a passphrase (password). You can just hit ENTER to use this keypair without a passphrase, however, it is recommended that you provide a strong passphrase.
7. This completes the SSH keys generation procedure and you should see the confirmation in the terminal window. Do not close Terminal just yet.

### Windows PC
1. Download _PuTTY_ from its [official web page](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html). Under "Package files" select 32-bit or 64-bit version depending on your laptop/PC processor type and operating system edition. If unsure, download 32-bit version. After download is complete, double-click on the msi file and follow the installation steps.
2. Open the PuTTYgen program.
3. For "Type of key to generate", select RSA, for "Number of bits in a generated key" leave default value `2048`. 
4. Click the "Generate" button.
5. You'll need to randomly move your mouse in the area below the progress bar. These movements will be used to generate random numbers for the cryptographic functions. Continue until the progress bar is full.
6. Type a passphrase (password) into the "Key passphrase" and "Confirm passphrase" fields. You can use this keypair without a passphrase, however, it is recommended that you provide a strong passphrase.
![PuTTY](https://raw.githubusercontent.com/oraclesorg/test-templates/dev/Docs/Putty.png)

7. Click the "Save private key" button, select the folder you want to save this file to, enter filename, e.g. "private.ppk" and save the fule. Please note, that this file should be saved to a folder only you can access.
8. Click the "Save public key" button, select the folder you want to save this file to, enter filename, e.g. "public.ppk" and save the file.
9. Do not close PuTTY just yet.

## 3. Virtual machine setup.
On this step you will create azure virtual machine from a template by filling in a number of fields with data obtained on previous steps. After virtual machine deployment is complete, it will automatically start new Oracles-PoA network.

1. Hold <kbd>cmd ⌘</kbd> (on Mac OS X) or <kbd>CTRL</kbd> (on Windows PC) and click on the "Deploy to Azure" button below. This will open a separate browser tab, lead you to azure portal and launch "Custom deployment" wizard (alternatively, you can right-click on the button and select "Open in New Tab")  
[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Foraclesorg%2Ftest-templates%2Fdev%2FTestTestNet%2Fbootnode%2Ftemplate.json)

2. A new browser tab will be opened. Double-check address bar that you are connected to `https://portal.azure.com` and that secure connection sign is present (e.g. 🔒, exact representation may differ by browser). Fill the necessary fields as described below:
3. **Subscription**: Select the azure subsciption you want to link virtual machine to.
4. **Resource group**: Choose "Create new" Resource group and input a name for the resource group. This name will be displayed on your azure dashboard, it will not be used in the Oracles-PoA network, so choose a name that would make it clear _to you_ what this resource group represents. However, Azure imposes certain restrictions on a resource group name: it can only include upper case and lower case latin letters, numbers (e.g. _a_, _B_, _5_), periods, underscores, hyphens and parenthesis, cannot contain spaces (` `) and cannot end in a period. An example of a correct name is `oracles-poa`. After you've typed in the name, make sure a green check mark ✓ appears on the right.
5. **Location**: Select a location to where the virtual machine will be deployed.
6. **Node Full Name**: Enter full name of the bootnode. This will be displayed in the Oracles-PoA network usage info page and visible to other users of the network.
7. **Node Admin Email**: Enter admin email address for your network.
8. **Owner Key File**: Open owner's keyfile in a text editor (e.g. "TextEdit.app" on Mac OS X or Notepad on Windows). The content of this file is in JSON format (should consist of words in double-quotes `"` separated from other words or numbers by semicolons `:`, nested into curly brackets `{...}`). Select this file's _entire content_, copy it and paste into this field. When you paste it, the actual content will not be displayed, because it is treated as a secured password, instead you'll see black dots.

At this step, you should see a window similar to this (values will be different in your case)
![wizard-1](https://raw.githubusercontent.com/oraclesorg/test-templates/dev/Docs/deployment1.png)

9. **Owner Keypass**: Enter owner's passphrase (password) for the mining key. The content of the field will be hidden, instead you'll see black dots.
10. **Admin username**: Think up a login account name on your virtual machine. It may contain only lower case latin letters and numbers, also it should start with a letter. An example of a valid username is `azureuser`. This name will not be used in the Oracles-PoA network, and is only used to identify you when connecting to the virtual machine.

11. **Ssh Public Key**:  
* _On Mac OS X_: switch to the "Terminal" application opened on the previous step and paste the following command into the terminal, then hit ENTER
```
pbcopy < ~/.ssh/id_rsa.pub
```
This command will copy your public key to your clipboard. Then switch back to your browser and paste it into this field. Note that you should not copy anything in-between, otherwise your clipboard will be overwritten and you'll have to redo this step. After pasting check that the key starts with `ssh-rsa`.  
* _On Windows_: Switch back to PuTTY and right-click in the text field labeled "Public key for pasting into OpenSSH authorized_keys file", choose "Select All", then right-click again in the same text field and choose "Copy". Paste selected text into this field. After pasting check that the key starts with `ssh-rsa`.

12. **Netstats Secret**: Think up a secret code that will be used by mining nodes to connect to the netstats server. This code should be be provided to all miners.
13. Carefully read "Terms and conditions" section provided by Azure and click "I agree" checkbox below if you do agree.
14. Check "Pin to dashboard" checkbox at the bottom of the page. This will put virtual machine on your azure dashboard, making it easy to access.

Second half of the fields should look similar to this (values will be different in your case)
![wizard-2](https://raw.githubusercontent.com/oraclesorg/test-templates/dev/Docs/deployment2.png)

15. Click "Purchase". In case of errors please double check that you have completed the steps above and all fields are filled with correct values. If the error persists you can file a bug report [here](https://github.com/oraclesorg/test-templates/issues/new). Please provide as detailed a description as possible, one or several screenshots, so that values in all fields will be visible to us. Also provide a screenshot with the error message.

16. After that, you will be taken to your azure dashboard. Look for a box similar to this  
![Deployment in progress](https://raw.githubusercontent.com/oraclesorg/test-templates/dev/Docs/deploy_new_deployment.png)  
representing deployment process of the resource group. Do not close this windows and wait till the process is complete and you'll be automatically forwarded to a newly-created resource group page.  
This is a list of resources that should have been deployed:
![resources](https://raw.githubusercontent.com/oraclesorg/test-templates/dev/Docs/deployed-resources.png)  
Click on the Virtual Machine from this list, wait till the page with details is opened and copy IP address (e.g. `8.8.8.8`).

## 4. Post-installation
After the deployment process is complete, you should login to the virtual machine by typing in terminal window
```
ssh $ADMIN_USERNAME@$IP_ADDRESS
```
instead of `$ADMIN_USERNAME` substitute the admin username you have provided at the previous step (e.g. `azureuser`); instead of `$IP_ADDRESS` substitute actual IP adress of the virtual machine. Note to keep the `@` between username and IP address (e.g.`ssh azureuser@8.8.8.8`). You will be prompted to enter your ssh password, if you provided it while generating ssh keypair.

