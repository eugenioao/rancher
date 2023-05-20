# Converter do Rancher 1.6 para o Rancher 2.7
<img src="imagens/rancher-1_6-2_7.jpg" style="max-width: 85%;" align="center" />

Os scripts foram criados para ajudar na conversão das Stacks do Rancher 1.6 para o Rancher 2.7 com o menor ajuste possível. Eles não farão a conversão final automática por ser necessário criar os namespaces de cada projeto antes de importar os arquivos das aplicações/serviços. Este processo poderá ser realizado após a conversão de uma Stack ou parte dela.

**OBS: Você precisará efetuar a autenticação no Rancher 1.6 e 2.7 antes de iniciar a execução dos scripts.**

# Script: converter-r16to27.sh

Este script irá buscar as Stacks no Rancher 1.6 e efetuará a conversão dos arquivos docker-compose.yml e rancher-compose.yml de cada aplicação. Ele também irá remover as linhas que não serão compativeis com o Rancher 2.7.

## Dependencias:
   1) Instalar o migration-tools
   ```
      wget https://github.com/rancher/migration-tools/releases/download/v0.1.3/migration-tools_linux-amd64 \
      -O /usr/local/sbin/migration-tool
   ```

   2) Instalar a cli do Rancher 1.6
   ```
      wget https://releases.rancher.com/cli/v0.6.14/rancher-linux-amd64-v0.6.14.tar.gz \
      -O /tmp/rancher-v0.6.14.tar.gz && cd /tmp ; tar zxf rancher-v0.6.14.tar.gz && \
      mv rancher-v0.6.14/rancher /usr/local/sbin/rancher-1.6 ; rm -rf rancher-v0.6.14.tar.gz rancher-v0.6.14
   ```

   3) Instalar a cli do Rancher 2.7
   ```
      wget https://releases.rancher.com/cli2/v2.7.0/rancher-linux-amd64-v2.7.0.tar.gz \
      -O rancher-v2.7.0.tar.gz && cd /tmp ; tar zxf rancher-v2.7.0.tar.gz && \
      mv rancher-v2.7.0/rancher /usr/local/sbin/ ; rm -rf rancher-v2.7.0.tar.gz rancher-v2.7.0
   ```
      
   4) A instalação do kubectl é opcional
   ```
      curl -LO "https://dl.k8s.io/release/ \
      $(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
      mv kubectl /usr/local/bin/ && chmod +x /usr/local/bin/kubectl
   ```

Os arquivos de saida (docker-compose.yml e rancher-compose.yml) de cada stack serão gravados no diretório STACKS/\<nome da stack\>.

Para a importação dos arquivos gerados pelo script para o Rancher 2.7, execute:
   ```
   1. cd STACKS/<nome da stack>
   2. kubectl apply -f <nome>-deployment.yaml -n <namespace do projeto>
   ```


# Script: converter-svc-ingress-r16to27.sh

Este script irá converter os serviços do balanceador (haproxy) gerando um arquivo para o service e outro para o ingress de cada conexto publicado tendo como padrão os arquivos que estão no diretorio templates.  

## Dependencias:
   1) Instalar o yq
   ```
      wget https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_amd64 -O /usr/local/sbin/yq
   ```

   2) Instalar o migration-tools
   ```
      wget https://github.com/rancher/migration-tools/releases/download/v0.1.3/migration-tools_linux-amd64 \
      -O /usr/local/sbin/migration-tool
   ```

   3) Gerar o export do Balanceador (rancher-composer.yml)
   ```
      migration-tools export --url http://rancher.dominio.com.br/v1/ --access-key <CHAVE> --secret-key \
      <SECRET> --system <nome do balanceador>
   ```

   4) Dos templates service.yaml e ingress.yaml

Os arquivos de saida (\*-infress.yaml e \*-service.yaml) de cada serviço serão gravados no diretório HAPROXY/\<services\>/\<\*-\[ingress\|service\].yaml\>.

Para a importação dos arquivos gerados pelo script para o Rancher 2.7, execute:

   ```
   1. cd HAPROXY/<nome do services>
   2. kubectl apply -f <nome>-service.yaml -n <namespace do projeto>
   3. kubectl apply -f <nome>-ingress.yaml -n <namespace do projeto>
   ```

**OBS: Para que o service e o ingress seja atribuido ao POD, será necessário acresentar uma tag (seletor) no Deployment Config, no Service e no Ingresses.
Exemplo para uma tag:  app=\<nome da aplicação\>**
