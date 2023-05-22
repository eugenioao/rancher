#!/bin/bash
#
# Script...: converter-configmap.sh
# Descricao: Exporta as variaveis de ambiente do deployment.yaml
# Autor....: Eugenio Oliveira


# Variaveis globais
vARQUIVOS=$1

###############################################################
# Converte o arquivo yaml
#

ConvertYAML() {

vCNFMAP="configmap-$(echo ${vARQUIVO%'-deployment.yaml'}).properties"

yq e '.spec.template.spec.containers[].env[]' ${vARQUIVO} > ${vARQUIVO}.tmp
vTIPOANT=""
> ${vCNFMAP}
vENV=0

while read vLINHA ; do

   vTIPO=$(echo $vLINHA|awk -F': ' '{print $1}')
   vENV=1

   case "${vTIPO}" in
        name)
                if [ "${vTIPOANT}" = "${vTIPO}" ]; then
                   eval "sed -i '/name: ${vNOME}/d' ${vARQUIVO}"
                   echo "${vNOME}=" >> ${vCNFMAP}
                fi
                vTIPOANT=${vTIPO}
                vNOME=$(echo $vLINHA|awk -F': ' '{print $2}')
        ;;
        value)
                vVALOR=$(echo $vLINHA|awk -F': ' '{print $2}')
                eval "sed -i '/name: ${vNOME}/d' ${vARQUIVO}"
                eval "sed -i '/value: ${vVALOR}/d' ${vARQUIVO}"
                echo "${vNOME}=${vVALOR}" >> ${vCNFMAP}
                vTIPOANT=${vTIPO}
        ;;
        *)
        ;;
   esac

done < ${vARQUIVO}.tmp

if [ $vENV -eq 1 ]; then
   if [ -z "$(yq e '.spec.template.spec.containers[].env[]' ${vARQUIVO})" ]; then
      vCNFMAP=$(echo ${vARQUIVO%'-deployment.yaml'})
      eval "sed -i '/ env:/a \                envFrom:\n                  - configMapRef:\n\                      name: ${vCNFMAP}-configmap' ${vARQUIVO}"
   fi
fi

rm -f ${vARQUIVO}.tmp

}

vCONTADOR=1
vCARACTER="/-\|"

echo "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
echo " Aguarde. Processando arquivo(s)"
echo "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
echo -n ' '

if [ -z "$1" ]; then
   vARQUIVOS=$(ls -1 *-deployment.yaml)
fi

for vARQUIVO in $vARQUIVOS ; do
    ConvertYAML
    printf "\b${vCARACTER:vCONTADOR++%${#vCARACTER}:1}"
done

echo ""
