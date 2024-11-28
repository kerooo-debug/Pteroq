#!/bin/bash
output(){
    echo -e '\e[37m'$1'\e[0m';
}

warn(){
    echo -e '\e[31m'$1'\e[0m';
}

PANEL=v1.11.2
WINGS=v1.11.0
PANEL_LEGACY=v0.7.19
DAEMON_LEGACY=v0.6.13
PHPMYADMIN=5.2.0

preflight(){
    output "Script de Instalação e Atualização do Pterodactyl."
	warn "https://github.com/ItsDDev"
    warn ""
    warn "Informações do Script"
	warn ""
	warn "Versão: " && output " 1.0"
	warn "Autor: " && output "ItsD#0001"
	warn ""
    warn ""
    warn ""
    output "Observe que este script deve ser instalado em um novo sistema operacional. Instalá-lo em um sistema operacional não novo pode causar problemas."
    output "Detecção automática do sistema operacional inicializada..."

    os_check

    if [ "$EUID" -ne 0 ]; then
        output "Por favor, execute como root."
        exit 3
    fi

    output "Detecção automática de arquitetura inicializada ..."
    MACHINE_TYPE=`uname -m`
    if [ ${MACHINE_TYPE} == 'x86_64' ]; then
        output "Servidor de 64 bits detectado! Bom para ir."
        output ""
    else
        output "Arquitetura não suportada detectada! Mude para 64 bits (x86_64)."
        exit 4
    fi

    output "Detecção automática de virtualização inicializada..."
    if [ "$lsb_dist" =  "ubuntu" ]; then
        apt-get update --fix-missing
        apt-get -y install software-properties-common
        add-apt-repository -y universe
        apt-get -y install virt-what curl
    elif [ "$lsb_dist" =  "debian" ]; then
        apt update --fix-missing
        apt-get -y install software-properties-common virt-what wget curl dnsutils
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install virt-what wget bind-utils
    fi
    virt_serv=$(echo $(virt-what))
    if [ "$virt_serv" = "" ]; then
        output "Virtualização: Detectado Bare Metal."
    elif [ "$virt_serv" = "openvz lxc" ]; then
        output "Virtualização: OpenVZ 7 detectado."
    elif [ "$virt_serv" = "xen xen-hvm" ]; then
        output "Virtualização: Xen-HVM detectado."
    elif [ "$virt_serv" = "xen xen-hvm aws" ]; then
        output "Virtualização: Xen-HVM detectado no AWS."
        warn "Ao criar alocações para este node, use o IP interno, pois o Google Cloud usa o roteamento NAT."
        warn "Retomando em 10 segundos ..."
        sleep 10
    else
        output "Virtualização: $virt_serv detectada."
    fi
    output ""
    if [ "$virt_serv" != "" ] && [ "$virt_serv" != "kvm" ] && [ "$virt_serv" != "vmware" ] && [ "$virt_serv" != "hyperv" ] && [ "$virt_serv" != "openvz lxc" ] && [ "$virt_serv" != "xen xen-hvm" ] && [ "$virt_serv" != "xen xen-hvm aws" ]; then
        warn "Tipo não compatível de virtualização detectado. Consulte seu provedor de hospedagem se o seu servidor pode executar Docker ou não. Prossiga por sua conta e risco."
        warn "Nenhum suporte será fornecido se o seu servidor quebrar a qualquer momento no futuro."
        warn "Continuar?\n[1] Sim.\n [2] Não."
        read choice
        case $choice in 
            1)  output "Prosseguindo ..."
                ;;
            2)  output "Cancelando instalação ..."
                exit 5
                ;;
        esac
        output ""
    fi

    output "Detecção de kernel inicializada ..."
    if echo $(uname -r) | grep -q xxxx; then
        output "Kernel OVH detectado. Este script não funcionará. Reinstale seu servidor usando um kernel genérico / de distribuição."
        output "Quando você estiver reinstalando seu servidor, clique em 'instalação personalizada' e clique em 'usar distribuição' kernel depois disso."
        output "Você também pode querer fazer um particionamento personalizado, remover a partição /home/ e dar / todo o espaço restante."
        output "Não hesite em nos contatar se precisar de ajuda com relação a este problema."
        exit 6
    elif echo $(uname -r) | grep -q pve; then
        output "Kernel Proxmox LXE detectado. Você optou por continuar na última etapa, portanto, prosseguiremos por sua própria conta e risco."
        output "Prosseguindo com uma operação arriscada..."
    elif echo $(uname -r) | grep -q stab; then
        if echo $(uname -r) | grep -q 2.6; then 
            output "OpenVZ 6 detectado. Este servidor definitivamente não funcionará com o Docker, independentemente do que seu provedor possa dizer. Saindo para evitar maiores danos."
            exit 6
        fi
    elif echo $(uname -r) | grep -q gcp; then
        output "Google Cloud detectado."
        warn "Certifique-se de ter uma configuração de IP estático, caso contrário, o sistema não funcionará após a reinicialização."
        warn "Verifique também se o firewall do GCP permite que as portas necessárias para o servidor funcione normalmente."
        warn "Ao criar alocações para este node, use o IP interno, pois o Google Cloud usa o roteamento NAT."
        warn "Retomando em 10 segundos ..."
        sleep 10
    else
        output "Não detectou nenhum kernel ruim. Seguindo em frente ..."
        output ""
    fi
}

os_check(){
    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
        dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        if [ $lsb_dist = "rhel" ]; then
            dist_version="$(echo $dist_version | awk -F. '{print $1}')"
        fi
    else
        exit 1
    fi
    
    if [ "$lsb_dist" =  "ubuntu" ]; then
        if  [ "$dist_version" != "20.04" ] && [ "$dist_version" != "18.04" ]; then
            output "Versão não suportada do Ubuntu. Apenas Ubuntu 20.04 e 18.04 são suportados."
            exit 2
        fi
    elif [ "$lsb_dist" = "debian" ]; then
        if [ "$dist_version" != "10" ]; then
            output "Versão Debian não suportada. Apenas Debian 10 é suportado."
            exit 2
        fi
    elif [ "$lsb_dist" = "fedora" ]; then
        if [ "$dist_version" != "33" ] && [ "$dist_version" != "32" ]; then
            output "Versão não suportada do Fedora. Apenas Fedora 33 e 32 são suportados."
            exit 2
        fi
    elif [ "$lsb_dist" = "centos" ]; then
        if [ "$dist_version" != "8" ]; then
            output "Versão CentOS não suportada. Apenas CentOS Stream e 8 são suportados."
            exit 2
        fi
    elif [ "$lsb_dist" = "rhel" ]; then
        if  [ $dist_version != "8" ]; then
            output "Versão RHEL não suportada. Apenas RHEL 8 é compatível."
            exit 2
        fi
    elif [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "debian" ] && [ "$lsb_dist" != "centos" ]; then
        output "Sistema operacional não compatível."
        output ""
        output "Sistemas compatível:"
        output "Ubuntu: 20.04, 18.04"
        output "Debian: 10"
        output "Fedora: 33, 32"
        output "CentOS: 8, 7"
        output "RHEL: 8"
        exit 2
    fi
}

install_options(){
    output "Selecione sua opção de instalação:"
    output "[1] Instalar o Painel ${PANEL}."
    output "[2] Instalar o Painel ${PANEL_LEGACY}."
    output "[3] Instalar o Wings ${WINGS}."
    output "[4] Instalar o Daemon ${DAEMON_LEGACY}."
    output "[5] Instalar o Painel ${PANEL} e o Wings ${WINGS}."
    output "[6] Instalar o Painel ${PANEL_LEGACY} e o Daemon ${DAEMON_LEGACY}."
    output "[7] Instale o servidor SFTP autônomo."
    output "[8] Atualizar o Painel (1.x) para a versão ${PANEL}."
    output "[9] Atualizar o Painel (0.7.x) para a versão ${PANEL}."
    output "[10] Atualizar o Painel (0.7.x) para a versão ${PANEL_LEGACY}."
    output "[11] Atualizar o Daemon (0.6.x) para a versão ${DAEMON_LEGACY}."
    output "[12] Migrando o Deamon para o Wings."
    output "[13] Atualize o painel para ${PANEL} e migrar para Wings ${WINGS}"
    output "[14] Uatualize o painel para ${PANEL_LEGACY} e o Daemon para ${DAEMON_LEGACY}"
    output "[15] Atualize o servidor SFTP autônomo para (1.0.5)."
    output "[16] Torne o Pterodactyl compatível com o aplicativo móvel (use-o apenas depois de instalar o painel - verifique https://pterodactyl.cloud para mais informações)."
    output "[17] Atualize a compatibilidade móvel."
    output "[18] Instale ou atualize para phpMyAdmin (${PHPMYADMIN}) (Só use isso depois de instalar o painel)."
    output "[19] Instale um host de banco de dados independente (apenas para uso em instalações apenas daemon)."
    output "[20] Alterar o tema do Painel (${PANEL_LEGACY} Apenas)."
    output "[21] Redefinição de senha raiz de emergência MariaDB."
    output "[22] Redefinição das informações do host do banco de dados de emergência."
    output "[23] Alterar o URL do Painel. ( Lembrando, você deve reconfigurar o node. )"
    output " "
    output " "
    output " "
    output "[0] Ultimas Atualizações"

    read choice
    case $choice in
        1 ) installoption=1
            output "Você selecionou apenas a instalação de painel ${PANEL}."
            ;;
        2 ) installoption=2
            output "Você selecionou a instalação do painel ${PANEL_LEGACY} apenas."
            ;;
        3 ) installoption=3
            output "Você selecionou apenas a instalação do Wings ${WINGS}."
            ;;
        4 ) installoption=4
            output "Você selecionou apenas a instalação do daemon ${DAEMON_LEGACY}."
            ;;
        5 ) installoption=5
            output "Você selecionou ${PANEL} painel e wings ${WINGS} instalação."
            ;;
        6 ) installoption=6
            output "Você selecionou o painel ${PANEL_LEGACY} e a instalação do daemon."
            ;;
        7 ) installoption=7
            output "Você optou por instalar o servidor SFTP autônomo."
            ;;
        8 ) installoption=8
            output "Você optou por atualizar o painel para ${PANEL}."
            ;;
        9 ) installoption=9
            output "Você optou por atualizar o painel para ${PANEL}."
            ;;
        10 ) installoption=10
            output "Você optou por atualizar o painel para ${PANEL_LEGACY}."
            ;;
        11 ) installoption=11
            output "Você optou por atualizar o daemon para ${DAEMON_LEGACY}."
            ;;
        12 ) installoption=12
            output "Você optou por migrar o daemon ${DAEMON_LEGACY} para o wings ${WINGS}."
            ;;
        13 ) installoption=13
            output "Você optou por atualizar o painel para ${PANEL} e migrar para as asas ${WINGS}."
            ;;
        14 ) installoption=14
            output "Você optou por atualizar o painel para ${PANEL} e o daemon para ${DAEMON_LEGACY}."
            ;;
        15 ) installoption=15
            output "Você optou por atualizar o SFTP autônomo."
            ;;
        16 ) installoption=16
            output "Você ativou a compatibilidade do aplicativo móvel."
            ;;
        17 ) installoption=17
            output "Você ativou a compatibilidade do aplicativo móvel"
            ;;
        18 ) installoption=18
            output "Você optou por instalar ou atualizar phpMyAdmin ${PHPMYADMIN}."
            ;;
        19 ) installoption=19
            output "Você optou por instalar um host de banco de dados."
            ;;
        20 ) installoption=20
            output "Você optou por alterar apenas o tema do Pterodactyl ${PANEL_LEGACY}."
            ;;
        21 ) installoption=21
            output "Você selecionou redefinição de senha de root do MariaDB."
            ;;
        22 ) installoption=22
            output "Você selecionou redefinir as informações do Host do banco de dados."
            ;;
	23 ) installoption=23
            output "Você Solicitou a troca do URL do painel!"
            ;;
        0 ) installoption=0
            output "Você optou por ver as logs!"
            ;;
        * ) output "Você não inseriu uma seleção válida."
            install_options
    esac
}

logs(){
	warn "[05/02/2021]" 
	warn "Tradução do Script"
	warn "Adicionado Forma de ligar o node apos instalar o Wings ${WINGS}."
	warn " "
	warn "[07/02/2021]" 
	warn "Adicionado troca de URL"
	warn "Adicionado função de Logs"
	warn " "
	warn "[08/02/2021]" 
	warn "Removido BUG do Pterodactyl ${PANEL_LEGACY}"
	warn "Adicionado sistema pare lhe redirecionar ao terminar uma Opção do Script."
	
}
webserver_options() {
    output "Selecione qual servidor web você gostaria de usar: \n[1] Nginx (recomendado). \n[2] Apache2/httpd."
    read choice
    case $choice in
        1 ) webserver=1
            output "Você selecionou Nginx."
            output ""
            ;;
        2 ) webserver=2
            output "Você selecionou Apache2 / httpd."
            output ""
            ;;
        * ) output "Você não inseriu uma seleção válida."
            webserver_options
    esac
}

theme_options() {
    output "Gostaria de instalar um dos temas do Fonix?"
    warn "ATÉ AGORA, A FONIX NÃO ATUALIZOU SEU TEMA PARA 0.7.19 PARA CORRIGIR A EXPLORAÇÃO XSS EM PTERODACTYL <= 0.7.18 AINDA. NÃO USE ESTES NA PRODUÇÃO. RECOMENDO ALTAMENTE QUE SELECIONE [1]."
    output "[1] Não."
    output "[2] Super rosa e fofo."
    output "[3] Tango Twist."
    output "[4] Tijolo Azul."
    output "[5] Minecraft Madness."
    output "[6] Lime Stitch."
    output "[7] Macaco Vermelho."
    output "[8] Espaço BlackEned."
    output "[9] Nada além de grafite."
    output ""
    output "Você pode descobrir mais sobre os temas da Fonix aqui: https://github.com/TheFonix/Pterodactyl-Themes"
    read choice
    case $choice in
        1 ) themeoption=1
            output "Você optou por instalar o tema vanilla Pterodactyl."
            output ""
            ;;
        2 ) themeoption=2
            output "Você optou por instalar o tema Super rosa e fofo da Fonix."
            output ""
            ;;
        3 ) themeoption=3
            output "Você optou por instalar o tema Tango Twist da Fonix."
            output ""
            ;;
        4 ) themeoption=4
            output "Você optou por instalar o tema Tijolo Azul da Fonix."
            output ""
            ;;
        5 ) themeoption=5
            output "Você optou por instalar o tema Minecraft Madness da Fonix."
            output ""
            ;;
        6 ) themeoption=6
            output "Você optou por instalar o tema Lime Stitch da Fonix."
            output ""
            ;;
        7 ) themeoption=7
            output "Você optou por instalar o tema Macaco Vermelho da Fonix."
            output ""
            ;;
        8 ) themeoption=8
            output "Você optou por instalar o tema Espaço Preto da Fonix."
            output ""
            ;;
        9 ) themeoption=9
            output "Você optou por instalar o tema Nothing But Graphite da Fonix."
            output ""
            ;;
        * ) output "Você não inseriu uma seleção válida."
            theme_options
    esac
}

required_infos() {
    output "Insira um email para o login no Painel"
    read email
    dns_check
}

dns_check(){
    output "Insira seu FQDN (panel.domain.tld):"
    read FQDN

    output "Resolvendo DNS ..."
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    DOMAIN_RECORD=$(dig +short ${FQDN})
    if [ "${SERVER_IP}" != "${DOMAIN_RECORD}" ]; then
        output ""
        output "O domínio inserido não resolve para o IP público primário deste servidor."
        output "Faça um registro A apontando para o IP do seu servidor. Por exemplo, se você fizer um registro A chamado 'painel' apontando para o IP do seu servidor, seu FQDN é panel.domain.tld"
        output "Se você estiver usando Cloudflare, desative a nuvem laranja."
        output "Se você não tiver um domínio, pode obter um gratuitamente em https://freenom.com"
        dns_check
    else
        output "Domínio resolvido corretamente. Bom para ir..."
    fi
}

theme() {
    output "A instalação do tema foi inicializada ..."
    cd /var/www/pterodactyl
    if [ "$themeoption" = "1" ]; then
        output "Mantendo o tema baunilha do Pterodáctilo."
    elif [ "$themeoption" = "2" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/PinkAnFluffy/build.sh | sh
    elif [ "$themeoption" = "3" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/TangoTwist/build.sh | sh
    elif [ "$themeoption" = "4" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/BlueBrick/build.sh | sh
    elif [ "$themeoption" = "5" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/MinecraftMadness/build.sh | sh
    elif [ "$themeoption" = "6" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/LimeStitch/build.sh | sh
    elif [ "$themeoption" = "7" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/RedApe/build.sh | sh
    elif [ "$themeoption" = "8" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/BlackEndSpace/build.sh | sh
    elif [ "$themeoption" = "9" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/NothingButGraphite/build.sh | sh
    fi
    php artisan view:clear
    php artisan cache:clear
}

repositories_setup(){
    output "Configurando seus repositórios ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install sudo
        apt-get -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        dpkg --remove-architecture i386
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
        apt-get -y update
	      curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        if [ "$lsb_dist" =  "ubuntu" ]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            add-apt-repository -y ppa:chris-lea/redis-server
            if [ "$dist_version" != "20.04" ]; then
                add-apt-repository -y ppa:certbot/certbot
                add-apt-repository -y ppa:nginx/development
            fi
	        apt -y install tuned dnsutils
                tuned-adm profile latency-performance
        elif [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install ca-certificates apt-transport-https
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
            if [ "$dist_version" = "10" ]; then
                apt -y install dirmngr
                wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
                sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
                apt -y install tuned
                tuned-adm profile latency-performance
        fi
        apt-get -y update
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean
        apt-get -y install curl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ]; then
        if  [ "$lsb_dist" =  "fedora" ] ; then
            if [ "$dist_version" = "33" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-33.rpm
            elif [ "$dist_version" = "32" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-32.rpm
            fi
            dnf -y install dnf-plugins-core python2 libsemanage-devel
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-7.4
	    dnf -y module enable nginx:mainline/common
	    dnf -y module enable mariadb:14/server
        elif  [ "$lsb_dist" =  "centos" ] && [ "$dist_version" = "8" ]; then
            dnf -y install epel-release boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-7.4
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
    fi
            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.5/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            yum -y install epel-release
            yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
            yum -y install policycoreutils-python yum-utils libsemanage-devel
            yum-config-manager --enable remi
            yum-config-manager --enable remi-php74
	        yum-config-manager --enable nginx-mainline
	        yum-config-manager --enable mariadb
        elif  [ "$lsb_dist" =  "rhel" ] && [ "$dist_version" = "8" ]; then
            dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            dnf -y install boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-7.4
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
        fi
        yum -y install yum-utils tuned
        tuned-adm profile latency-performance
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
        yum -y install curl bind-utils cronie
    fi
}

repositories_setup_0.7.19(){
    output "Configurando seus repositórios ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install sudo
        apt-get -y install software-properties-common dnsutils gpg-agent
        dpkg --remove-architecture i386
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
        apt-get -y update
	  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        if [ "$lsb_dist" =  "ubuntu" ]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            add-apt-repository -y ppa:chris-lea/redis-server
            if [ "$dist_version" != "20.04" ]; then
                add-apt-repository -y ppa:certbot/certbot
                add-apt-repository -y ppa:nginx/development
            fi
	        apt -y install tuned dnsutils
                tuned-adm profile latency-performance
        elif [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install ca-certificates apt-transport-https
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
            if [ "$dist_version" = "10" ]; then
                apt -y install dirmngr
                wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
                sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
                apt -y install tuned
                tuned-adm profile latency-performance
        fi
        apt-get -y update
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean
        apt-get -y install curl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ]; then
        if  [ "$lsb_dist" =  "fedora" ] ; then
            if [ "$dist_version" = "33" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-33.rpm
            elif [ "$dist_version" = "32" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-32.rpm
            fi
            dnf -y install dnf-plugins-core python2 libsemanage-devel
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-7.3
	    dnf -y module enable nginx:mainline/common
	    dnf -y module enable mariadb:14/server
        elif  [ "$lsb_dist" =  "centos" ] && [ "$dist_version" = "8" ]; then
            dnf -y install epel-release boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-7.3
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
    fi
            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.5/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            yum -y install epel-release
            yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
            yum -y install policycoreutils-python yum-utils libsemanage-devel
            yum-config-manager --enable remi
            yum-config-manager --enable remi-php73
	        yum-config-manager --enable nginx-mainline
	        yum-config-manager --enable mariadb
        elif  [ "$lsb_dist" =  "rhel" ] && [ "$dist_version" = "8" ]; then
            dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            dnf -y install boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-7.3
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
        fi
        yum -y install yum-utils tuned
        tuned-adm profile latency-performance
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
        yum -y install curl bind-utils cronie
    fi
}

install_dependencies(){
    output "Instalando dependências ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        if [ "$webserver" = "1" ]; then
            apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} nginx tar unzip git redis-server nginx git wget expect
        elif [ "$webserver" = "2" ]; then
             apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} curl tar unzip git redis-server apache2 libapache2-mod-php8.0 redis-server git wget expect
        fi
        sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated mariadb-server"
    else
	if [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$dist_version" = "8" ]; then
	        dnf -y install MariaDB-server MariaDB-client --disablerepo=AppStream
        fi
	else
	    dnf -y install MariaDB-server
	fi
	dnf -y module install php:remi-7.4
        if [ "$webserver" = "1" ]; then
            dnf -y install redis nginx git policycoreutils-python-utils unzip wget expect jq php-mysql php-zip php-bcmath tar
        elif [ "$webserver" = "2" ]; then
            dnf -y install redis httpd git policycoreutils-python-utils mod_ssl unzip wget expect jq php-mysql php-zip php-mcmath tar
        fi
    fi

    output "Enabling Services..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        systemctl enable redis-server
        service redis-server start
        systemctl enable php8.0-fpm
        service php8.0-fpm start
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        systemctl enable redis
        service redis start
        systemctl enable php-fpm
        service php-fpm start
    fi

    systemctl enable cron
    systemctl enable mariadb

    if [ "$webserver" = "1" ]; then
        systemctl enable nginx
        service nginx start
    elif [ "$webserver" = "2" ]; then
        if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            systemctl enable apache2
            service apache2 start
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
            systemctl enable httpd
            service httpd start
        fi
    fi
    service mysql start
}



install_pterodactyl() {
    output "Criando os bancos de dados e definindo a senha root ..."
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="DROP DATABASE IF EXISTS test;"
    Q1="CREATE DATABASE IF NOT EXISTS panel;"
    Q2="SET old_passwords=0;"
    Q3="GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$password';"
    Q4="GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;
"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Vinculando MariaDB / MySQL a 0.0.0.0."
        if grep -Fqs "bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf ; then
		sed -i -- '/bind-address/s/#//g' /etc/mysql/mariadb.conf.d/50-server.cnf
 		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/mysql/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
    	elif grep -Fqs "bind-address" /etc/mysql/my.conf.d/mysqld.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.conf.d/mysqld.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	else
		output 'Não foi possível detectar um arquivo de configuração do MySQL! Entre em contato com o suporte.'
	fi

    output "Baixando o painel"
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    output "Instalando Pterodactyl..."
    if [ "$installoption" = "2" ] || [ "$installoption" = "6" ]; then
    	curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer --version=1.10.16
    else
        curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    fi
    cp .env.example .env
    /usr/local/bin/composer install --no-dev --optimize-autoloader
    php artisan key:generate --force
    php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/Sao_Paulo --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password=$password
    output "Para usar o envio de correio interno do PHP, selecione [mail]. Para usar um servidor SMTP personalizado, selecione [smtp]. A criptografia TLS é recomendada."
    php artisan p:environment:mail
    php artisan migrate --seed --force
    php artisan p:user:make --email=$email --admin=1
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            chown -R nginx:nginx * /var/www/pterodactyl
        elif [ "$webserver" = "2" ]; then
            chown -R apache:apache * /var/www/pterodactyl
        fi
	semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi

    output "Criando ouvintes de fila de painel ..."
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
    service cron restart

    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        cat > /etc/systemd/system/pteroq.service <<- 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            cat > /etc/systemd/system/pteroq.service <<- 'EOF'
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=nginx
Group=nginx
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
        elif [ "$webserver" = "2" ]; then
            cat > /etc/systemd/system/pteroq.service <<- 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=apache
Group=apache
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
        fi
        setsebool -P httpd_can_network_connect 1
	setsebool -P httpd_execmem 1
	setsebool -P httpd_unified 1
    fi
    sudo systemctl daemon-reload
    systemctl enable pteroq.service
    systemctl start pteroq
}


upgrade_pterodactyl(){
    cd /var/www/pterodactyl
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz | tar --strip-components=1 -xzv
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Seu painel foi atualizado com sucesso para a versão ${PANEL}"
    php artisan up
    php artisan queue:restart
}

upgrade_pterodactyl_1.0(){
    cd /var/www/pterodactyl
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz | tar --strip-components=1 -xzv
    rm -rf $(find app public resources -depth | head -n -1 | grep -Fv "$(tar -tf panel.tar.gz)")
    tar -xzvf panel.tar.gz && rm -f panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Seu painel foi atualizado com sucesso para a versão ${PANEL}"
    php artisan up
    php artisan queue:restart
}

upgrade_pterodactyl_0.7.19(){
    cd /var/www/pterodactyl
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL_LEGACY}/panel.tar.gz | tar --strip-components=1 -xzv
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Seu painel foi atualizado com sucesso para a versão ${PANEL_LEGACY}."
    php artisan up
    php artisan queue:restart
}

nginx_config() {
    output "Desativando configuração padrão..."
    rm -rf /etc/nginx/sites-enabled/default
    rm -rf /etc/nginx/sites-enabled/pterodactyl.conf
    output "Configurando o servidor da web Nginx ..."

echo '
server_tokens off;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;
real_ip_header X-Forwarded-For;
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    server_name '"$FQDN"';
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;
    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }
    location ~ /\.ht {
        deny all;
    }
}
' | sudo -E tee /etc/nginx/sites-available/pterodactyl.conf >/dev/null 2>&1
    if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
        sed -i 's/http2//g' /etc/nginx/sites-available/pterodactyl.conf
    fi
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

nginx_config_0.7.19() {
    output "Desativando configuração padrão ..."
    rm -rf /etc/nginx/sites-enabled/default
        rm -rf /etc/nginx/sites-enabled/default
    rm -rf /etc/nginx/sites-enabled/pterodactyl.conf
    output "Configurando o servidor da web Nginx ..."

echo '
server_tokens off;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;
real_ip_header X-Forwarded-For;
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    server_name '"$FQDN"';
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;
    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }
    location ~ /\.ht {
        deny all;
    }
}
' | sudo -E tee /etc/nginx/sites-available/pterodactyl.conf >/dev/null 2>&1
    if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
        sed -i 's/http2//g' /etc/nginx/sites-available/pterodactyl.conf
    fi
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

apache_config() {
    output "Desativando configuração padrão ..."
    rm -rf /etc/nginx/sites-enabled/default
    output "Configurando servidor web Apache2 ..."
echo '
<VirtualHost *:80>
  ServerName '"$FQDN"'
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
<VirtualHost *:443>
  ServerName '"$FQDN"'
  DocumentRoot "/var/www/pterodactyl/public"
  AllowEncodedSlashes On
  php_value upload_max_filesize 100M
  php_value post_max_size 100M
  <Directory "/var/www/pterodactyl/public">
    AllowOverride all
  </Directory>
  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/'"$FQDN"'/privkey.pem
</VirtualHost>
' | sudo -E tee /etc/apache2/sites-available/pterodactyl.conf >/dev/null 2>&1

    ln -s /etc/apache2/sites-available/pterodactyl.conf /etc/apache2/sites-enabled/pterodactyl.conf
    a2enmod ssl
    a2enmod rewrite
    service apache2 restart
}

nginx_config_redhat(){
    output "Configurando servidor da web Nginx ..."

echo '
server_tokens off;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;
real_ip_header X-Forwarded-For;
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    server_name '"$FQDN"';
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;
    # strengthen ssl security
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";

    # See the link below for more SSL information:
    #     https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
    #
    # ssl_dhparam /etc/ssl/certs/dhparam.pem;
    # Add headers to serve security related headers
    add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php-fpm/pterodactyl.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }
    location ~ /\.ht {
        deny all;
    }
}
' | sudo -E tee /etc/nginx/conf.d/pterodactyl.conf >/dev/null 2>&1

    service nginx restart
    chown -R nginx:nginx $(pwd)
    semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
    restorecon -R /var/www/pterodactyl
}

apache_config_redhat() {
    output "Configurando servidor web Apache2 ..."
echo '
<VirtualHost *:80>
  ServerName '"$FQDN"'
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
<VirtualHost *:443>
  ServerName '"$FQDN"'
  DocumentRoot "/var/www/pterodactyl/public"
  AllowEncodedSlashes On
  <Directory "/var/www/pterodactyl/public">
    AllowOverride all
  </Directory>
  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/'"$FQDN"'/privkey.pem
</VirtualHost>
' | sudo -E tee /etc/httpd/conf.d/pterodactyl.conf >/dev/null 2>&1
    service httpd restart
}

php_config(){
    output "Configurando socket PHP ..."
    bash -c 'cat > /etc/php-fpm.d/www-pterodactyl.conf' <<-'EOF'
[pterodactyl]
user = nginx
group = nginx
listen = /var/run/php-fpm/pterodactyl.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0750
pm = ondemand
pm.max_children = 9
pm.process_idle_timeout = 10s
pm.max_requests = 200
EOF
    systemctl restart php-fpm
}

webserver_config(){
    if [ "$lsb_dist" =  "debian" ] || [ "$lsb_dist" =  "ubuntu" ]; then
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "2" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config_0.7.19
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "3" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "4" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config_0.7.19
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "6" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config_0.7.19
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        fi
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            php_config
            nginx_config_redhat
	    chown -R nginx:nginx /var/lib/php/session
        elif [ "$webserver" = "2" ]; then
            apache_config_redhat
        fi
    fi
}

setup_pterodactyl(){
    install_dependencies
    install_pterodactyl
    ssl_certs
    webserver_config
}


setup_pterodactyl_0.7.19(){
    install_dependencies_0.7.19
    install_pterodactyl_0.7.19
    ssl_certs
    webserver_config
    theme
}

install_wings() {
    cd /root
    output "Instalando dependências do Pterodactyl Wings ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install curl tar unzip
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install curl tar unzip
    fi

    output "Instalando Docker"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash

    service docker start
    systemctl enable docker
    output "Habilitando o suporte SWAP para Docker."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
    output "Installing the Pterodactyl wings..."
    mkdir -p /etc/pterodactyl /srv/daemon-data
    cd /etc/pterodactyl
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF

    output "A instalação do Wings está quase concluída, vá para o painel e obtenha o comando 'Auto Deploy' na guia de configuração do node."
    output "Cole seu comando de implantação automática abaixo ( Sem o 'cd /etc/pterodactyl &&' ): "
    read AUTODEPLOY
    ${AUTODEPLOY}

    systemctl enable --now wings
    systemctl restart wings
    output "Wings ${WINGS} agora foi instalado em seu sistema."
}

install_daemon() {
    cd /root
    output "Instalando dependências do Pterodactyl Daemon ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install curl tar unzip
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install curl tar unzip
    fi

    output "Installing Docker"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash

    service docker start
    systemctl enable docker
    output "Habilitando o suporte SWAP para Docker e instalando NodeJS ..."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        update-grub
        curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
            if [ "$lsb_dist" =  "ubuntu" ] && [ "$dist_version" = "20.04" ]; then
                apt -y install nodejs make gcc g++
                npm install node-gyp
            elif [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "10" ]; then
                apt -y install nodejs make gcc g++
            else
                apt -y install nodejs make gcc g++ node-gyp
            fi
        apt-get -y update
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ]; then
        grub2-mkconfig -o "$(readlink /etc/grub2.conf)"
        if [ "$lsb_dist" =  "fedora" ]; then
            dnf -y module install nodejs:12/minimal
	          dnf install -y tar unzip make gcc gcc-c++ python2
	      fi
	  elif [ "$lsb_dist" =  "centos" ] && [ "$dist_version" = "8" ]; then
	      dnf -y module install nodejs:12/minimal
	      dnf install -y tar unzip make gcc gcc-c++ python2
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
    fi
    output "Instalando o daemon Pterodactyl ..."
    mkdir -p /srv/daemon /srv/daemon-data
    cd /srv/daemon
    curl -L https://github.com/pterodactyl/daemon/releases/download/${DAEMON_LEGACY}/daemon.tar.gz | tar --strip-components=1 -xzv
    npm install --only=production --no-audit --unsafe-perm
    bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
[Service]
User=root
#Group=some_group
WorkingDirectory=/srv/daemon
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/bin/node /srv/daemon/src/index.js
Restart=on-failure
StartLimitInterval=600
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wings

    output "A instalação do Daemon está quase concluída, vá para o painel e obtenha o comando 'Auto Deploy' na guia de configuração do node."
    output "Cole seu comando de implantação automática abaixo: "
    read AUTODEPLOY
    ${AUTODEPLOY}
    service wings start
    output "O Daemon ${DAEMON_LEGACY} agora foi instalado em seu sistema."
}

migrate_wings(){
    mkdir -p /etc/pterodactyl
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl stop wings
    rm -rf /srv/daemon
    systemctl disable --now pterosftp
    rm /etc/systemd/system/pterosftp.service
    bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now wings
    output "Your daemon has been migrated to wings."
}

upgrade_daemon(){
    cd /srv/daemon
    service wings stop
    curl -L https://github.com/pterodactyl/daemon/releases/download/${DAEMON_LEGACY}/daemon.tar.gz | tar --strip-components=1 -xzv
    npm install -g npm
    npm install --only=production --no-audit --unsafe-perm
    service wings restart
    output "Seu daemon foi atualizado para a versão ${DAEMON_LEGACY}."
    output "Npm foi atualizado para a versão mais recente."
}

install_standalone_sftp(){
    os_check
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install jq
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ]; then
        yum -y install jq
    fi
    if [ ! -f /srv/daemon/config/core.json ]; then
        warn "VOCÊ DEVE CONFIGURAR SEU DAEMON CORRETAMENTE ANTES DE INSTALAR O SERVIDOR SFTP STANDALONE!"
        exit 11
    fi
    cd /srv/daemon
    if [ $(cat /srv/daemon/config/core.json | jq -r '.sftp.enabled') == "null" ]; then
        output "Atualizando configuração para habilitar o servidor sftp ..."
        cat /srv/daemon/config/core.json | jq '.sftp.enabled |= false' > /tmp/core
        cat /tmp/core > /srv/daemon/config/core.json
        rm -rf /tmp/core
    elif [ $(cat /srv/daemon/config/core.json | jq -r '.sftp.enabled') == "false" ]; then
       output "Configuração já definida para o servidor Golang SFTP."
    else 
       output "Você pode ter definido propositalmente o SFTP como verdadeiro, o que fará com que isso falhe."
    fi
    service wings restart
    output "Instalando servidor SFTP autônomo ..."
    curl -Lo sftp-server https://github.com/pterodactyl/sftp-server/releases/download/v1.0.5/sftp-server
    chmod +x sftp-server
    bash -c 'cat > /etc/systemd/system/pterosftp.service' <<-'EOF'
[Unit]
Description=Pterodactyl Standalone SFTP Server
After=wings.service
[Service]
User=root
WorkingDirectory=/srv/daemon
LimitNOFILE=4096
PIDFile=/var/run/wings/sftp.pid
ExecStart=/srv/daemon/sftp-server
Restart=on-failure
StartLimitInterval=600
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable pterosftp
    service pterosftp restart
}

upgrade_standalone_sftp(){
    output "Desligando o servidor SFTP autônomo ..."
    service pterosftp stop
    curl -Lo sftp-server https://github.com/pterodactyl/sftp-server/releases/download/v1.0.5/sftp-server
    chmod +x sftp-server
    service pterosftp start
    output "Seu servidor SFTP autônomo foi atualizado com sucesso para v1.0.5."
}

install_mobile(){
    cd /var/www/pterodactyl
    composer config repositories.cloud composer https://packages.pterodactyl.cloud
    composer require pterodactyl/mobile-addon --update-no-dev --optimize-autoloader
    php artisan migrate --force
}

upgrade_mobile(){
    cd /var/www/pterodactyl
    composer update pterodactyl/mobile-addon
    php artisan migrate --force
}

install_phpmyadmin(){
    output "Installing phpMyAdmin..."
    cd /var/www/pterodactyl/public
    rm -rf phpmyadmin
    wget https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN}/phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    unzip phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    mv phpMyAdmin-${PHPMYADMIN}-all-languages phpmyadmin
    rm -rf phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    cd /var/www/pterodactyl/public/phpmyadmin

    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    BOWFISH=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 34 | head -n 1`
    bash -c 'cat > /var/www/pterodactyl/public/phpmyadmin/config.inc.php' <<EOF
<?php
/* Servers configuration */
\$i = 0;
/* Server: MariaDB [1] */
\$i++;
\$cfg['Servers'][\$i]['verbose'] = 'MariaDB';
\$cfg['Servers'][\$i]['host'] = '${SERVER_IP}';
\$cfg['Servers'][\$i]['port'] = '';
\$cfg['Servers'][\$i]['socket'] = '';
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['user'] = 'root';
\$cfg['Servers'][\$i]['password'] = '';
/* End of servers configuration */
\$cfg['blowfish_secret'] = '${BOWFISH}';
\$cfg['DefaultLang'] = 'en';
\$cfg['ServerDefault'] = 1;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['CaptchaLoginPublicKey'] = '6LcJcjwUAAAAAO_Xqjrtj9wWufUpYRnK6BW8lnfn';
\$cfg['CaptchaLoginPrivateKey'] = '6LcJcjwUAAAAALOcDJqAEYKTDhwELCkzUkNDQ0J5'
?>    
EOF
    output "Instalação completa."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
}

ssl_certs(){
    output "Instalando o Let's Encrypt e criando um certificado SSL ..."
    cd /root
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install certbot
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install certbot
    fi
    if [ "$webserver" = "1" ]; then
        service nginx stop
    elif [ "$webserver" = "2" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            service apache2 stop
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
            service httpd stop
        fi
    fi

    certbot certonly --standalone --email "$email" --agree-tos -d "$FQDN" --non-interactive
    
    if [ "$installoption" = "2" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            ufw deny 80
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
            firewall-cmd --permanent --remove-port=80/tcp
            firewall-cmd --reload
        fi
    else
        if [ "$webserver" = "1" ]; then
            service nginx restart
        elif [ "$webserver" = "2" ]; then
            if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
                service apache2 restart
            elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
                service httpd restart
            fi
        fi
    fi
       
        if [ "$lsb_dist" =  "debian" ] || [ "$lsb_dist" =  "ubuntu" ]; then
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --post-hook "service apache2 restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "2" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --post-hook "service apache2 restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "3" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "ufw allow 80" --pre-hook "service wings stop" --post-hook "ufw deny 80" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "4" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "ufw allow 80" --pre-hook "service wings stop" --post-hook "ufw deny 80" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --pre-hook "service wings stop" --post-hook "service apache2 restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "6" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --pre-hook "service wings stop" --post-hook "service apache2 restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        fi
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --post-hook "service httpd restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "2" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --post-hook "service httpd restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "3" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "firewall-cmd --add-port=80/tcp && firewall-cmd --reload" --pre-hook "service wings stop" --post-hook "firewall-cmd --remove-port=80/tcp && firewall-cmd --reload" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "4" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "firewall-cmd --add-port=80/tcp && firewall-cmd --reload" --pre-hook "service wings stop" --post-hook "firewall-cmd --remove-port=80/tcp && firewall-cmd --reload" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --pre-hook "service wings stop" --post-hook "service httpd restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --pre-hook "service wings stop" --post-hook "service httpd restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "6" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --pre-hook "service wings stop" --post-hook "service httpd restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        fi
    fi
}

firewall(){
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install iptables
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "cloudlinux" ]; then
        yum -y install iptables
    fi

    curl -sSL https://raw.githubusercontent.com/tommytran732/Anti-DDOS-Iptables/master/iptables-no-prompt.sh | sudo bash
    block_icmp
    javapipe_kernel
    output "Setting up Fail2Ban..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install fail2ban
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install fail2ban
    fi 
    systemctl enable fail2ban
    bash -c 'cat > /etc/fail2ban/jail.local' <<-'EOF'
[DEFAULT]
# Ban hosts for ten hours:
bantime = 36000
# Override /etc/fail2ban/jail.d/00-firewalld.conf:
banaction = iptables-multiport
[sshd]
enabled = true
EOF
    service fail2ban restart

    output "Configurando seu firewall ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install ufw
        ufw allow 22
        if [ "$installoption" = "1" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 3306
        elif [ "$installoption" = "2" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 3306
        elif [ "$installoption" = "3" ]; then
            ufw allow 80
            ufw allow 8080
            ufw allow 2022
        elif [ "$installoption" = "4" ]; then
            ufw allow 80
            ufw allow 8080
            ufw allow 2022
        elif [ "$installoption" = "5" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 8080
            ufw allow 2022
            ufw allow 3306
        elif [ "$installoption" = "6" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 8080
            ufw allow 2022
            ufw allow 3306
        fi
        yes |ufw enable 
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install firewalld
        systemctl enable firewalld
        systemctl start firewalld
        if [ "$installoption" = "1" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --add-service=mysql --permanent
        elif [ "$installoption" = "2" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent
            firewall-cmd --add-service=mysql --permanent
        elif [ "$installoption" = "3" ]; then
            firewall-cmd --permanent --add-service=80/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
        elif [ "$installoption" = "4" ]; then
            firewall-cmd --permanent --add-service=80/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
        elif [ "$installoption" = "5" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --add-service=mysql
        elif [ "$installoption" = "6" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --add-service=mysql
        fi
    fi
}

block_icmp(){
    output "Bloquear Pacotes de ICMP (Ping) ?"
    output "Você deve escolher [1] se você não estiver usando um sistema de monitoramento e [2] de outra forma."
    output "[1] Yes."
    output "[2] No."
    read icmp
    case $icmp in
        1 ) /sbin/iptables -t mangle -A PREROUTING -p icmp -j DROP
            (crontab -l ; echo "@reboot /sbin/iptables -t mangle -A PREROUTING -p icmp -j DROP >> /dev/null 2>&1")| crontab - 
            ;;
        2 ) output "Pulando regra ..."
            ;;
        * ) output "Você não inseriu uma seleção válida."
            block_icmp
    esac    
}

javapipe_kernel(){
    output "Aplicar as configurações de kernel do JavaPipe (https://javapipe.com/blog/iptables-ddos-protection)?"
    output "[1] Yes."
    output "[2] No."
    read javapipe
    case $javapipe in
        1)  sh -c "$(curl -sSL https://raw.githubusercontent.com/tommytran732/Anti-DDOS-Iptables/master/javapipe_kernel.sh)"
            ;;
        2)  output "Modificações do kernel JavaPipe não aplicadas."
            ;;
        * ) output "Você não inseriu uma seleção válida."
            javapipe_kernel
    esac 
}

install_database() {
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install mariadb-server
	elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$dist_version" = "8" ]; then
	        dnf -y install MariaDB-server MariaDB-client --disablerepo=AppStream
        fi
	else 
	    dnf -y install MariaDB-server
	fi

    output "Criando os bancos de dados e definindo a senha root ..."
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="DROP DATABASE IF EXISTS test;"
    Q1="CREATE DATABASE IF NOT EXISTS panel;"
    Q2="SET old_passwords=0;"
    Q3="GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$password';"
    Q4="GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Vinculando MariaDB / MySQL a 0.0.0.0."
	if [ -f /etc/mysql/my.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/mysql/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/mysql/my.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	elif [ -f /etc/my.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/my.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
    	elif [ -f /etc/mysql/my.conf.d/mysqld.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/my.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	else 
		output 'O arquivo my.cnf não foi encontrado! Entre em contato com o suporte.'
	fi

    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        yes | ufw allow 3306
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ]; then
        firewall-cmd --permanent --add-service=mysql
        firewall-cmd --reload
    fi 

    broadcast_database
}

database_host_reset(){
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="SET old_passwords=0;"
    Q1="SET PASSWORD FOR 'admin'@'%' = PASSWORD('$adminpassword');"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}"
    mysql mysql -e "$SQL"

if grep -Fqs "bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf ; then
		sed -i -- '/bind-address/s/#//g' /etc/mysql/mariadb.conf.d/50-server.cnf
 		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/mysql/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
    	elif grep -Fqs "bind-address" /etc/mysql/my.conf.d/mysqld.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.conf.d/mysqld.cnf
		output 'Reiniciando o processo MySQL ...'
		service mysql restart
	else
		output 'Não foi possível detectar um arquivo de configuração do MySQL! Entre em contato com o suporte.'
	fi

    output "New database host information:"
    output "Host: $SERVER_IP"
    output "Port: 3306"
    output "User: admin"
    output "Password: $adminpassword"
}

broadcast(){
    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        broadcast_database
    fi
    output "###############################################################"
    output "INFORMAÇÕES DE FIREWALL"
    output ""
    output "Todas as portas desnecessárias são bloqueadas por padrão."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        output "Use 'ufw allow <port>' para habilitar as portas desejadas."
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] && [ "$dist_version" != "8" ]; then
        output "Use 'firewall-cmd --permanent --add-port = <port> / tcp' para habilitar as portas desejadas."
    fi
    output "###############################################################"
    output ""
}

broadcast_database(){
        output "###############################################################"
        output "INFORMAÇÕES MARIADB / MySQL"
        output ""
        output "Sua senha root MariaDB / MySQL é$rootpassword"
        output ""
        output "Crie seu host MariaDB / MySQL com as seguintes informações:"
        output "Host: $SERVER_IP"
        output "Porta: 3306"
        output "User: admin"
        output "Senha: $adminpassword"
        output "###############################################################"
        output ""
}

checkversion(){
	output "Qual é a versão serie do seu Pterodactyl?"
    output "[1] 1.0."
    output "[2] 0.7."
    read version
    case $version in
        1 )
			output "Você está ultilizando a serie 1.0!"
            ;;
        2 ) output "Você está ultilizando a serie 0.7!"
            ;;
        * ) output "Você não inseriu uma seleção válida."
            checkversion
    esac    
}

alterar(){
	required_infos
	checkversion
	netstat -tulpn | grep :80
    output "Insira so PID que foi mostrado"
    warn "Coloque, ou não irá funcionar"
    warn "Caso n tenha aperte ENTER"
    read pid
    
    kill $pid
certbot certonly --standalone --email "$email" --agree-tos -d "$FQDN" --non-interactive
cd /var/www/pterodactyl
if [ "$version" = "1" ]; then
	nginx_config
	php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/Sao_Paulo --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379

    output "A troca do url do painel está quase concluída, vá para o painel e obtenha o comando 'Auto Deploy' na guia de configuração do nó."
    output "Altere o seu FQDN no node para ${FQDN}"
    output "Cole seu comando de implantação automática abaixo ( Sem o 'cd /etc/pterodactyl &&' ): "
    read AUTODEPLOY
    ${AUTODEPLOY}
systemctl stop pteroq
ssl_certs
    systemctl enable --now wings
    systemctl start wings
    systemctl restart wings

elif [ "$version" = "2"]; then
	nginx_config_0.7.19
	php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/Sao_Paulo --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
        output "A troca do url do painel está quase concluída, vá para o painel e obtenha o comando 'Auto Deploy' na guia de configuração do nó."
        output "Altere o seu FQDN no node para ${FQDN}"
    output "Cole seu comando de implantação automática abaixo: "
    read AUTODEPLOY
    ${AUTODEPLOY}

    systemctl enable --now wings
    systemctl start wings
    systemctl restart wings
fi
}

translate(){
wget https://cdn.discordapp.com/attachments/831582323102318602/834543751879196703/scripts.zip
clear
mkdir /archives/
mkdir /archives/temp
mv scripts.zip /archives/temp
cd /var/www/pterodactyl/resources
unzip /archives/temp/scripts.zip
su -c 'apt update'
su -c 'apt install -y curl'
su -c 'curl -sL https://deb.nodesource.com/setup_14.x | bash -'
su -c 'apt update'
su -c 'apt install -y nodejs'
cd /var/www/pterodactyl/
npm install -g yarn
yarn install
yarn run build:production
rm -r /archives/temp
warn "Tradução realizada com sucesso"
}

#Execution
preflight
install_options
case $installoption in 
        1)   webserver_options
             repositories_setup
             required_infos
             firewall
             setup_pterodactyl
             broadcast
	     broadcast_database
	     install_options
             ;;
        2)   bash <(curl -s https://ragg.tech/Pterodactyl/dir/Legacy.sh)
	install_options
             ;;
        3)   repositories_setup
             required_infos
             firewall
             ssl_certs
             install_wings
             broadcast
	     broadcast_database
             ;;
        4)   repositories_setup_0.7.19
             required_infos
             firewall
             ssl_certs
             install_daemon
             broadcast
             ;;
        5)   webserver_options
             repositories_setup
             required_infos
             firewall
             ssl_certs
             setup_pterodactyl
             install_wings
             broadcast
	     broadcast_database
             ;;
        6)   https://ragg.tech/Pterodactyl/dir/Legacy.sh
             repositories_setup_0.7.19
             install_daemon
             broadcast
	     install_options
             ;;
        7)   install_standalone_sftp
	install_options
             ;;
        8)   upgrade_pterodactyl
	install_options
             ;;
        9)   upgrade_pterodactyl_1.0
	install_options
             ;;
        10)  theme_options
             upgrade_pterodactyl_0.7.19
             theme
	     install_options
             ;;
        11)  upgrade_daemon
	install_options
             ;;
        12)  migrate_wings
	install_options
             ;;
        13)  upgrade_pterodactyl_1.0
             migrate_wings
	     install_options
             ;;
        14)  theme_options
             upgrade_pterodactyl_0.7.19
             theme
             upgrade_daemon
	     install_options
             ;;
        15)  upgrade_standalone_sftp
	install_options
             ;;
        16)  install_mobile
	install_options
             ;;
        17)  upgrade_mobile
	install_options
             ;;
        18)  install_phpmyadmin
	install_options
             ;;
        19)  repositories_setup
             install_database
             ;;
        20)  theme_options
             if [ "$themeoption" = "1" ]; then
             	upgrade_pterodactyl_0.7.19
             fi
             theme
	     install_options
            ;;
        21) curl -sSL https://raw.githubusercontent.com/tommytran732/MariaDB-Root-Password-Reset/master/mariadb-104.sh | sudo bash
	install_options
            ;;
        22) database_host_reset
	    install_options
            ;;
        23) alterar
	    install_options
	    ;;
	0) logs
	    ;;
esac
