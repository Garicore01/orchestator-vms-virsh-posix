#!/bin/sh

## Añadir un destroy
# Autor: Gari Arellano Zubía 848905.
# Pequeño script para orquestar las acciones sobre las máquinas virtuales.

CONFIG_FILE="vms_config.cfg"
SSH_USER="a848905"

# PRE: El orden de los parametros es <accion>, <nombre_maquina>. En caso de tener tres parametros, el tercero es el hipervisor.
# POST: Ejecuta <accion> en el hipervisor correspondiente sobre la maquina <nombre_maquina>
ejecutar_accion() {
    accion=$1
    nombre_maquina=$2
    # Hay veces que me pasan un tercer parametro, para utilizar un hipervisor especifico.
    if [ "$#" -eq 3 ]; then
        hipervisor=$3
    else
        hipervisor=$(obtener_primer_hipervisor_disponible)
    fi

    if [ -z "$hipervisor" ]; then
        echo "Error: No se encontró un hipervisor disponible en la configuración."
        exit 1
    fi
    echo "$hipervisor" "$accion" "$nombre_maquina_config"
    case $accion in
        start)
            ssh -nf "$SSH_USER@$hipervisor" "virsh -c qemu:///system start $nombre_maquina" 
            ;;
        stop)
            ssh -nf "$SSH_USER@$hipervisor" "virsh -c qemu:///system shutdown $nombre_maquina"
            ;;
        restart)
            ssh -nf "$SSH_USER@$hipervisor" "virsh -c qemu:///system reboot $nombre_maquina"
            ;;
        define)
            ssh -nf "$SSH_USER@$hipervisor" "virsh -c qemu:///system define <remote_path>/$nombre_maquina.xml" 
            ;;
        undefine)
            ssh -nf "$SSH_USER@$hipervisor" "virsh -c qemu:///system undefine $nombre_maquina" 
            ;;
        list)
            ssh "$SSH_USER@$hipervisor" "virsh -c qemu:///system list --all"
            ;;
        create)
            crear_maquina_virtual "$nombre_maquina" "$3" "$4" "$5" "$hipervisor"
            ;;
        *)
            echo "Acción no válida"
            ;;
    esac
}

# PRE: Los parametros de invocación son los cambios a realizar en el XML de la máquina virtual y el hipervisor al que se quiere conectar.
# POST: Se crea una imagen diferencial de la imagen base o5.qcow2 y se realizan las modificaciones necesarias en el XML de la nueva maquina.
crear_maquina_virtual() {
    nombre_maquina=$1
    w=$2
    xy=$3
    z=$4
    hipervisor=$5
    ruta_destino="<remote_path>/$nombre_maquina"
    ruta_origen="<remote_path>/o5.qcow2"

    # Clonamos la imagen.
    ssh -nf "$SSH_USER@$hipervisor" "qemu-img create -f qcow2 -o backing_file=$ruta_origen,backing_fmt=qcow2 $ruta_destino.qcow2 &&
    cp <remote_path>/o5.xml $ruta_destino.xml && 
    chmod ug+rw $ruta_destino.xml &&
    chmod ug+rw $ruta_destino.qcow2 &&
    sed -i 's|<mac address='\''52:54:00:05:FF:01'\''/>|<mac address='\''52:54:00:0$w:$xy:0$z'\''/>|' $ruta_destino.xml  &&
    sed -i 's|<name>o5</name>|<name>$nombre_maquina</name>|' $ruta_destino.xml &&
    sed -i 's|<uuid>5ceb27cf-35ce-49b8-adf2-8ac0cc5f5111</uuid>|<uuid>5ceb27cf-35ce-49b8-adf2-8ac0cc5f$w$xy$z</uuid>|' $ruta_destino.xml &&
    sed -i 's|<source file='\''<remote_path>/o5.qcow2'\''/>|<source file='\''$ruta_destino.qcow2'\''/>|' $ruta_destino.xml"
}

# PRE: $CONFIG_FILE debe ser un fichero de configuración válido.
# POST: Se comprueba y devuelve el primer hipervisor encendido del grupo [Grupo Hipervisores].
obtener_primer_hipervisor_disponible() {
    in_grupo=false
    while read -r line; do
        if [ "$line" = "[Grupo Hipervisores]" ]; then
            in_grupo=true
        elif [ "$in_grupo" = "true" ]; then
            hipervisor_name=$(echo "$line" | tr -d '[:space:]')
            # Realizar un ping al hipervisor
            if ping -c 1 "$hipervisor_name" > /dev/null 2>&1; then
                echo "$hipervisor_name"
                return 
            fi
        fi
    done < "$CONFIG_FILE"

    echo ""  # Devolver cadena vacía si no se encuentra ningún hipervisor disponible
}

######################################################################################################################################################
######################################################################################################################################################
# Principal
######################################################################################################################################################
######################################################################################################################################################

if [ "$1" = "help" ]; then
    echo "Manual de uso del script: orquestador-vm-adsis2.sh"
    echo "Uso 1: Se especifica una acción y una máquina virtual. Tambien se podria especificar un hipervisor."
    echo "./orquestador-vm.sh <accion> <nombre_maquina> [hipervisor]\n"
    echo "Uso 2: Se especifica una acción que se ejecuta para todas las maquinas configuradas y se ejecutan en el primer hipervisor disponible."
    echo "./orquestador-vm.sh <accion>\n"
    echo "Uso 3: Crear una nueva maquina virtual."
    echo "./orquestador-vm-adsis2.sh create <nombre_maquina> <W> <XY> <Z>\n"
    echo "Acciones disponibles:"
    echo "  start: Iniciar máquina virtual."
    echo "  stop: Apagar máquina virtual."
    echo "  restart: Reiniciar máquina virtual."
    echo "  define: Definir máquina virtual."
    echo "  undefine: Eliminar la definición de máquina virtual."
    echo "  list: Listar las máquinas virtuales."
    echo "  create: Crear una nueva máquina virtual."
elif [ "$#" -eq 3 ]; then
    # Caso en el que se especifica una máquina virtual e hipervisor
    # Ejemplo de uso: ./orquestador-vm.sh define orouter5 hipervisor
    ejecutar_accion "$1" "$2" "$3"
elif [ "$#" -eq 5 ]; then
    # Caso en el que se quiere clonar una nueva maquina virtual.
    # Ejemplo de uso: ./orquestador-vm.sh crear orouter5 W XY Z 
    ejecutar_accion "$1" "$2" "$3" "$4" "$5"
else
    # Caso en el que tengo que iterar el fichero de configuración.
    # Ejemplo de uso: ./orquestador-vm.sh define
    accion=$1
    # Si no se especifica una máquina virtual, hay que buscar y realizar la acción para todas las máquinas que están en el archivo de configuración
    # y pertenecen al grupo "Grupo VMS"
    while read -r line; do
        if [ "$line" = "[Grupo VMS]" ]; then
            in_grupo=true
        elif [ "$line" = "[Grupo Hipervisores]" ]; then
            break
        elif [ "$in_grupo" = "true" ]; then
            nombre_maquina_config=$(echo "$line" | cut -d '=' -f 1 | tr -d '[:space:]')
            if [ ! -z "$nombre_maquina_config" ]; then
                #echo "$hipervisor" "$accion" "$nombre_maquina_config"
                ejecutar_accion "$accion" "$nombre_maquina_config"
            fi
        fi
    done < "$CONFIG_FILE"

    # Esperar a que todos los procesos secundarios (ssh en segundo plano) finalicen
    wait
fi
