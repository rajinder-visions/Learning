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

## iii) Set all packages from Obsolete and Locally Created Packages section to purge.
```
sudo aptitude
```

## iv) Check locally installed packages with:
```
sh find_origin.sh | grep /var
```

## v) Reinstall two (maybe more!) packages listed here - bash and base-files from focal-updates repository from terminal:
```
sudo apt-get install base-files=11ubuntu5 xapps-common=1.6.10-2
```

## vi) Then purge all packages that does not have ii state (such as rc) with:
```
sudo apt-get purge $(dpkg -l | grep -v ^ii | tail -n +6 | awk '{print $2}')
sudo apt-get install linux-image-generic linux-headers-generic
sudo locale-gen en_US.UTF-8
```

## vii) Remove Mint files from home directory:

```
rm -rf ~/.linuxmint/
```

## viii) Check system integrity with debsums:
```
sudo apt-get install debsums
sudo debsums_init
sudo debsums -a -c # carefully check all files listed here with `dpkg -S filepath`

sudo apt-get install --reinstall caja casper compton cups-filters engrampa gnome-icon-theme gnome-accessibility-themes im-config imagemagick libgs9 mate-desktop mate-icon-theme mate-screensaver mate-screensaver-common mate-system-monitor mate-utils openjdk-11-jre sound-theme-freedesktop imagemagick-6.q16 libreoffice-draw libreoffice-math gnome-colors-common vino gnome-orca adwaita-icon-theme-full info
sudo apt-get -o Dpkg::Options::="--force-confask" install --reinstall acpid libcompizconfig0 mate-menus systemd xdg-user-dirs-gtk vino casper # select Y
```

## ix) Then check system for files, that are not from Ubuntu repositories:
```
sudo find /bin /etc /lib /lib64 /opt /sbin /srv /usr /var -type f -exec dpkg -S {} \; 2> ~/Desktop/results.out

```

## x) Remove the following objects (may be others!):
```
sudo rm -rf /etc/linuxmint
sudo rm -rf /usr/lib/linuxmint
sudo rm /usr/lib/python3/dist-packages/__pycache__/mintreport.cpython-38.pyc
```

## xi) And finally install Ubuntu MATE desktop on first login:
```
sudo apt-get install lightdm-gtk-greeter ubuntu-mate-lightdm-theme ubuntu-mate-themes ubuntu-mate-wallpapers* ubuntu-mate-core ubuntu-mate-default-settings ubuntu-mate-artwork ubuntu-mate-icon-themes plymouth-theme-ubuntu-mate-logo plymouth-theme-ubuntu-mate-text grub2-themes-ubuntu-mate mate-tweak ubuntu-mate-guide caja-eiciel compiz-mate eom mate-accessibility-profiles mate-applet-appmenu mate-applet-brisk-menu mate-calc mate-dock-applet mate-hud mate-menu mate-netbook mate-optimus mate-user-guide mate-window-applets-common mate-window-buttons-applet mate-window-menu-applet mate-window-title-applet folder-color-caja deja-dup-caja gsettings-ubuntu-schemas indicator-messages indicator-power indicator-session indicator-sound brasero shotwell simple-scan smbclient ubuntu-standard vlc gdebi gdebi-core plank seahorse tilda

```

## xii) Reset MATE desktop settings to the defaults:

```
dconf reset -f /org/mate
gsettings set org.mate.panel default-layout "'default'"
```

## xiii) Install MATE Welcome and Software Boutique as Snaps:

```
sudo snap install software-boutique --classic
sudo snap install ubuntu-mate-welcome --classic
```


# Note: Donot Reboot System
