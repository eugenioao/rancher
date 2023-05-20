#!/bin/bash
#
# Script...: converter-r16to27.sh
# Descrição: Exporta e converte do Rancher 1.6 para o 2.x
# Autor....: Eugenio Oliveira <iigenio@msn.com>
# Data.....: 27/04/2023
#
#
# Como criar um Projeto e namespace dentro do projeto
# rancher projects create NOME_DO_PROJETO
# rancher context switch NOME_DO_PROJETO
# rancher namespaces create NOME_DO_NAMESPACE
#
# Dependencias:
#       1) Instalar o migration-tools
#          wget https://github.com/rancher/migration-tools/releases/download/v0.1.3/migration-tools_linux-amd64 -O /usr/local/sbin/migration-tool
#
#       2) Instalar a cli do Rancher 1.6
#          wget https://releases.rancher.com/cli/v0.6.14/rancher-linux-amd64-v0.6.14.tar.gz -O ${vTMP}/rancher-v0.6.14.tar.gz
#          cd /tmp ; tar zxf rancher-v0.6.14.tar.gz ; mv rancher-v0.6.14/rancher /usr/local/sbin/rancher-1.6
#          rm -rf rancher-v0.6.14.tar.gz rancher-v0.6.14
#
#       3) Instalar a cli do Rancher 2.7
#          wget https://releases.rancher.com/cli2/v2.7.0/rancher-linux-amd64-v2.7.0.tar.gz -O rancher-v2.7.0.tar.gz
#          cd /tmp ; tar zxf rancher-v2.7.0.tar.gz ; mv rancher-v2.7.0/rancher /usr/local/sbin/
#          rm -rf rancher-v2.7.0.tar.gz rancher-v2.7.0
#

if [[ -z "$1" || -z "${KUBECONFIG}" ]]; then
   echo " ATENÇÃO"
   echo " ---------"
   echo " Você precisa informar o ID do Rancher 1.6 e/ou definir a variável KUBECONFIG do Rancher 2.7."
   echo " Exemplo: $(basename $0) 1a5"
   echo ""
   exit 1
fi

vENV=${1}
vDIR=$(pwd)/STACKS
vTMP="tmp"

if [ -d ${vDIR} ] ; then
   rm -rf ${vDIR}
fi
mkdir -p ${vDIR}

if [ -z "${2}" ]; then
   echo "[+] Exportando a lista das Stacks de ${vENV}"
   rancher-1.6 --env ${vENV} stacks --format="{{.Stack.Name}}" | grep -vEi 'Balanceador|Prometheus' > ${vTMP}/stacks.log
else
   echo "[+] Exportando a lista da Stack ${2} de ${vENV}"
   echo ${2} > ${vTMP}/stacks.log
fi

if [ ! -s ${vTMP}/stacks.log ] ; then
   echo "[x] A lista das stacks esta vazia!"
   exit 1
fi

echo "[+] Exportando a lista de Projetos do Rancher 2.7 [$(basename $KUBECONFIG)]"
rancher project ls --format="{{.Project.Name}}" > ${vTMP}/projetos.log

> ${vTMP}/stacks-falha.log

for vSTACKS in $(cat ${vTMP}/stacks.log) ; do

    if [ -z "$(grep -i ${vSTACKS} ${vTMP}/projetos.log)" ] ; then
       echo "[-] Criando o projeto [${vSTACKS}] no Rancher 2.7"
       rancher project create ${vSTACKS} > /dev/null 2>&1
    fi

    cd ${vDIR}
    echo "[-] Exportando as configurações da Stack ${vSTACKS}"
    rancher-1.6 --env ${vENV} export --system ${vSTACKS} > /dev/null 2>&1

    echo "    [-] Convertendo os arquivos da Stack ${vSTACKS}"
    cd ${vDIR}/${vSTACKS}
    migration-tools parse --docker-file=${vDIR}/${vSTACKS}/docker-compose.yml --rancher-file=${vDIR}/${vSTACKS}/rancher-compose.yml > /dev/null 2>&1
    if [ $? -ne 0 ]; then
       echo "        [x] Erro na conversão dos arquivos da Stack ${vSTACKS}"
       echo ${vSTACKS} >> ${vTMP}/stacks-falha.log
    else
       cd ${vDIR}
       echo "    [-] Removendo as linhas desnecessárias dos arquivos .yaml"
       grep '>>' ${vSTACKS}/output.txt | sort -u|awk -F'>>' '{print $2}' > ${vSTACKS}/output-tmp.txt

       for vARQUIVO in $(ls -1 ${vSTACKS}/*-deployment.yaml) ; do

           sed -i '/restartPolicy: Always/a \            imagePullSecrets: \n\            - name: registry' ${vARQUIVO}
           eval "sed -i -e 's/io.kompose.service/app/' ${vARQUIVO}"

           for vLINHA in $(cat ${vSTACKS}/output-tmp.txt) ; do
               eval "sed -i '/${vLINHA}/d' ${vARQUIVO}"
           done
           sed -i '/kompose.cmd/d' ${vARQUIVO}
           sed -i '/kompose.version/d' ${vARQUIVO}
           sed -i '/rancher-compose/d' ${vARQUIVO}

       done
       echo "    [-] Excluindo os arquivos [docker|rancher]-compose.yml"
       rm -f ${vDIR}/${vSTACKS}/docker-compose.yml ${vDIR}/${vSTACKS}/rancher-compose.yml ${vSTACKS}/output*.txt
    fi
    sleep 2s
done
echo "[*] Fim da execução."
