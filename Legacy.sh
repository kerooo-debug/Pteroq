#!/bin/bash

#############################################################################
#                                                                           #
# Project 'pterodactyl-installer' for panel                                 #
#                                                                           #
# Copyright (C) 2018 - 2020, Vilhelm Prytz, <vilhelm@prytznet.se>, et al.   #
#                                                                           #
# This script is licensed under the terms of the GNU GPL v3.0 license       #
# https://github.com/vilhelmprytz/pterodactyl-installer/blob/master/LICENSE #
#                                                                           #
# This script is not associated with the official Pterodactyl Project.      #
# https://github.com/vilhelmprytz/pterodactyl-installer                     #
#                                                                           #
#############################################################################

# exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* Este script deve ser executado com privilégios de root (sudo)." 1>&2
  exit 1
fi

# check for curl
CURLPATH="$(command -v curl)"
if [ -z "$CURLPATH" ]; then
  echo "* O comando 'curl' é necessário para que este script funcione."
  echo "* instalar usando apt no Debian / Ubuntu ou yum no CentOS"
  exit 1
fi

# define version using information from GitHub
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
  grep '"tag_name":' |                                              # Get tag line
  sed -E 's/.*"([^"]+)".*/\1/'                                      # Pluck JSON value
}

echo "* Recuperando informações de lançamento .."
PTERODACTYL_VERSION="$(get_latest_release "pterodactyl/panel")"
echo "* A última versão é $PTERODACTYL_VERSION"

# variables
WEBSERVER="nginx"
FQDN=""

# default MySQL credentials
MYSQL_DB="pterodactyl"
MYSQL_USER="pterodactyl"
MYSQL_PASSWORD=""

# assume SSL, will fetch different config if true
ASSUME_SSL=false
CONFIGURE_LETSENCRYPT=false

# download URLs
PANEL_DL_URL="https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
CONFIGS_URL="https://raw.githubusercontent.com/vilhelmprytz/pterodactyl-installer/master/configs"

# apt sources path
SOURCES_PATH="/etc/apt/sources.list"

# ufw firewall
CONFIGURE_UFW=false

# visual functions
function print_error {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

function print_warning {
  COLOR_YELLOW='\033[1;33m'
  COLOR_NC='\033[0m'
  echo ""
  echo -e "* ${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
  echo ""
}

function print_brake {
  for ((n=0;n<$1;n++));
    do
      echo -n "#"
    done
    echo ""
}

# other functions
function detect_distro {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS="SuSE"
    OS_VER="?"
  elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS="Red Hat/CentOS"
    OS_VER="?"
  else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

function check_os_comp {
  if [ "$OS" == "ubuntu" ]; then
    if [ "$OS_VER_MAJOR" == "16" ]; then
      SUPPORTED=true
      PHP_SOCKET="/run/php/php7.2-fpm.sock"
    elif [ "$OS_VER_MAJOR" == "18" ]; then
      SUPPORTED=true
      PHP_SOCKET="/run/php/php7.2-fpm.sock"
    elif [ "$OS_VER_MAJOR" == "20" ]; then
      SUPPORTED=true
      PHP_SOCKET="/run/php/php7.4-fpm.sock"
    else
      SUPPORTED=false
    fi
  elif [ "$OS" == "zorin" ]; then
    if [ "$OS_VER_MAJOR" == "15" ]; then
      SUPPORTED=true
      PHP_SOCKET="/run/php/php7.2-fpm.sock"
    else
      SUPPORTED=false
    fi
  elif [ "$OS" == "debian" ]; then
    if [ "$OS_VER_MAJOR" == "8" ]; then
      SUPPORTED=true
      PHP_SOCKET="/run/php/php7.3-fpm.sock"
    elif [ "$OS_VER_MAJOR" == "9" ]; then
      SUPPORTED=true
      PHP_SOCKET="/run/php/php7.3-fpm.sock"
    elif [ "$OS_VER_MAJOR" == "10" ]; then
      SUPPORTED=true
      PHP_SOCKET="/run/php/php7.3-fpm.sock"
    else
      SUPPORTED=false
    fi
  elif [ "$OS" == "centos" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      SUPPORTED=true
      PHP_SOCKET="/var/run/php-fpm/pterodactyl.sock"
    elif [ "$OS_VER_MAJOR" == "8" ]; then
      SUPPORTED=true
      PHP_SOCKET="/var/run/php-fpm/pterodactyl.sock"
    else
      SUPPORTED=false
    fi
  else
    SUPPORTED=false
  fi

  # exit if not supported
  if [ "$SUPPORTED" == true ]; then
    echo "* $OS $OS_VER é suportado."
  else
    echo "* $OS $OS_VER não é suportado"
    print_error "Unsupported OS"
    exit 1
  fi
}

#################################
## main installation functions ##
#################################

function install_composer {
  echo "* Instalando o composer..."
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  echo "* Composer installed!"
}

function ptdl_dl {
  echo "* Baixando arquivos do painel Pterodactyl... "
  mkdir -p /var/www/pterodactyl
  cd /var/www/pterodactyl || exit

  curl -Lo panel.tar.gz "$PANEL_DL_URL"
  tar --strip-components=1 -xzvf panel.tar.gz
  chmod -R 755 storage/* bootstrap/cache/

  cp .env.example .env
  composer install --no-dev --optimize-autoloader

  php artisan key:generate --force
  echo "* Arquivos de painel de pterodáctilo baixados e dependências do compositor instaladas!"
}

function configure {
  print_brake 88
  echo "* Por favor, siga os passos abaixo. O instalador irá pedir detalhes de configuração."
  print_brake 88
  echo ""
  php artisan p:environment:setup

  print_brake 67
  echo "* O instalador agora solicitará as credenciais do banco de dados MySQL."
  print_brake 67
  echo ""
  php artisan p:environment:database

  print_brake 70
  echo "* O instalador agora solicitará a configuração do e-mail / credenciais do e-mail."
  print_brake 70
  echo ""
  php artisan p:environment:mail

  # configures database
  php artisan migrate --seed --force

  echo "* O instalador agora solicitará que você crie a conta de usuário admin inicial."
  php artisan p:user:make

  # set folder permissions now
  set_folder_permissions
}

# set the correct folder permissions depending on OS and webserver
function set_folder_permissions {
  # if os is ubuntu or debian, we do this
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ] || [ "$OS" == "zorin" ]; then
    chown -R www-data:www-data ./*
  elif [ "$OS" == "centos" ] && [ "$WEBSERVER" == "nginx" ]; then
    chown -R nginx:nginx ./*
  elif [ "$OS" == "centos" ] && [ "$WEBSERVER" == "apache" ]; then
    chown -R apache:apache ./*
  else
    print_error "Servidor da web e configuração de sistema operacional inválidos."
    exit 1
  fi
}

# insert cronjob
function insert_cronjob {
  echo "* Installing cronjob.. "

  crontab -l | { cat; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"; } | crontab -

  echo "* Cronjob installed!"
}

function install_pteroq {
  echo "* Instalando o serviço pteroq..."

  curl -o /etc/systemd/system/pteroq.service $CONFIGS_URL/pteroq.service
  systemctl enable pteroq.service
  systemctl start pteroq

  echo "* Pteroq instalado!"
}

function create_database {
  if [ "$OS" == "centos" ]; then
    # secure MariaDB
    echo "* Instalação segura MariaDB. A seguir estão os padrões de segurança."
    echo "* Definir senha de root? [S/n] S"
    echo "* Remover usuários anônimos? [S/n] S"
    echo "* Desautorizar login de root remotamente? [S/n] S"
    echo "* Remova o banco de dados de teste e acesse-o? [S/n] S"
    echo "* Recarregar tabelas de privilégios agora? [S/n] S"
    echo "*"

    mysql_secure_installation

    echo "* O script deveria ter pedido a você para definir a senha root do MySQL anteriormente (não deve ser confundida com a senha de usuário do banco de dados pterodáctilo)"
    echo "* O MySQL agora pedirá que você digite a senha antes de cada comando."

    echo "* Crie um usuário MySQL."
    mysql -u root -p -e "CREATE USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';"

    echo "* Crie banco de dados."
    mysql -u root -p -e "CREATE DATABASE ${MYSQL_DB};"

    echo "* Conceder privilégios."
    mysql -u root -p -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"

    echo "* Liberar privilégios."
    mysql -u root -p -e "FLUSH PRIVILEGES;"
  else
    echo "* Executando consultas MySQL..."

    echo "* Criando usuário MySQL..."
    mysql -u root -e "CREATE USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';"

    echo "* Criando banco de dados .."
    mysql -u root -e "CREATE DATABASE ${MYSQL_DB};"

    echo "* Concedendo privilégios..."
    mysql -u root -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"

    echo "* Privilégios de descarga..."
    mysql -u root -e "FLUSH PRIVILEGES;"

    echo "* Banco de dados MySQL criado e configurado!"
  fi
}

##################################
# OS specific install functions ##
##################################

function apt_update {
  apt update -y && apt upgrade -y
}

function ubuntu20_dep {
  echo "* Instalando dependências para Ubuntu 20 .."

  # Add "add-apt-repository" command
  apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

  # Update repositories list
  apt update

  # Install Dependencies
  apt -y install php7.4 php7.4-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server redis

  # enable services
  systemctl start mariadb
  systemctl enable mariadb
  systemctl start redis-server
  systemctl enable redis-server

  echo "* Dependências para Ubuntu instaladas!"
}

function ubuntu18_dep {
  echo "* Instalando dependências para Ubuntu 18 .."

  # Add "add-apt-repository" command
  apt -y install software-properties-common

  # Add additional repositories for PHP, Redis, and MariaDB

  # Update repositories list
  apt update

  # Install Dependencies
  apt -y install php7.2 php7.2-cli php7.2-gd php7.2-mysql php7.2-pdo php7.2-mbstring php7.2-tokenizer php7.2-bcmath php7.2-xml php7.2-fpm php7.2-curl php7.2-zip mariadb-server nginx curl tar unzip git redis-server redis

  # enable services
  systemctl start mariadb
  systemctl enable mariadb
  systemctl start redis-server
  systemctl enable redis-server

  echo "* Dependências para Ubuntu instaladas!"
}

function ubuntu16_dep {
  echo "* Instalando dependências para Ubuntu 16 .."

  # Add "add-apt-repository" command
  apt -y install software-properties-common

  # Add additional repositories for PHP, Redis, and MariaDB
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
  add-apt-repository -y ppa:chris-lea/redis-server

  # Update repositories list
  apt update

  # Install Dependencies
  apt -y install php7.2 php7.2-cli php7.2-gd php7.2-mysql php7.2-pdo php7.2-mbstring php7.2-tokenizer php7.2-bcmath php7.2-xml php7.2-fpm php7.2-curl php7.2-zip mariadb-server nginx curl tar unzip git redis-server

  # enable services
  systemctl start mariadb
  systemctl enable mariadb
  systemctl start redis-server
  systemctl enable redis-server

  echo "* Dependências para Ubuntu instaladas!"
}

function debian_jessie_dep {
  echo "* Instalando dependências para Debian 8/9 .."

  # MariaDB need dirmngr
  apt -y install dirmngr

  # install PHP 7.3 using sury's repo instead of PPA
  # this guide shows how: https://vilhelmprytz.se/2018/08/22/install-php72-on-Debian-8-and-9.html
  apt install ca-certificates apt-transport-https lsb-release -y
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

  # redis-server is not installed using the PPA, as it's already available in the Debian repo

  # Update repositories list
  apt update

  # Install Dependencies
  apt -y install php7.3 php7.3-cli php7.3-gd php7.3-mysql php7.3-pdo php7.3-mbstring php7.3-tokenizer php7.3-bcmath php7.3-xml php7.3-fpm php7.3-curl php7.3-zip mariadb-server nginx curl tar unzip git redis-server

  # enable services
  systemctl start mariadb
  systemctl enable mariadb
  systemctl start redis-server
  systemctl enable redis-server

  echo "* Dependências para Debian 8/9 instaladas!"
}

function debian_dep {
  echo "* Instalando dependências para Debian 10 .."

  # MariaDB need dirmngr
  apt -y install dirmngr

  # Update repositories list
  apt update

  # install dependencies
  apt -y install php7.3 php7.3-cli php7.3-common php7.3-gd php7.3-mysql php7.3-mbstring php7.3-bcmath php7.3-xml php7.3-fpm php7.3-curl php7.3-zip mariadb-server nginx curl tar unzip git redis-server

  # enable services
  systemctl start mariadb
  systemctl enable mariadb
  systemctl start redis-server
  systemctl enable redis-server

  echo "* Dependências para Debian 10 instaladas!"
}

function centos7_dep {
  echo "* Instalando dependências para CentOS 7 .."

  # update first
  yum update -y

  # SELinux tools
  yum install -y policycoreutils policycoreutils-python selinux-policy selinux-policy-targeted libselinux-utils setroubleshoot-server setools setools-console mcstrans

  # install php7.3
  yum install -y epel-release http://rpms.remirepo.net/enterprise/remi-release-7.rpm
  yum install -y yum-utils
  yum-config-manager --disable remi-php54
  yum-config-manager --enable remi-php73
  yum update -y

  # Install MariaDB
  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

  # install dependencies
  yum -y install php php-common php-fpm php-cli php-json php-mysqlnd php-mcrypt php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache mariadb-server nginx curl tar zip unzip git redis

  # enable services
  systemctl enable mariadb
  systemctl enable redis
  systemctl start mariadb
  systemctl start redis

  # SELinux (allow nginx and redis)
  setsebool -P httpd_can_network_connect 1
  setsebool -P httpd_execmem 1
  setsebool -P httpd_unified 1

  echo "* Dependências para CentOS instaladas!"
}

function centos8_dep {
  echo "* Instalando dependências para CentOS 8 .."

  # update first
  dnf update -y

  # SELinux tools
  dnf install -y policycoreutils selinux-policy selinux-policy-targeted setroubleshoot-server setools setools-console mcstrans

  # Install php 7.2
  dnf install -y php php-common php-fpm php-cli php-json php-mysqlnd php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache

  # MariaDB (use from official repo)
  dnf install -y mariadb mariadb-server

  # Other dependencies
  dnf install -y nginx curl tar zip unzip git redis

  # enable services
  systemctl enable mariadb
  systemctl enable redis
  systemctl start mariadb
  systemctl start redis

  # SELinux (allow nginx and redis)
  setsebool -P httpd_can_network_connect 1
  setsebool -P httpd_execmem 1
  setsebool -P httpd_unified 1

  echo "* Dependências para CentOS instaladas!"
}

#################################
## OTHER OS SPECIFIC FUNCTIONS ##
#################################

function ubuntu_universedep {
  # Probably should change this, this is more of a bandaid fix for this
  # This function is ran before software-properties-common is installed
  apt update -y
  apt install software-properties-common -y

  if grep -q universe "$SOURCES_PATH"; then
    # even if it detects it as already existent, we'll still run the apt command to make sure
    add-apt-repository universe
    echo "* O repositório Ubuntu universe já existe."
  else
    add-apt-repository universe
  fi
}

function centos_php {
  curl -o /etc/php-fpm.d/www-pterodactyl.conf $CONFIGS_URL/www-pterodactyl.conf

  systemctl enable php-fpm
  systemctl start php-fpm
}

function firewall_ufw {
  apt update
  apt install ufw -y

  echo -e "\n* Habilitando Firewall Descomplicado (UFW)"
  echo "* Abrindo a Porta 22 (SSH), 80 (HTTP) e 443 (HTTPS)"

  # pointing to /dev/null silences the command output
  ufw allow ssh > /dev/null
  ufw allow http > /dev/null
  ufw allow https > /dev/null

  ufw enable
  ufw status numbered | sed '/v6/d'
}

function debian_based_letsencrypt {
  # Install certbot and setup the certificate using the FQDN
  apt install certbot -y

  systemctl stop nginx

  echo -e "\nCertifique-se de escolher a Opção 1 e criar um Servidor Web Independente durante o certificado"
  certbot certonly -d "$FQDN"

  systemctl restart nginx
}

#######################################
## WEBSERVER CONFIGURATION FUNCTIONS ##
#######################################

function configure_nginx {
  echo "* Configurando o nginx.."

  if [ "$ASSUME_SSL" == true ]; then
    DL_FILE="nginx_ssl.conf"
  else
    DL_FILE="nginx.conf"
  fi

  if [ "$OS" == "centos" ]; then
      # remove default config
      rm -rf /etc/nginx/conf.d/default

      # download new config
      curl -o /etc/nginx/conf.d/pterodactyl.conf $CONFIGS_URL/$DL_FILE

      # replace all <domain> places with the correct domain
      sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/conf.d/pterodactyl.conf

      # replace all <php_socket> places with correct socket "path"
      sed -i -e "s@<php_socket>@${PHP_SOCKET}@g" /etc/nginx/conf.d/pterodactyl.conf
  else
      # remove default config
      rm -rf /etc/nginx/sites-enabled/default

      # download new config
      curl -o /etc/nginx/sites-available/pterodactyl.conf $CONFIGS_URL/$DL_FILE

      # replace all <domain> places with the correct domain
      sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-available/pterodactyl.conf

      # replace all <php_socket> places with correct socket "path"
      sed -i -e "s@<php_socket>@${PHP_SOCKET}@g" /etc/nginx/sites-available/pterodactyl.conf

      # on debian 8/9, TLS v1.3 is not supported (see #76)
      # this if statement can be refactored into a one-liner but I think this is more readable
      if [ "$OS" == "debian" ]; then
        if [ "$OS_VER_MAJOR" == "8" ] || [ "$OS_VER_MAJOR" == "9" ]; then
          sed -i 's/ TLSv1.3//' file /etc/nginx/sites-available/pterodactyl.conf
        fi
      fi

      # enable pterodactyl
      ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
  fi

  # restart nginx
  systemctl restart nginx
  echo "* nginx configurado!"
}

function configure_apache {
  echo "em breve .."
}

####################
## MAIN FUNCTIONS ##
####################

function perform_install {
  echo "* Iniciando a instalação .. isso pode demorar um pouco!"

  [ "$CONFIGURE_UFW" == true ] && firewall_ufw

  # do different things depending on OS
  if [ "$OS" == "ubuntu" ]; then
    ubuntu_universedep
    apt_update
    # different dependencies depending on if it's 18 or 16
    if [ "$OS_VER_MAJOR" == "20" ]; then
      ubuntu20_dep
    elif [ "$OS_VER_MAJOR" == "18" ]; then
      ubuntu18_dep
    elif [ "$OS_VER_MAJOR" == "16" ]; then
      ubuntu16_dep
    else
      print_error "Unsupported version of Ubuntu."
      exit 1
    fi
    install_composer
    ptdl_dl
    create_database
    configure
    insert_cronjob
    install_pteroq

    if [ "$OS_VER_MAJOR" == "18" ] || [ "$OS_VER_MAJOR" == "20" ]; then
      if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
        debian_based_letsencrypt
      fi
    fi
  elif [ "$OS" == "zorin" ]; then
    ubuntu_universedep
    apt_update
    if [ "$OS_VER_MAJOR" == "15" ]; then
      ubuntu18_dep
    else
      print_error "Unsupported version of Zorin."
      exit 1
    fi
    install_composer
    ptdl_dl
    create_database
    configure
    insert_cronjob
    install_pteroq
  elif [ "$OS" == "debian" ]; then
    apt_update
    if [ "$OS_VER_MAJOR" == "8" ] || [ "$OS_VER_MAJOR" == "9" ]; then
      debian_jessie_dep
    elif [ "$OS_VER_MAJOR" == "10" ]; then
      debian_dep
    fi
    install_composer
    ptdl_dl
    create_database
    configure
    insert_cronjob
    install_pteroq

    if [ "$OS_VER_MAJOR" == "9" ] || [ "$OS_VER_MAJOR" == "10" ]; then
      if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
        debian_based_letsencrypt
      fi
    fi
  elif [ "$OS" == "centos" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      centos7_dep
    elif [ "$OS_VER_MAJOR" == "8" ]; then
      centos8_dep
    fi
    centos_php
    install_composer
    ptdl_dl
    create_database
    configure
    insert_cronjob
    install_pteroq
  else
    # exit
    print_error "OS not supported."
    exit 1
  fi

  # perform webserver configuration
  if [ "$WEBSERVER" == "nginx" ]; then
    configure_nginx
  elif [ "$WEBSERVER" == "apache" ]; then
    configure_apache
  else
    print_error "Invalid webserver."
    exit 1
  fi
}

function ask_letsencrypt {
  if [ "$CONFIGURE_UFW" == false ]; then
    echo -e "* ${COLOR_RED}Notas${COLOR_NC}: Let's Encrypt requer que a porta 80/443 seja aberta! Você optou por não receber a configuração automática do UFW; use isso por sua própria conta e risco (se a porta 80/443 for fechada, o script falhará)!"
  fi

  print_warning "Você não pode usar o Let's Encrypt com seu nome de host como um endereço IP! Deve ser um FQDN (por exemplo, panel.example.org)."

  echo -e -n "*Você deseja configurar HTTPS automaticamente usando Let's Encrypt? (s/N): "
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Ss] ]]; then
    CONFIGURE_LETSENCRYPT=true
    ASSUME_SSL=true
  fi
}

function main {
  # check if we can detect an already existing installation
  if [ -d "/var/www/pterodactyl" ]; then
    echo -e -n " AVISO: O script detectou que você já tem o painel Pterodactyl em seu sistema! Você não pode executar o script várias vezes, ele falhará!
    echo -e -n "* Tem certeza de que deseja continuar? (S/n): "
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Ss] ]]; then
      print_error "Installation aborted!"
      exit 1
    fi
  fi

  # detect distro
  detect_distro

  print_brake 70
  echo "* Pterodactyl panel installation script"
  echo "*"
  echo "* Copyright (C) 2018 - 2020, Vilhelm Prytz, <vilhelm@prytznet.se>, et al."
  echo "* https://github.com/VilhelmPrytz/pterodactyl-installer"
  echo "*"
  echo "* This script is not associated with the official Pterodactyl Project."
  echo "*"
  echo "* Running $OS version $OS_VER."
  print_brake 70

  # checks if the system is compatible with this installation script
  check_os_comp

  while [ "$WEBSERVER_INPUT" != "1" ]; do
    echo "* [1] - Nginx"
    echo -e "\e[9m* [2] - apache\e[0m - \e[1mApache ainda não suportado\e[0m"

    echo ""

    echo -n "* Selecione o servidor da web para instalar o painel pterodáctilo com: "
    read -r WEBSERVER_INPUT

    if [ "$WEBSERVER_INPUT" == "1" ]; then
      WEBSERVER="nginx"
    else
      # exit
      print_error "Servidor web inválido."
    fi
  done

  # set database credentials
  print_brake 72
  echo "* Configuração do banco de dados."
  echo ""
  echo "* Estas serão as credenciais usadas para comunicação entre o MySQL"
  echo "* Banco de dados e o painel. Você não precisa criar o banco de dados"
  echo "* Antes de executar este script, o script fará isso por você."
  echo ""

  echo -n "* Nome do banco de dados (panel): "
  read -r MYSQL_DB_INPUT

  [ -z "$MYSQL_DB_INPUT" ] && MYSQL_DB="panel" || MYSQL_DB=$MYSQL_DB_INPUT

  echo -n "* Username (pterodactyl): "
  read -r MYSQL_USER_INPUT

  [ -z "$MYSQL_USER_INPUT" ] && MYSQL_USER="pterodactyl" || MYSQL_USER=$MYSQL_USER_INPUT

  # MySQL password input
  while [ -z "$MYSQL_PASSWORD" ]; do
    echo -n "* Senha (use uma senha boa): "

    # modified from https://stackoverflow.com/a/22940001
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && { printf '\n'; break; } # ENTER pressed; output \n and break.
      if [[ $char == $'\x7f' ]]; then # backspace was pressed
          # Only if variable is not empty
          if [ -n "$MYSQL_PASSWORD" ]; then
            # Remove last char from output variable.
            [[ -n $MYSQL_PASSWORD ]] && MYSQL_PASSWORD=${MYSQL_PASSWORD%?}
            # Erase '*' to the left.
            printf '\b \b' 
          fi
      else
        # Add typed char to output variable.
        MYSQL_PASSWORD+=$char
        # Print '*' in its stead.
        printf '*'
      fi
    done

    [ -z "$MYSQL_PASSWORD" ] && print_error "A senha do MySQL não pode estar vazia"
  done

  print_brake 72

  # set FQDN
  while [ -z "$FQDN" ]; do
      echo -n "* Defina o FQDN deste painel (panel.example.com): "
      read -r FQDN

      [ -z "$FQDN" ] && print_error "FQDN não pode estar vazio"
  done

  # UFW is available for Ubuntu/Debian
  # Let's Encrypt, in this setup, is only available on Ubuntu/Debian
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ] || [ "$OS" == "zorin" ]; then
    echo -e -n "* Do you want to automatically configure UFW (firewall)? (S/n): "
    read -r CONFIRM_UFW

    if [[ "$CONFIRM_UFW" =~ [Ss] ]]; then
      CONFIGURE_UFW=true
    fi

    # Available for Debian 9/10
    if [ "$OS" == "debian" ]; then
      if [ "$OS_VER_MAJOR" == "9" ] || [ "$OS_VER_MAJOR" == "10" ]; then
        ask_letsencrypt
      fi
    fi

    # Available for Ubuntu 18/20
    if [ "$OS" == "ubuntu" ]; then
      if [ "$OS_VER_MAJOR" == "18" ] || [ "$OS_VER_MAJOR" == "20" ]; then
        ask_letsencrypt
      fi
    fi
  fi

  # If it's already true, this should be a no-brainer
  if [ "$CONFIGURE_LETSENCRYPT" == false ]; then
    echo "* O Let's Encrypt não será configurado automaticamente por este script (ainda sem suporte ou o usuário optou por sair)."
    echo "* Você pode 'presumir' Let's Encrypt, o que significa que o script baixará uma configuração nginx configurada para usar um certificado Let's Encrypt, mas o script não obterá o certificado para você."
    echo "* Se você assumir SSL e não obter o certificado, a instalação não funcionará."

    echo -n "* Assumir SSL ou não? (S/n): "
    read -r ASSUME_SSL_INPUT

    if [[ "$ASSUME_SSL_INPUT" =~ [Ss] ]]; then
      ASSUME_SSL=true
    fi
  fi

  # summary
  summary

  # confirm installation
  echo -e -n "\n* Configuração inicial concluída. Continuar com a instalação? (S/n): "
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Ss] ]]; then
    perform_install
  else
    # run welcome script again
    print_error "Instalação abortada."
    exit 1
  fi
}

function summary {
  print_brake 62
  echo "* Painel de pterodáctilo $PTERODACTYL_VERSION com $WEBSERVER como servidor web em $OS"
  echo "* Nome do banco de dados: $MYSQL_DB"
  echo "* Usuário do banco de dados: $MYSQL_USER"
  echo "* Senha do banco de dados: (censored)"
  echo "* Hostname/FQDN: $FQDN"
  echo "* Configurar UFW? $CONFIGURE_UFW"
  echo "* Configurar Let's Encrypt? $CONFIGURE_LETSENCRYPT"
  echo "* Usar SSL? $ASSUME_SSL"
  print_brake 62
}

function goodbye {
  print_brake 62
  echo "* Painel de pterodáctilo instalado com sucesso @ $FQDN"
  echo "* "
  echo "* A instalação está usando $WEBSERVER no $OS"
  echo "* Obrigado por usar este script."
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: Se você não configurou o firewall: 80/443 (HTTP / HTTPS) é necessário para ser aberto!"
  print_brake 62
}

# run script
main
goodbye
