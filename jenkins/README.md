#
# Script de deploy das aplicações - Rancher 2.7 para o Jenkins 


# Dependencias:
```
1) Instalar a cli do Rancher 2.7
   wget https://releases.rancher.com/cli2/v2.7.0/rancher-linux-amd64-v2.7.0.tar.gz -O rancher-v2.7.0.tar.gz
   cd /tmp ; tar zxf rancher-v2.7.0.tar.gz ; mv rancher-v2.7.0/rancher /home/jenkins/rancher/bin/
   rm -rf rancher-v2.7.0.tar.gz rancher-v2.7.0

2) Instalar o cli do kubectl
   curl -LO "https://dl.k8s.io/release/ \
   $(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
   mv kubectl /home/jenkins/rancher/bin/ && chmod +x /home/jenkins/rancher/bin/kubectl
	   
3) Instalar o yq
   wget https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_amd64 -O /home/jenkins/rancher/bin/yq

```

# Parametros:

	1º - Sigla do ambiente (dsv,hmg,prd)
	2º - Nome do Projeto
	3º - Nome do Namespace
	4º - Nome da Aplicacao
	5º - Diretorio dos arquivos de configuracao do gitlab


# Exemplo de chamada

```
deploy-rancher.sh hmg PROJETO namespace aplicacao-frontend /home/jenkins/workspace/aplicacao-frontend/hmg

```
