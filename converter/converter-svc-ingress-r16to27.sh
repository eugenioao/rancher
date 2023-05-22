#!/bin/bash
#
# Script...: converter-svc-ingress-r16to27.sh
# Descricao: Converte a configuração do Balanceador (haproxy) do Rancher 1.6
# Autor....: Eugenio Oliveira <iigenio@msn.com>
# Data.....: 27/04/2023
#
# Dependencias:
#       1) Instalar o yq
#          wget https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_amd64 -O /usr/local/sbin/yq
#
#       2) Instalar o migration-tools
#          wget https://github.com/rancher/migration-tools/releases/download/v0.1.3/migration-tools_linux-amd64 -O /usr/local/sbin/migration-tool
#
#       3) Gerar o export do Balanceador (rancher-composer.yml)
#          migration-tools export --url http://rancher16.dominio.com.br/v1/ --access-key <CHAVE> --secret-key <SECRET> --system Balanceador
#
#       4) Dos templates service.yaml e ingress.yaml
#
#

aARQUIVOS=('rancher-compose.yml' 'templates/service.yaml' 'templates/ingress.yaml')

for vARQUIVO in "${aARQUIVOS[@]}" ; do
    if [ ! -f ${vARQUIVO} ]; then
       echo " ATENÇÃO"
       echo " ---------"
       echo " Arquivo ${vARQUIVO} não encontrado."
       echo " Execute o $(basename $0) onde tem o ${aARQUIVOS[0]} e o diretório de templates."
       echo ""
       exit 1
    fi
done

vTMP="HAPROXY"
rm -rf ${vTMP}
mkdir ${vTMP}

echo "[+] Iniciando a conversão dos serviços do Balanceador"

yq e ".services | keys" rancher-compose.yml|awk '{print $2}' > ${vTMP}/keys.log
for vENV in $(cat ${vTMP}/keys.log) ; do

    vQTD=$(yq e ".services.${vENV}.lb_config.port_rules[]" rancher-compose.yml | grep hostname|wc -l)

    rm -rf ${vTMP}/${vENV}
    mkdir -p ${vTMP}/${vENV}

    for ((i=0;i<${vQTD};i++)) ; do

        echo "    [-] Gerando o bloco do service/ingress"
        yq e ".services.${vENV}.lb_config.port_rules[${i}]" rancher-compose.yml | grep -E 'hostname|path|service|target_port' > ${vTMP}/${vENV}/service-ingress.log

        if [ -s ${vTMP}/${vENV}/service-ingress.log ] ; then

           vHOST=$(grep 'hostname:' ${vTMP}/${vENV}/service-ingress.log|awk '{print $2}')
           echo "        [-] Processando bloco do ${vHOST}"

           vARQINGRESS="${vTMP}/${vENV}/${vHOST}-ingress.yaml"
           vARQSERVICE="${vTMP}/${vENV}/${vHOST}-service.yaml"

           vPATH=$(grep 'path:' ${vTMP}/${vENV}/service-ingress.log|awk '{print $2}')
           vSERVICE=$(grep 'service:' ${vTMP}/${vENV}/service-ingress.log|awk -F'/' '{print $2}')
           vTARGET=$(grep 'target_port:' ${vTMP}/${vENV}/service-ingress.log|awk '{print $2}')

           if [[ -z "${vPATH}" || "${vPATH}" = "''" ]] ; then
              echo -e "        paths:\n          - backend:\n              service:\n                name: ${vSERVICE}\n                port:\n                  number: 443\n            pathType: ImplementationSpecific" > ${vTMP}/path.log
           else
              echo -e "        paths:\n          - backend:\n              service:\n                name: ${vSERVICE}\n                port:\n                  number: 443\n            path: ${vPATH}\n            pathType: Prefix" > ${vTMP}/path.log
           fi

           if [ ! -f ${vARQINGRESS} ] ; then
              echo "            [-] Criando arquivo ${vARQINGRESS}"
              cp templates/ingress.yaml ${vARQINGRESS}
           fi
           eval "sed -i -e 's/NAME/${vHOST}/' ${vARQINGRESS}"
           eval "sed -i -e 's/SERVICE/${vSERVICE}/' ${vARQINGRESS}"
           eval "sed -i -e 's/TARGET_PORT/${vTARGET}/' ${vARQINGRESS}"

           eval "sed -i '13 e sed -n 2,13p ${vTMP}/path.log' ${vARQINGRESS}"
           if [ ! -f ${vARQSERVICE} ] ; then
              echo "            [-] Criando arquivo ${vARQSERVICE}"
              cp templates/service.yaml ${vARQSERVICE}
              eval "sed -i -e 's/SERVICE/${vSERVICE}/' ${vARQSERVICE}"
              eval "sed -i -e 's/TARGET_PORT/${vTARGET}/' ${vARQSERVICE}"
           fi
        fi
    done
done
echo "[*] Fim da execução."
