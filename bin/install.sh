# Exit when return is non-zero
set -e

# Return the exit code of the right most command
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

# Choose a user account to use for the installation
# use export TARGET_USER=<username>
get_user() {
	if [[ -z "${TARGET_USER}" ]]; then
		mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)

		if [[ -z "${TARGET_USER}" ]]; then
			echo "Please create a user or use the TARGET_USER variable"
			exit 1
		fi

		# if there is only one option just use that user
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi

		# iterate through the user options and print them
		PS3='command -v user account should be used? '

		select opt in "${options[@]}"; do
			readonly TARGET_USER=$opt
			break
		done
	fi
}

# Check if user has root permissions
check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root."
		exit
	fi
}


setup_sources() {
	echo "[*] Setting up sources"
	# Prep Docker installation
	curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
		$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
}

install_chrome() {
	sudo mkdir -p /etc/docker/seccomp/
	sudo wget https://raw.githubusercontent.com/jfrazelle/dotfiles/master/etc/docker/seccomp/chrome.json -O /etc/docker/seccomp/chrome.json
}

initial() {
	echo "[*] INSTALLING INITIAL PACKAGES"
	apt install -y \
		systemd-timesyncd --no-install-recommends
		
	apt install -y \
		ntp --no-install-recommends

	apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dirmngr \
		gnupg2 \
		lsb-release --no-install-recommends
}

user_exists() {
	echo "[*] Checking if the user $TARGET_USER exists"
	if [[ ! $(id -u $TARGET_USER) ]]; then
		echo "The user $TARGET_USER does not exist"
		apt update || true 
		apt install -y adduser
		adduser $TARGET_USER
		usermod -s /bin/bash $TARGET_USER
	fi
}

base() {
	initial

	user_exists

	setup_sources

	# Install Plasma
	install_desktop

	apt update
	apt upgrade -y
	apt install -y \
		adduser \
		apparmor \
		automake \
		bash-completion \
		bc \
		bridge-utils \
		bzip2 \
		ca-certificates \
		cgroupfs-mount \
		containerd.io \
		coreutils \
		curl \
		dnsutils \
		docker-ce \
		docker-ce-cli \
		docker-compose-plugin \
		file \
		findutils \
		fwupd \
		fwupdate \
		gcc \
		git \
		gnupg \
		gnupg2 \
		gnupg-agent \
		grep \
		gzip \
		hostname \
		indent \
		iptables \
		iwd \
		jq \
		less \
		libapparmor-dev \
		libc6-dev \
		libimobiledevice6 \
		libltdl-dev \
		libpam-systemd \
		libpcsclite-dev \
		libseccomp-dev \
		locales \
		lsof \
		lynx \
		make \
		mount \
		net-tools \
		pcscd \
		pinentry-curses \
		policykit-1 \
		python3 \
		python3-pip \
		scdaemon \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		systemd \
		tar \
		tree \
		tzdata \
		unzip \
		vim \
		zip --no-install-recommends

	apt autoremove -y
	apt autoclean -y
	apt clean -y

	setup_sudo

	# Create a symlinc for python
	if [[ -z /usr/bin/python ]]; then
		sudo ln -s /usr/bin/python3 /usr/bin/python
	fi
	
	# create apt sandbox user
	if [[ ! $(id -u $TARGET_USER) ]]; then
		echo "[!] Creating the apt sandbox user _apt"
		sudo useradd --system "_apt"
	fi
	
	install_scripts
	install_dotfiles
}

# install custom scripts/binaries
install_scripts() {
	echo "[*] Installing scripts"
	# install speedtest
	curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /usr/local/bin/speedtest
	chmod +x /usr/local/bin/speedtest

		# install lolcat
	curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /usr/local/bin/lolcat
	chmod +x /usr/local/bin/lolcat

    if [[ ! -d /home/$TARGET_USER/dotfiles ]]; then
		git clone git@github.com:man715/dotfiles.git /home/$TARGET_USER/dotfiles
		chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/dotfiles
    fi
	
    runuser -l $TARGET_USER -c 'cd ${HOME}/dotfiles && make scripts' 
	chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER

}

# Setup sudo for a user
setup_sudo() {
	echo "[*] Setting up sudo permissions for $TARGET_USER"

	# add user to sudoers
	adduser "$TARGET_USER" sudo

	# add user to systemd groups
	# then you wont need sudo to view logs and shit
	gpasswd -a "$TARGET_USER" systemd-journal
	gpasswd -a "$TARGET_USER" systemd-network

	sudo gpasswd -a "$TARGET_USER" docker

	# add go path to secure path
	{ \
		echo -e "Defaults	secure_path=\"/usr/local/go/bin:/home/${TARGET_USER}/.go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/bcc/tools:/home/${TARGET_USER}/.cargo/bin\""; \
		echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy GOPATH EDITOR"'; \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers

	# setup downloads folder as tmpfs
	# that way things are removed on reboot
	# i like things clean but you may not want this
	mkdir -p "/home/$TARGET_USER/Downloads"
	echo -e "\\n# tmpfs for downloads\\ntmpfs\\t/home/${TARGET_USER}/Downloads\\ttmpfs\\tnodev,nosuid,size=50G\\t0\\t0" >> /etc/fstab
}

# install graphics drivers
install_graphics() {
	local system=$1

	if [[ -z "$system" ]]; then
		echo "You need to specify whether it's intel, geforce or optimus"
		exit 1
	fi

	local pkgs=( xorg xserver-xorg xserver-xorg-input-libinput xserver-xorg-input-synaptics )

	case $system in
		"intel")
			pkgs+=( xserver-xorg-video-intel )
			;;
		"geforce")
			pkgs+=( nvidia-driver )
			;;
		"optimus")
			pkgs+=( nvidia-kernel-dkms bumblebee-nvidia primus )
			;;
		"amd")
			pkgs+=(firmware-amd-graphics libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers xserver-xorg-video-all)
			;;
		"vm")
			;;
		*)
			echo "You need to specify whether it's intel, geforce or optimus"
			exit 1
			;;
	esac

	apt update || true
	apt -y upgrade

	apt install -y "${pkgs[@]}" --no-install-recommends
}


install_desktop() {
	apt update
	apt -y upgrade
	apt install -y \
		xorg \
		xserver-xorg \
		xserver-xorg-input-libinput \
		xserver-xorg-input-synaptics\
		xz-utils \
		plasma-desktop \
		kwin-x11 \
		dolphin \
		kate \
		konsole \
		sddm
}

# Install tmux
install_tmux() {
	sudo apt update || true
	sudo apt install -y \
		tmux --no-install-recommends
	
	git clone https://github.com/tmux-plugins/tpm /home/$TARGET_USER/.tmux/plugins/tpm
	wget https://raw.githubusercontent.com/man715/linux_configs/main/.tmux.conf -O /home/$TARGET_USER/.tmux.conf
}

# Install vim
install_vim() {
	sudo apt update || true
	sudo apt install -y \
		vim --no-install-recommends
	curl -fLo /home/$TARGET_USER/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	wget https://raw.githubusercontent.com/man715/linux_configs/main/.vimrc -O /home/$TARGET_USER/.vimrc
	echo "[*] Open vim and run 'PlugInstall'"

}

install_dotfiles() {
	echo "[*] Installing dot files"
	if [[ ! -d /home/$TARGET_USER/dotfiles ]]; then
        git clone git@github.com:man715/dotfiles.git /home/$TARGET_USER/dotfiles
		chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/dotfiles
    fi
    runuser -l $TARGET_USER -c 'cd ${HOME}/dotfiles && make dotfiles'
	chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER
}

web3() {
	sudo apt update || true
	sudo apt-get install -y \
		automake \
		bzip2 \
		cmake \
		curl \
		build-essential \
		gcc \
		libbz2-dev \
		libffi-dev \
		liblzma-dev \
		libncurses5-dev \
		libreadline-dev \
		libssl-dev \
		libsqlite3-dev \
		libtool \
		libxml2-dev \
		libxmlsec1-dev \
		llvm \
		make \
		perl \
		snapd \
		solc \
		sqlite \
		tk-dev \
		wget \
		xz-utils \
		zlib1g-dev --no-install-recommends
	
	install_rdp
	install_pyenv
}

install_rdp() {
	sudo apt install -y \
		xrdp --no-install-recommends
		
	sudo systemctl enable xrdp
	sudo systemctl start xrdp
}

install_pyenv() {
	echo "[*] Download the pyenv script and run it"
	sudo curl https://pyenv.run | zsh
	source /home/$TARGET_USER/.bashrc
	echo "[*] PyEnv is installed"
	echo "[*] Go here for some simple usage instructions:"
	echo "[~] https://github.com/pyenv/pyenv"

	# install python 3.9.4 by default (echidna has issues with 3.10)
	if [[ -n "$1" ]]; then
		$1='3.9.4'
	fi 
	
	echo "[*] Install python $1"
	pyenv install -v $1
	
	# Install Python Modules
	echo "[*] Install python modules"
	/home/"$USER"/.pyenv/bin/pyenv global 3.9.4
	/home/"$USER"/.pyenv/versions/3.9.4/bin/pip install pipx --user
	/home/"$USER"/.local/bin/pipx install eth-brownie
	/home/"$USER"/.pyenv/versions/3.9.4/bin/pip install web3
}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a debian laptop\\n"
	echo "Usage:"
	echo "  base                                      - setup sources & install base pkgs"
	echo "  graphics {amd, intel, geforce, optimus,}  - install graphics drivers"
	echo "  wm                                        - install window manager/desktop pkgs"
	echo "  dotfiles                                  - get dotfiles"
	echo "  vim                                       - install vim specific dotfiles"
	echo "  pyenv                                     - install pyenv"
	echo "  tmux                                      - install tmux"
	echo "  scripts                                   - install scripts"
}

main() {
	local cmd=$1

	case $cmd in 
		"base")
			check_is_sudo
			get_user
			base
			;;
		
		"graphics")
			check_is_sudo
			if [[ -z "$2" ]]; then
				echo "Please specify which graphics to install."
				exit 1
			fi
			
			install_graphics "$2"
			;;

		"desktop")
			check_is_sudo
			install_desktop
			;;

		"dotfiles")
			get_user
			install_dotfiles
			;;
			
		"vim")
			install_vim
			;;
		
		"scripts")
			install_scripts
			;;
		
		"rdp")
			check_is_sudo
			install_rdp
			;;
			
		"pyenv")
			check_is_sudo
			install_pyenv
			;;	
		
		"web3")
			check_is_sudo
			web3
			;;
		
		"tmux")
			check_is_sudo
			install_tmux
			;;
		
		"chrome")
			check_is_sudo
			install_chrome
			;;
		*)
			usage
			exit 1
			;;
		esac
		
}

main "$@"