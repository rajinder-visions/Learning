# ⚙️ LinuxMint MATE 20 (Ulyana) -> Ubuntu Focal Fossa 20.04 LTS

## 🚀 Full Conversion Steps

## i) listing of packages from known repository:
```
cat > find_origin.sh << \EOF
LC_ALL=C dpkg-query --showformat='${Package}:${Status}\n' -W '*' | \
fgrep ':install ok installed' | cut -d: -f1 | \
(while read pkg; do inst_version=$(apt-cache policy $pkg \
| fgrep Installed: \
| awk '{ print $2 }'); origin=$(apt-cache policy "$pkg" \
| fgrep " *** ${inst_version}" -C1 \
| tail -n 1 \
| cut -c12-); echo $pkg $origin; done)
EOF
```
## ii) 🔍 Find Mint packages and remove them:
```
sh find_origin.sh | grep packages.linuxmint.com > mint-packages-all.txt
cat mint-packages-all.txt | grep -v "E:" | grep -v ^bash | grep -v ^base-files | grep -v ^mintsources | grep -v grub > mint-packages-remove.txt
sudo apt-get install aptitude
sudo aptitude purge $(cat mint-packages-remove.txt | awk '{print $1}')
sudo sed -i 's/^deb http:\/\/packages.linuxmint.com/#deb http:\/\/packages.linuxmint.com/g' /etc/apt/sources.list.d/official-package-repositories.list
sudo rm /etc/apt/preferences.d/official-package-repositories.pref
```
