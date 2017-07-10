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
![SSH-term](https://raw.githubusercontent.com/oraclesorg/test-templates/master/Ceremony/gen_ssh_term.png)

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
![PuTTY](https://raw.githubusercontent.com/oraclesorg/test-templates/master/Ceremony/Putty.png)

7. Click the "Save private key" button, select the folder you want to save this file to, enter filename, e.g. "private.ppk" and save the fule. Please note, that this file should be saved to a folder only you can access.
8. Click the "Save public key" button, select the folder you want to save this file to, enter filename, e.g. "public.ppk" and save the file.
9. Do not close PuTTY just yet.

## 3. Virtual machine setup.
