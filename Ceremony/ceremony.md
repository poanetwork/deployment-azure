# Steps to join Oracles-PoA network

## 1. Obtain initial key

## 2. Exchange initial key for mining, voting key and payout keys

## 3. Create azure account

## 4. Generate SSH keys
SSH keys is a pair of cryptographic keys that will be used to access your virtual machine. Each pair consists of a _public key_ and a _private key_. Both of them will be stored on your current laptop/PC in separate files. Public key will then be copied to the virtual machine and used to verify your identity when you try to access it. As a consequence, the first connection can be made only from your current laptop/PC. While public key may be shared with anybody, you should never share your private key. Later, if need be, you'll be able to create additional key pairs on your other devices and access the virtual machine from them as well.

### Mac OS X
1. Open "Finder", choose Utilities from the "Go" menu.
2. Find the "Terminal.app" in the "Utilities" window.
3. Double-click to open the "Terminal.app".
4. Enter the following command in the terminal window and hit ENTER 
```
ssh-keygen -t rsa
```
![SSH-term](https://raw.githubusercontent.com/oraclesorg/test-templates/master/Ceremony/gen_ssh_term.png).

5. You'll be prompted to indicate where to store the keys. Accept the default location by hitting ENTER.
6. Next you'll be prompted for a passphrase (password). You can just hit ENTER to use this keypair without a passphrase, however, it is recommended that you provide a strong passphrase.
7. This completes the SSH keys generation procedure and you should see the confirmation in the terminal window. Do not close Terminal just yet.

### Windows PC

## 5. Virtual machine setup.
This is the final step, on which you will create azure virtual machine from a template by filling in a number of fields with data obtained on previous steps. After virtual machine deployment is complete, it will automatically join the Oracles-PoA network and all corresponding activities (voting, payout) will become available to you.

1. Hold <kbd>cmd ⌘</kbd> (on Mac OS X) or <kbd>CTRL</kbd> (on Windows PC) and click on the "Deploy to Azure" button below. This will open a separate browser tab, lead you to azure portal and launch "Custom deployment" wizard (alternatively, you can right-click on the button and select "Open in New Tab")  
[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Foraclesorg%2Ftest-templates%2Fmaster%2FTestTestNet%2Fmining-node%2Ftemplate.json)

2. You should see a window similar to this
![wizard-1a](https://github.com/oraclesorg/test-templates/blob/master/Ceremony/deploy_wizard1a.png?raw=true)  
Double check address bar that you are connected to `https://portal.azure.com` and that "Secure" sign is present.

3. Select the azure subsciption you want to use.
4. Click to "Create new" Resource group and input a name for the resource group. This name will be displayed on your azure portal dashboard, it will not be used in the Oracles-PoA network, so choose a name that would make it clear _to you_ what this resource group represents. However, Azure imposes certain restrictions on a resource group `name`: it can only include upper case and lower case latin letters, numbers (e.g. _a_, _B_, _Z_, _5_, ...), periods, underscores, hyphens and parenthesis, cannot contain spaces (` `) and cannot end in a period. An example of a correct `name` is "oracles-poa". After you've typed in the name in the input, make sure a green check mark ✓ appears on the right.



5. 
