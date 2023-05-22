#!/bin/bash
#
# Script...: deploy-rancher.sh
# Descrição: Faz a criacao e o deploy no racnher 2.7
# Autor....: Eugenio Oliveira
# Data.....: 16/05/2023
#
# Dependencias:
#
#  1) Instalar a cli do Rancher 2.7
#     wget https://releases.rancher.com/cli2/v2.7.0/rancher-linux-amd64-v2.7.0.tar.gz -O rancher-v2.7.0.tar.gz
#     cd /tmp ; tar zxf rancher-v2.7.0.tar.gz ; mv rancher-v2.7.0/rancher /home/jenkins/rancher/bin/
#     rm -rf rancher-v2.7.0.tar.gz rancher-v2.7.0
#
#  2) Instalar o cli do kubectl
#     curl -LO "https://dl.k8s.io/release/ \
#     $(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
#     mv kubectl /home/jenkins/rancher/bin/ && chmod +x /home/jenkins/rancher/bin/kubectl
#
#  3) Instalar o yq
#     wget https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_amd64 -O /home/jenkins/rancher/bin/yq
#
# Parametros:
#
#	1º - Sigla do Ambiente (dsv,hmg,prd)
#	2º - Nome do Projeto
#	3º - Nome do Namespace
#	4º - Nome da Aplicacao
#	5º - Diretorio dos arquivos de configuracao do gitlab
#

if [ $# -lt 5 ] ; then
   echo " ATENÇÃO"
   echo " ---------"
   echo " Você precisa informar todos os parametros para a atualizacao no Rancher 2.7."
   echo " Exemplo: $(basename $0) AMBIENTE PROJETO NAMESPACE APLICACAO DIRETORIO"
   echo ""
   exit 1
fi

# Declaracao de variaveis
vAMBIENTE=${1#*'r2-'}
vPROJETO=$(echo ${2}|tr '[:lower:]' '[:upper:]')
vNAMESPACE="$3"
vAPLICACAO="$4"
vSTGTIPO=""
vHOME="/home/jenkins/rancher"
vBIN="${vHOME}/bin"

################################################################
# KubectlPatchCS: Faz a atualizacao do configmap e/ou secret
################################################################

KubectlPatchCS() {

      ${vBIN}/kubectl get ${vSTGTIPO} ${vAPLICACAO}-${vSTGTIPO} -n ${vNAMESPACE} -o yaml| ${vBIN}/yq '.data' > ${vSTGTIPO}.tmp 2>&1
      while read vLINHA ; do
        vCHAVE="$(echo $vLINHA|awk '{print $1}'|awk -F':' '{print $1}')"
        vVALOR="$(echo $vLINHA|awk '{print $2}')"
        vSTRING="${vCHAVE}=${vVALOR}"

        vRESP=`eval "grep '${vSTRING}' ${vSTGTIPO}.properties"`
        if [ -z "$vRESP" ]; then
	   echo "[-] Removendo chave [${vCHAVE}] e valor [****] do ${vAPLICACAO}-${vSTGTIPO}"
           eval "${vBIN}/kubectl patch ${vSTGTIPO} -n ${vNAMESPACE} ${vAPLICACAO}-${vSTGTIPO} --type=json -p='[{\"op\": \"remove\", \"path\": \"/data/$vCHAVE\"}]' > /dev/null 2>&1" 
        fi
      done < ${vSTGTIPO}.tmp

      ${vBIN}/kubectl get ${vSTGTIPO} ${vAPLICACAO}-${vSTGTIPO} -n ${vNAMESPACE} -o yaml| ${vBIN}/yq '.data' > ${vSTGTIPO}.tmp 2>&1
      while read vLINHA ; do
        vCHAVE="$(echo $vLINHA|awk -F'=' '{print $1}')"
        vVALOR="$(echo $vLINHA|awk -F'=' '{print $2}')"
        vSTRING="${vCHAVE}: ${vVALOR}"

        vR=`eval "grep '${vSTRING}' ${vSTGTIPO}.tmp"`
        if [ -z "$vR" ]; then
	   echo "[-] Adicionando chave [${vCHAVE}] e valor [****] no ${vAPLICACAO}-${vSTGTIPO}"
           eval "${vBIN}/kubectl patch ${vSTGTIPO} -n ${vNAMESPACE} ${vAPLICACAO}-${vSTGTIPO} -p '{\"data\":{\"$vCHAVE\":\"$vVALOR\"}}' > /dev/null 2>&1"
        fi
      done < ${vSTGTIPO}.properties

}

echo "[+] Iniciando o processo de criação/atualização"

#echo "    [-] Criando diretorio temporario e copiando arquivos"
vTMP=$(mktemp -d)
cd ${vTMP}
cp -a $5/* .

# Define qual ambiente usar
export KUBECONFIG=${vHOME}/etc/config/${vAMBIENTE}/kubeconfig.yaml
export RANCHER_CONFIG_DIR=${vHOME}/etc/config/${vAMBIENTE}/

#echo "[+] Verificando o Projeto no Rancher 2.7 [${vAMBIENTE}]"
${vBIN}/rancher project ls --format="{{.Project.Name}}" > projetos.tmp 2>&1
if [ -z "$(grep ${vPROJETO} projetos.tmp)" ]; then
   echo -n "[-] Criando o Projeto ${vPROJETO}"
   ${vBIN}/rancher projects create ${vPROJETO} > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo -e "\nERRO ao criar o ${vPROJETO}"
      exit 1
   fi
   echo " - OK"
fi

#echo "[+] Alterando para o Projeto ${vPROJETO}"
${vBIN}/rancher context switch ${vPROJETO} > /dev/null 2>&1

#echo "[+] Verificando o namespace ${vNAMESPACE} do Projeto ${vPROJETO}"
${vBIN}/rancher namespace ls --all-namespaces --format '{{.Namespace.Name}}' > namespaces.tmp 2>&1
if [ -z "$(grep -x ${vNAMESPACE} namespaces.tmp)" ]; then

   echo -n "[+] Criando o namespace ${vNAMESPACE} no Projeto ${vPROJETO}"
   ${vBIN}/rancher namespace create ${vNAMESPACE} > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo -e "\nERRO ao criar o namespace ${vNAMESPACE} no ${vPROJETO}"
      exit 1
   fi
   echo " - OK"

fi

#echo "[+] Verificando a secret registry do namespace ${vNAMESPACE}"
${vBIN}/kubectl get secret -n ${vNAMESPACE} > secrets.tmp 2>&1
if [ -z "$(grep ^registry secrets.tmp)" ]; then

   echo -n "[+] Criando a secret registry"
   ${vBIN}/kubectl apply -f ${vHOME}/etc/config/registry.yaml -n ${vNAMESPACE} > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo -e "\nERRO ao criar a secret da registry no Projeto ${vPROJETO}"
      exit 1
   fi
   echo " - OK"

fi

if [ -f "configmap.properties" ] ; then

   #echo "[+] Verificando o configmap ${vAPLICACAO}-configmap do namespace ${vNAMESPACE}"
   ${vBIN}/kubectl get configmap -n ${vNAMESPACE} > configmap.tmp 2>&1
   if [ -z "$(grep ${vAPLICACAO}-configmap configmap.tmp)" ]; then
      echo -n "[+] Criando a confimap ${vAPLICACAO}-configmap"
      ${vBIN}/kubectl create configmap ${vAPLICACAO}-configmap --from-env-file=configmap.properties -n ${vNAMESPACE} > /dev/null 2>&1
      if [ $? -eq 1 ]; then
	 echo -e "\nERRO ao criar a configmap ${vAPLICACAO}-configmap no namespace ${vNAMESPACE}"
         exit 1
      fi
      echo " - OK"
   else
      vSTGTIPO="configmap"
      KubectlPatchCS
   fi

fi

if [ -f "secret.properties" ] ; then

   #echo "[+] Verificando o secret ${vAPLICACAO}-secret do namespace ${vNAMESPACE}"
   if [ -z "$(grep ${vAPLICACAO}-secret secrets.tmp)" ]; then
      echo -n "[+] Criando a secret ${vAPLICACAO}-secret"
      ${vBIN}/kubectl create secret generic ${vAPLICACAO}-secret --from-env-file=secret.properties -n ${vNAMESPACE} > /dev/null 2>&1
      if [ $? -eq 1 ]; then
	 echo -e "\nERRO ao criar a secret ${vAPLICACAO}-secret no namespace ${vNAMESPACE}"
         exit 1
      fi
      echo " - OK"
   else
      vSTGTIPO="secret"
      KubectlPatchCS
   fi

fi

if [ -f service.yaml ] ; then
   echo -n "[+] Aplicando o service da ${vAPLICACAO}"
   ${vBIN}/kubectl apply -f service.yaml -n ${vNAMESPACE} > /dev/null 2>&1
   if [ $? -eq 1 ]; then
      echo -e "\nERRO ao criar o service da aplicacao ${vAPLICACAO} no namespace ${vNAMESPACE}"
      exit 1
   fi
   echo " - OK"
fi

if [ -f ingress.yaml ] ; then
   echo -n "[+] Aplicando o ingress da ${vAPLICACAO}"
   ${vBIN}/kubectl apply -f ingress.yaml -n ${vNAMESPACE} > /dev/null 2>&1
   if [ $? -eq 1 ]; then
      echo -e "\nERRO ao criar o ingress da aplicacao ${vAPLICACAO} no namespace ${vNAMESPACE}"
      exit 1
   fi
   echo " - OK"
fi

if [ ! -f deployment.yaml ] ; then
   echo "ERRO: o arquivo deployment.yaml nao foi encontrado"
   exit 
fi

#echo "[+] Verificando a aplicacao ${vAPLICACAO} no namespace ${vNAMESPACE}"
${vBIN}/kubectl get pod -n ${vNAMESPACE} > pod.tmp 2>&1
if [ -z "$(grep ${vAPLICACAO} pod.tmp)" ]; then
   echo -n "[+] Criando a aplicacao ${vAPLICACAO}"
   ${vBIN}/kubectl apply -f deployment.yaml -n ${vNAMESPACE} > /dev/null 2>&1
   if [ $? -eq 1 ]; then
      echo -e "\nERRO ao criar a aplicacao ${vAPLICACAO} no namespace ${vNAMESPACE}"
      exit 1
   fi
   echo " - OK"
else
   echo -n "[+] Atualizando a aplicacao ${vAPLICACAO}"

   case "$vAMBIENTE" in
	prd|prod)
		${vBIN}/kubectl apply -f deployment.yaml -n ${vNAMESPACE} > /dev/null 2>&1
		if [ $? -eq 1 ]; then
		   echo -e "\nERRO ao atualizar a aplicacao ${vAPLICACAO} no namespace ${vNAMESPACE}"
		   exit 1
		fi
	;;
	dsv|hmg)
		# Redeploy
		${vBIN}/kubectl rollout restart deployment/${vAPLICACAO} -n ${vNAMESPACE} > /dev/null 2>&1
		if [ $? -eq 1 ]; then
		   echo -e "\nERRO ao efetuar o redeploy da aplicacao ${vAPLICACAO} no namespace ${vNAMESPACE}"
		   exit 1
		fi
	;;
	*)
		echo -e "\nERRO. Ambiente rancher não identificado."
		exit 1
	;;
   esac
   echo " - OK"
fi
cd
rm -rf $vTMP

echo "[*] Fim da execução."
