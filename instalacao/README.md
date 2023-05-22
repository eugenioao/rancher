# Procedimentos para instalação de um ambiente kubernetes (k8s)
Instalação com RKE2 - Rancher 2.7, LongHorm e Backup

# Pré-requisitos
Para um ambiente em cluster (HA), precisa de 3 servidores para o etcd/controlplane, 2 (ou mais) para os workers e de um balanceador (vip) de carga. 
Todos os servidores devem ser registrados no DNS Server com reverso e criação de uma URL de gerencia. A instalação deverá ser com a opção Minimal.

# Servidores Linux - Configuração minima:
Para o etcd e ControlPlane (3 servidores)

```
vCPU: 4
RAM: 8Gb
HD: 60Gb para o S.O., 80Gb para o /var/lib/rancher
S.O.: RHEL 8.7
```

Para os Workers (minimo de 2 servidores)

```
vCPU: 8
RAM: 16Gb
HD: 60Gb para o S.O., 100Gb para o /var/lib/rancher e 200Gb para o /var/lib/longhorn
S.O.: RHEL 8.7
```

# Em todos os servidores, configure e instale conforme abaixo:

1) Adicione as configurações do kernel no /etc/sysctl.conf

```
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
```

2) Instale os pacotes basicos

```
dnf install -y nfs-utils curl wget
```

3) Nos workers, caso o longhorn seja instalado, será necessário instalar o iscsi

```
dnf install -y iscsi-initiator-utils
systemctl enable --now iscsid.service
```

4) Desabilite os serviços e swap

```
systemctl disable --now firewalld

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
```

5) Reinicie os servidores antes de continuar com a instalação


# Instalação com o RKE2
Após instalar todos os servidores e montar os volumes, podemos iniciar a instalação do ambiente via RKE2.

# Instalação no servidor master (1º servidor)
A instalação do master é simples e não requer muito esforço mas tenha paciencia pois pode demorar.

1) Efetue o login via ssh no 1º servidor

2) Instale o serviço

```
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="server" sh -
```

3) Crie o arquivo com as configurações iniciais

```
mkdir -p /etc/rancher/rke2/
vi /etc/rancher/rke2/config.yaml
cluster-cidr: "10.x.0.0/16"
service-cidr: "10.x.0.0/16"
cni: calico
```

4) Inicie o serviço do rke2-server (este processo é demorado)

```
systemctl enable --now rke2-server.service
```

5) Configure a variavel para o kubectl e acompanhe a configuração

```
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml PATH=\$PATH:/var/lib/rancher/rke2/bin" >> ~/.bash_profile 
source ~/.bash_profile 

# Verificar se o node já está pronto 
kubectl get nodes 

# Verificar se os pods já subiram 
kubectl get pod -A 
```

6) Quando o servidor estiver com o status de pronto, pege o token

```
cat /var/lib/rancher/rke2/server/token
```


# Instalação no servidores de slaves
A instalação dos slaves é semelhante à instalação do master. A diferença é que precisamos do arquivo de configuração com o IP e token do master antes de iniciar o serviço. 

1) Efetue o login via ssh no 2º e 3º servidor

2) Instale o serviço

```
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="server" sh -
```

3) Crie o arquivo com as configurações iniciais

```
mkdir -p /etc/rancher/rke2/ 
vim /etc/rancher/rke2/config.yaml 
server: https://<IP_DO_SERVIDOR_MASTER>:9345 
token: <TOKEN_DO_SERVIDOR_MASTER> 
cluster-cidr: "10.x.0.0/16"
service-cidr: "10.x.0.0/16"
cni: calico
```

4) Inicie o serviço do rke2-server

```
systemctl enable --now rke2-server.service
```

5) Configure a variavel para o kubectl e acompanhe a finalização da configuração

```
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml PATH=\$PATH:/var/lib/rancher/rke2/bin" >> ~/.bash_profile 
source ~/.bash_profile 

# Verificar se o node já está pronto 
kubectl get nodes 

```

Faça os mesmos procedimentos para todos os servidores do etcd/controlplane e ao finalizar, aguarde pelo menos uns 10 minutos antes de continuar a instalação dos agentes (workers).


# Instalação no servidores de Workers
A instalação dos servidores agentes (Workers) é semelhante à instalação do slave. A diferença é o parametro INSTALL_RKE2_TYPE.

1) Efetue o login via ssh nos servidores de workers

2) Instale o serviço

```
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
```

3) Crie o arquivo com as configurações iniciais

```
mkdir -p /etc/rancher/rke2/ 
vim /etc/rancher/rke2/config.yaml 
server: https://<IP_DO_SERVIDOR_MASTER>:9345 
token: <TOKEN_DO_SERVIDOR_MASTER> 
cluster-cidr: "10.x.0.0/16"
service-cidr: "10.x.0.0/16"
cni: calico
```

4) Inicie o serviço do rke2-agent (este processo é demorado)

```
systemctl enable --now rke2-agent.service
```

5) Configure a variavel para o kubectl e acompanhe a finalização da configuração

```
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml PATH=\$PATH:/var/lib/rancher/rke2/bin" >> ~/.bash_profile 
source ~/.bash_profile 

# Verificar se o node já está pronto 
kubectl get nodes 

```

6) Altere a role do servidor

```
kubectl label nodes <nome_do_servidor> node-role.kubernetes.io/worker=true
```


Faça os mesmos procedimentos para todos os servidores do agent (workers) e ao finalizar, aguarde pelo menos uns 5 minutos antes de continuar com a instalação do Rancher.


# Instalação do Rancher 2.7
Se tudo ocorreu de forma normal com os procedimentos acima, a instalação do cluster k8s foi concluída.
Para seguir, precisaremos instalar o Helm em algum local. A instalação pode ser feita em qualquer servidor ou estação que tenha acesso ao cluster.
Para instalar o cliente em um servidor diferente ou estação de trabalho, instale o kubectl, o Helm e copie o rke2.yaml do master ***(tenha cuidado com ele)***. 

1) Faça o download e instalação do kubectl e do Helm

```
cd /tmp
# A instalação do kubectl é opcional
curl -LO "https://dl.k8s.io/release/ \
$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
mv kubectl /usr/local/bin/ && chmod +x /usr/local/bin/kubectl

wget https://get.helm.sh/helm-v3.11.2-linux-amd64.tar.gz && \
tar xvf helm-v3.11.2-linux-amd64.tar.gz && \
mv linux-amd64/helm /usr/local/bin/ && \
rm -rf linux-amd64 helm-v3.11.2-linux-amd64.tar.gz 
```

2) Adicione o repositório da ultima versão estável do Rancher

```
/usr/local/bin/helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
```

3) Crie o Namespace para o Cert Manager e Rancher

```
kubectl create namespace cattle-system
```

4) Aplique as credenciais do certificado 

```
kubectl apply -f \
https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.crds.yaml
```

5) Adicione o repositório do jetstack 

```
helm repo add jetstack https://charts.jetstack.io 
```

6) Atualize os repositórios

```
helm repo update
```

7) Instale o cert-manager 

```
helm install cert-manager jetstack/cert-manager \ 
--namespace cert-manager \ 
--create-namespace \ 
--version 1.11.0 
```

8) Instale o Rancher 2.7

```
helm install rancher rancher-stable/rancher \ 
--namespace cattle-system \ 
--set hostname=<DEFINIR_UMA_URL>.dominio.com.br \ 
--set replicas=3 \ 
--set bootstrapPassword=<DEFINIR_UMA_SENHA>
```

9) Verifique o adamento do deploy do Rancher

```
kubectl -n cattle-system rollout status deploy/rancher 
```

10) Verifique o status do deploy do Rancher

```
kubectl -n cattle-system get deploy rancher 
```

Acompanhe a finalização da instalação com o ```kubectl get pod -A```. Assim que finalizar, a console do Rancher estará disponível para uso.
Faça o acesso usando a URL informada no --set hostname e valide toda a configuração inicial.

# Instalação do LongHorn
Neste procedimento, o longhorn será instalado somente como repositório para o backup do cluster. Ele também poderá ser usado como volume para as aplicações e neste caso, o planejamento para o tamanho do volume deverá ser de acordo com a necessidade.
Antes de iniciar, verifique nos ***workers*** se foi criado o volume /var/lib/longhorn com espaço necessário.

1) Efetue o login na interface do Rancher, selecione o cluster e depois Projects/Namespace
2) Clique no botão Create Project e informe o nome Longhorn e clique em Save
3) Clique em Nodes e ***em cada node de worker***, configure (Edit Config) o label do longhorn

```
   node.longhorn.io/create-default-disk = true
```
ou

```
   kubectl label nodes <nome_do_nome> node.longhorn.io/create-default-disk=true
```

4) No menu lateral, clique em Apps e Charts ou clique em Cluster Tools no rodapé
5) Na lista de Charts, clique em LongHorn e depois no botão Install
6) Marque a opção Customize Helm options before install e depois em Next
7) Marque a opção Customize Default Settings, marque também a opção Create Default Disk on Labeled Nodes e clique em Next
8) Clique em Install e aguarde o processo de instalação finalizar

Se tudo ocorreu de forma normal, o LongHorn foi instalado com sucesso.


# Instalação e configuração do Rancher Backup
O Rancher possue uma ferramenta de backup para o caso de recupeção de desastres do cluster. Para instalar, siga os procedimentos abaixo.

1) Efetue o login na interface do Rancher e selecione o cluster local
2) Clique no botão Create Project e informe o nome BackupRancher e clique em Save
3) No menu lateral, clique em Apps e Charts ou clique em Cluster Tools no rodapé
4) Na lista de Charts, clique em Rancher Backups
5) Clique em Install
6) Selecione o Project BackupRancher, marque a opção Customize Helm options before install e clique em Next
7) Selecione a opção Use an existing storage class, selecione longhorn e defina um tamanho. Normalmente 15Gi e clique em Next
8) Clique em Install e aguarde o processo de instalação finalizar

Se tudo ocorreu de forma normal, o Rancher Backups foi instalado com sucesso. Agora é criar a(s) rotina(s) de backup(s).
