#!/bin/bash

# Verificar si el script se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Definir variables
usuario=""
direccion_ip=""
rootPasswd=""

# Configurar la IP estática
echo "Configurando la IP estática a ${direccion_ip}"
cat <<EOL > /etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
allow-hotplug eth0
iface eth0 inet static
    address ${direccion_ip}
    netmask 255.255.255.0
    gateway 192.168.1.1
EOL

# Reiniciar el servicio de red para aplicar los cambios
echo "Reiniciando el servicio de red"
systemctl restart networking

# Actualizar el sistema
echo "Actualizando el sistema"
apt update
apt upgrade -y

# Instalar Docker y Docker Compose
echo "Instalando Docker y Docker Compose"
apt install -y docker docker-compose

#Instalar sudo
apt install sudo

# Crear el usuario ${usuario} con permisos sudo
echo "Creando el usuario ${usuario} con permisos sudo"
useradd -m -s /bin/bash ${usuario}
echo "${usuario}:${usuario}" | chpasswd
usermod -aG sudo ${usuario}

# Agregar el usuario ${usuario} al grupo docker
echo "Agregando el usuario ${usuario} al grupo docker"
usermod -aG docker ${usuario}

# Cambiar la contraseña de root
echo "Cambiando la contraseña de root"
echo "root:${rootPasswd}" | chpasswd

# Crear la carpeta Portainer y el archivo docker-compose.yml
echo "Creando la carpeta Portainer y el archivo docker-compose.yml"
mkdir -p /home/${usuario}/Portainer
cat <<EOL > /home/${usuario}/Portainer/docker-compose.yml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "8000:8000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

volumes:
  portainer_data:
EOL

# Cambiar el propietario de la carpeta Portainer a ${usuario}
chown -R ${usuario}:${usuario} /home/${usuario}/Portainer

# Crear la carpeta para montar el dispositivo
echo "Creando la carpeta /home/${usuario}/plex/media para montar el dispositivo"
mkdir -p /home/${usuario}/plex/media
chown -R ${usuario}:${usuario} /home/${usuario}/plex/media

# Agregar la entrada al archivo /etc/fstab
echo "Agregando la entrada en /etc/fstab para montar el dispositivo con UUID 29A454401B165805"
echo "UUID=29A454401B165805 /home/${usuario}/plex/media ntfs defaults,uid=$(id -u ${usuario}),gid=$(id -g ${usuario}) 0 0" | tee -a /etc/fstab

# Montar el dispositivo
echo "Montando el dispositivo"
mount -a

# Cambiar el directorio a /home/${usuario}/Portainer y levantar los contenedores con docker-compose
echo "Iniciando Portainer con Docker Compose"
cd /home/${usuario}/Portainer
docker-compose up -d

echo "Configuración completada. Por favor, reinicie el servidor."
