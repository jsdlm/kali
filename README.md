# kali

## Usage
```
git clone https://github.com/jsdlm/kali.git
cd kali
chmod +x ./install.sh
sudo ./install.sh
```

## Post-setup steps
- Put Nessus ACTIVATION_CODE in $NESSUS_DIR/docker-compose.yml
- Burp Suite Pro preferences:
```
cp root_prefs.xml -d /root/.java/.userPrefs/burp/prefs.xml
cp pentester_prefs.xml -d /home/pentester/.java/.userPrefs/burp/prefs.xml
```
