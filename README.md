# kali

## Usage
```
git clone https://github.com/jsdlm/kali.git
cd kali
chmod +x ./install.sh
sudo ./install.sh
```

Sans argument, le script demande interactivement le nom d'utilisateur et le mode d'installation.

### Arguments

| Argument | Description | Défaut |
|---|---|---|
| `-u`, `--user` | Nom du user pentester | `pentester` |
| `-m`, `--mode` | Mode d'installation (`full` ou `oscp`) | interactif |

```
sudo ./install.sh -u monuser -m full
sudo ./install.sh -m oscp
```

### Modes d'installation

**`full`** — installation complète :
- Setup système de base + personnalisations
- ktrace, outils pentest APT, outils pipx
- Clonage des repos
- Burp Suite Pro, Docker, BloodHound CE, Nessus

**`oscp`** — installation légère orientée OSCP :
- ktrace
- Clonage des repos
- Docker
- BloodHound CE

## Post-setup steps
- Put Nessus ACTIVATION_CODE in $NESSUS_DIR/docker-compose.yml
- Burp Suite Pro preferences:
```
cp root_prefs.xml -d /root/.java/.userPrefs/burp/prefs.xml
cp pentester_prefs.xml -d /home/pentester/.java/.userPrefs/burp/prefs.xml
```
