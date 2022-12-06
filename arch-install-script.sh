#!/usr/bin/zsh
# firstly install zsh or just use bash instead.

function printascii {
    echo '\n'
    echo '          _____                    _____                _____'
    sleep 0.1
    echo '         /\    \                  /\    \              /\    \'
    sleep 0.1
    echo '        /::\____\                /::\    \            /::\    \'
    sleep 0.1
    echo '       /::::|   |               /::::\    \           \:::\    \'
    sleep 0.1
    echo '      /:::::|   |              /::::::\    \           \:::\    \'
    sleep 0.1
    echo '     /::::::|   |             /:::/\:::\    \           \:::\    \'
    sleep 0.1
    echo '    /:::/|::|   |            /:::/__\:::\    \           \:::\    \'
    sleep 0.1
    echo '   /:::/ |::|   |           /::::\   \:::\    \          /::::\    \'
    sleep 0.1
    echo '  /:::/  |::|___|______    /::::::\   \:::\    \        /::::::\    \'
    sleep 0.1
    echo ' /:::/   |::::::::\    \  /:::/\:::\   \:::\____\      /:::/\:::\    \'
    sleep 0.1
    echo '/:::/    |:::::::::\____\/:::/  \:::\   \:::|    |    /:::/  \:::\____\'
    sleep 0.1
    echo '\::/    / ~~~~~/:::/    /\::/   |::::\  /:::|____|   /:::/    \::/    /'
    sleep 0.1
    echo ' \/____/      /:::/    /  \/____|:::::\/:::/    /   /:::/    / \/____/'
    sleep 0.1
    echo '             /:::/    /         |:::::::::/    /   /:::/    /'
    sleep 0.1
    echo '            /:::/    /          |::|\::::/    /   /:::/    /'
    sleep 0.1
    echo '           /:::/    /           |::| \::/____/    \::/    /'
    sleep 0.1
    echo '          /:::/    /            |::|  ~|           \/____/'
    sleep 0.1
    echo '         /:::/    /             |::|   |'
    sleep 0.1
    echo '        /:::/    /              \::|   |'
    sleep 0.1
    echo '        \::/    /                \:|   |'
    sleep 0.1
    echo '         \/____/                  \|___|'
}

function cont {
	echo "[SUCCESS] Continue to next step? [Y/n] "
	read -r contin
	case $contin in
		[Nn][oO]|[nN])
			exit
			;;
		*)
			;;
	esac
}

function base {
	echo "Starting installation of packages in selected root drive..."
	sleep 1
	pacman -Syu
	pacstrap /mnt base base-devel linux linux-firmware diffutils e2fsprogs inetutils less networkmanager sudo bash-completion git vim exfat-utils ntfs-3g grub os-prober \
			 efibootmgr htop vlc pacman-contrib chromium firefox zsh-autosuggestions zsh-syntax-highlighting zsh-theme-powerlevel10k zsh-completions zsh-history-substring-search
	genfstab -U /mnt >> /mnt/etc/fstab
	cont
}

function install_grub {
	echo "Install GRUB bootloader? [y/N] " 
	read -r igrub
	case "$igrub" in
		[yY][eE][sS]|[yY])
			echo -e "Installing GRUB.."
			arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch && grub-mkconfig -o /boot/grub/grub.cfg && exit"
			;;
		*)
			;;
	esac
}

function encrypt_home {
	echo "Enter your device path and name: "
	read -r dev_path
	cryptsetup -y -v luksFormat $dev_path
	cryptsetup open $dev_path home
	mkfs.ext4 /dev/mapper/home
	mount /dev/mapper/home /mnt/home
}

function install_microcode {
	echo "Install microcode for stability and security fixes ? Y/N "
    read -r microcode
    case $microcode in 
        [yY][eE][sS]|[Yy])
		echo "1.Amd 2.Intel choose one ? 1/2 " 
        read -r processor
        case $processor in
            1)
            arch-chroot /mnt bash -c "pacman -S amd-ucode"
            ;;
            2)
            arch-chroot /mnt bash -c "pacman -S intel-ucode"
            ;;
            esac
        ;;
        *)
        cont
        ;;
    esac
    # regenarate the grub config
    arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg" 
}

function mounting {
	echo "which is your root partition? "
	read -r rootp
	mkfs.ext4 $rootp
	mount $rootp /mnt
	mkdir /mnt/boot
	echo "Enter your boot partition: " 
	read -r bootp
	mount $bootp /mnt/boot
	echo "Do you want to use a seperate home partition? [y/N] " 
	read -r responsehome
	case "$responsehome" in
		[yY][eE][sS]|[yY])
			encrypt_home
			;;
		*)
			;;
	esac
	echo "Enter swap partition path and name:  " 
	read -r swappart
	swapon $swappart
	cont
}

function archroot {
	echo "Enter the username: "
	read -r uname
	echo "Enter the hostname: " 
	read -r hname

	echo -e "Setting up Region and Language\n"
	echo -e "please enter your region: "
	read -r local
	arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/$local /etc/localtime && hwclock --systohc && sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen && echo 'LANG=en_US.UTF-8' > /etc/locale.conf && exit"

    echo -e "Setting up keyboard...\n please enter your keyboard layout:"
	read -r keyboard
    localectl set-keymap --no-convert $keyboard
	echo -e "Setting up Hostname\n"
	hostnamectl set-hostname $hostname

	echo "Set Root password"
	arch-chroot /mnt bash -c "passwd && useradd -m -s /bin/zsh $uname && echo 'set user password' && passwd $uname && groupadd sudo && gpasswd -a $uname sudo && EDITOR=nano visudo && exit"

	echo -e "enabling services...\n"
	arch-chroot /mnt bash -c "systemctl enable bluetooth && exit"
	arch-chroot /mnt bash -c "systemctl enable NetworkManager && exit"

	echo -e "enabling paccache timer...\n"
	arch-chroot /mnt bash -c "systemctl enable paccache.timer && exit"

	echo -e "zsh autocompletion config editing.."
	arch-chroot /mnt bash -c "echo 'source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /home/$uname/.zshrc"
	arch-chroot /mnt bash -c "echo 'source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-auto-suggestions.zsh' >> /home/$uname/.zshrc"
	cont
}

function install-amd {
	pacstrap /mnt mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
	pacstrap /mnt libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau
}

function install-nvidia {
	echo "Do you want to install Nvidia drivers? [y/N] "
	read -r graphic
	case "$graphic" in
		[yY][eE][sS]|[yY])
			pacstrap /mnt nvidia nvidia-settings nvidia-utils lib32-nvidia-utils
			;;
		*)
			;;
	esac
	cont
}

function install_kde {
    echo '\nDo you want to install Kde Plasma and apps Y/N ?'
    read kdeinstal
    case $kdeinstal in
        [yY][eE][Ss]|[yY])
        pacstrap /mnt xorg plasma sddm
	    arch-chroot /mnt bash -c "systemctl enable sddm && exit"
	    pacstrap /mnt ark dolphin ffmpegthumbs gwenview kaccounts-integration kate yakuake kdialog kio-extras konsole ksystemlog \
        okular print-manager nano neofetch 
        ;;
        *)
        ;;
    esac
}

function set-time {
	echo "Setting time...."
	timedatectl set-local-rtc 1 --adjust-system-clock
}

function installation {
    printascii
    set-time
    mounting
    base
    install_kde
    archroot
    install_microcode
    install-amd
    install-nvidia
    install_grub
}

echo 'Do you want to start installation Y/N ?'
read confirm
case $confirm in
    [yY][eE][sS]|[Yy])
    installation
    ;;
    *)
    exit
    ;;
esac
