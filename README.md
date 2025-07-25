# Projeto GitOps Kubernetes

- [Objetivos](#Objetivos)
- [Pré-requisitos](#Pré-requisitos)

1. [Criar a aplicação FastAPI](#1-criar-a-aplicação-fastapi)
2. [Criar o GitHub Actions (CI/CD)](#2-criar-o-github-actions-cicd)
3. [Criar manifestos Kubernetes](#3-criar-manifestos-kubernetes)
4. [Criar o app no ArgoCD](#4-criar-o-app-no-argocd)
5. [Acessar aplicação localmente e testar alteração do main.py](#5-acessar-aplicação-localmente-e-testar-alteração-do-mainpy)

---

## Objetivos

### Automatizar o ciclo completo de desenvolvimento, build, deploy e execução de uma aplicação FastAPI simples, usando GitHub Actions para CI/CD, Docker Hub como registry, e ArgoCD para entrega contínua em Kubernetes local com Rancher Desktop.

## Pré-requisitos

- Conta no GitHub (repo público)
- Conta no Docker Hub com token de acesso
- Rancher Desktop com Kubernetes habilitado
- kubectl configurado corretamente (kubectl get nodes)
- ArgoCD instalado no cluster local
- Git instalado
- Python 3 e Docker instalados

## 1. Criar a aplicação FastAPI

Para isso, deve-se criar repositórios específicos para a aplicação:

- app-python (onde ficará localizado o Dockerfile e main.py)
- app-manifests (onde estará todos manifestos para o ArgoCD)

Com eles criados, agora será criado o main.py. Para isso, clone o repositório app-python localmente e com ajuda do VS Code, crie o arquivo com os seguintes:

```python
from fastapi import FastAPI
app = FastAPI()
@app.get("/")
async def root():
    return {"message": "Hello World"}
```

**IMPORTANTE**: A indentação precisa estar correta para o código funcionar.

Esse código tem como objetivo apenas retornar o famoso "Hello World".

Agora, para o Dockerfile:

```Docker
FROM python:alpine3.22

WORKDIR /app

RUN pip install "fastapi" uvicorn

COPY main.py .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

Primeiro é definida a imagem base, sendo ela o python com alpine, após é definida a pasta que servirá para os próximos códigos. É feita a instalação das dependências, sendo elas o próprio FastAPI e o uvicorn, um servidor ASGI necessário quando é utilizado FastAPI. Em sequencia, é copiado o código python escrito anteriormente e é exposta a porta que será utilizada. Agora é feito o mapeamento do uvicorn para que o programa python possa ser executado na porta e endereço correto, essa etapa é importante pois garante que a aplicação possa ser acessada fora do container, quando as portas forem mapeadas.

Os manifestos serão produzidos em uma próxima etapa.

## 2. Criar o GitHub Actions (CI/CD)

Para criar a etapa de CI/CD no projeto, deve-se primeiro criar a estruturação de pastas a seguir:

Em um terminal, na pasta raiz do repositório app-python, execute:

```cmd
mkdir .github
cd .github
mkdir workflows
```

Dentro da pasta workflows, deve estar localizado o yaml com o seguinte:

```yaml
name: CI/CD

on:
  push:

jobs:
  buildar-e-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{secrets.DOCKER_NOMEUSUARIO}}
          password: ${{secrets.DOCKER_SENHA}}

      - name: Buildar e push da imagem Docker
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{secrets.DOCKER_NOMEUSUARIO}}/app-python:latest
            ${{secrets.DOCKER_NOMEUSUARIO}}/app-python:${{github.sha}}

      - name: Checkout Repositório dos manifestos ArgoCD
        uses: actions/checkout@v4
        with:
          repository: yuri-ferreira/app-manifests
          token: ${{secrets.PAT}}
          path: app-manifests

      - name: Atualizar tag da imagem no manifesto Kubernetes
        run: |
          cd app-manifests
          sed -i "s|image: .*/app-python:.*|image: ${{ secrets.DOCKER_NOMEUSUARIO }}/app-python:${{ github.sha }}|g" deployment.yaml
          git config user.name "GitHub Actions Bot"
          git config user.email "actions@github.com"
          git add deployment.yaml
          git commit -m "Atualizando a imagem do app-python para ${{ github.sha }} 🥳" || echo "Nenhuma mudança 👍"

      - name: Criar Pull Request para o manifesto ArgoCD
        uses: peter-evans/create-pull-request@v6
        with:
          token: ${{secrets.PAT}}
          commit-message: "Atualizar a imagem do python-app para ${{github.sha}}"
          title: "Atualizar a imagem do python-app para ${{github.sha}}"
          body: "Esse Pull Request serve para atualizar a imagem Docker do python-app no manifesto Kubernetes :)"
          branch: atualizar-tag-da-imagem${{github.sha}}
          base: main
          delete-branch: true
          path: app-manifests
```

#### Para explicação será dividido em módulos:

#### Criar Secrets no repo

Para acessar o Docker Hub ou até mesmo fazer as mudanças no manifest kubernetes é necessário a chave/login/senha de cada um. Para isso, será utilizado os Actions secrets do GitHub. Para criar um secret, deve-se:

![Criando Secrets1](/imgs/criando-secrets.png)

Ao clicar no botão "New repository secret":

![Criando Secrets2](/imgs/criando-secrets2.png)

Assim, pode adicionar um nome ao secret como por exemplo: **DOCKER_NOMEUSUARIO** e adicionar um valor, nesse caso o nome de usuário no docker hub.

#### Criar PAT

Para algumas ações do github actions é necessário o PAT, para criá-lo deve-se:

Entrar em configurações da conta e clicar em "Developer Settings"

![Criando PAT1](/imgs/criar-pat1.png)

Agora, clicar no "Personal Acess Tokens" no "Tokens(classic)":

Nessa tela, clique em "Generate new token" e em "Generate new token (classic)"

![Criando PAT2](/imgs/criar-pat2.png)

![Criando PAT3](/imgs/criar-pat3.png)

Agora, deve-se adicionar um nome para o PAT, selecionar quando deve expirar e marcar caixinha "repo" para garantir todos os direitos sobre repo. Após tudo, clique em criar.

#### YAML:

#### - Declarações iniciais

Primeiro, será feita a declaração do nome, quando deve ser executada e configurada para rodar em um ambiente ubuntu. Após, é definido os jobs:

#### - Login no Docker HUB

Com o uso da ação:(docker/login-action@v3), é feito a autenticação do workflow no Docker Hub, usando o nome e senha inseridos nos secrets criados anteriormente.

---

#### - Build e Push

Com o uso da ação:(docker/build-push-action@v5), é feito a construção da imagem a partir do Dockerfile localizado na raiz (.), em seguida é enviada para o Docker Hub. Sempre serão criadas duas tags para a imagem, latest e o sha.

---

#### - Checkout repositório dos manifestos ArgoCD

Com o uso da ação:(actions/checkout@v4), o repositório onde está localizado os manifestos é clonado, é necessário utilizar o token do PAT criado anteriormente.

---

#### - Atualizar tag da imagem no manifesto

Aqui é uma parte muito importante do CI/CD, é feito uma série de comandos a serem executados no ubuntu que tem como os seguintes objetivos:

- **cd app-manifests**: Entrar na pasta app-manifests, onde o repositório foi clonado.
- **sed -i "s|image: ._/app-python:._|image: ${{ secrets.DOCKER_NOMEUSUARIO }}/app-python:${{ github.sha }}|g" deployment.yaml**: Aqui com o comando **sed**, é feita a troca da linha da versão da imagem da aplicação no arquivo deployment.yaml. Dessa maneira ele procura por qualquer linha que comece com image seguida por qualquer coisa, /app-python: e substitui pelo meu nome de usuário no Docker Hub e o sha do commit atual.
- **git config user.name "GitHub Actions Bot"**: é configurado o nome do usuário.
- **git config user.email "actions@github.com"**: é configurado o email do usuário.
- **git add deployment.yaml**: aqui é adicionado o deployment.yaml modificado para o commit.
- **git commit -m "Atualizando a imagem do app-pyhon para ${{ github.sha }} 🥳" || echo "Nenhuma mudança 👍"**: Aqui é feito o commit com uma variação para caso não tenha ocorrido nenhuma mudança.

---

#### - Criar Pull Request para o manifesto

Com o uso da ação:(peter-evans/create-pull-request@v6), é feito o Pull Request para alteração da imagem. Foi adicionado uma mensagem com a varíavel sha. Para efetuar com sucesso, é necessário o token do PAT, criado anteriormente e adicionado ao secrets do repo. Após o merge a branch criada é deletada. Sempre será feito o merge na main.

## 3. Criar manifestos Kubernetes

Agora, será utilizado o [repositório app-manifests](https://github.com/yuri-ferreira/app-manifests).

Deve-se criar na raiz, deployment.yaml e service.yaml com os seguintes:

**Deployment**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-python-deployment
  labels:
    app: app-python
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-python
  template:
    metadata:
      labels:
        app: app-python
    spec:
      containers:
        - name: app-python
          image: yuribrigido/app-python:7576d7f324dfb86579351f010eb53af7e220d0f9
          ports:
            - containerPort: 8080
```

**Service**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-python-servico
spec:
  selector:
    app: app-python
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
```

Aqui o deployment serve para a criação do deployment que criará os pods da aplicação e irá gerenciar eles.

Já o service serve para a criação do serviço clusterIP que irá expor os pods para fora do deployment.

## 4. Criar o app no ArgoCD

Para criar a aplicação no ArgoCD deve-se:

Primeiramente fazer o port-forward do ArgoCD para acessa-lo, para isso em um terminal após ter feito a aplicação dos manifests do ArgoCD:

```Kubernetes
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Caso não tenha aplicado:

```
kubectl create namespace argocd

Após:

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Com isso, é necessário encontrar as credenciais para acessar. Em um terminal execute:

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"

[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("Output_do_comando_anterior"))
```

Com isso, na home do ArgoCD, clique em "Aplications" e depois em "New APP"

![Criando APP ArgoCD](/imgs/argocd-1.png)

![Criando APP ArgoCD](/imgs/argocd-2.png)

Nessa nova tela, digite um **nome para a sua aplicação**, **selecione um projeto** (pode utilizar o default),selecione para **sincronizar automaticamente** e marque as opções:

**Prune Resources, Self Heal, Set Deletion Finalizer, Auto-Create Namespace**.

![Criando APP ArgoCD](/imgs/argocd-3.png)

Aqui, digite a **url do repositório dos manifestos**, selecione a **branch main** e em **path digite (.)**, pois os arquivos estão na raiz. Após clique em criar aplicação.

![Criando APP ArgoCD](/imgs/argocd-4.png)

Com isso, o ArgoCD irá sincronizar com o repositório.

## 5. Acessar aplicação localmente e testar alteração do main.py

Com todos os passos anteriores feitos agora é necessário fazer o port-forward da aplicação, para isso, execute em um terminal:

```
kubectl port-forward svc/app-python-servico 80:80 -n app-python
```

Com isso é possível acessar a aplicação e ver o retorno:

![Retorno aplicação](/imgs/retorno01.png)

Agora para testar se está tudo funcionando, será feito uma modificação no main.py com outra mensagem para retornar.

```PYTHON
from fastapi import FastAPI
app = FastAPI()
@app.get("/")
async def root():
    return {"message": "Aoba mundo! Essa é uma nova mensagem para testar se está tudo funcionando! 🥳"}
```

Com a alteração no main.py é necessário aceitar o Pull Request efetuado pelo Git Actions, para isso, acesse o repositório dos manifests (app-manifests), e clique na aba "Pull Requests":

![Pull Request](/imgs/pullrequest01.png)

Ao clicar no PR criado, é necessário clicar no botão "merge", assim essa branch será destruída e as modificações serão adicionadas a branch principal (main).

![Pull Request](/imgs/pullrequest02.png)
![Pull Request](/imgs/pullrequest03.png)

Com isso, é necessário que o ArgoCD sincronize com essa branch nova, como foi configurado na etapa anterior, ele sincronizará de forma automática, e após alguns minutos a nova aplicação estará de pé, podendo ver a alteração da mensagem na print a seguir:

![ArgoCD sincronizando](/imgs/argocd-semsync.png)

![ArgoCD sincronizado](/imgs/argocd-sync.png)

![Novo retorno de mensagem](/imgs/nova-mensagem-retornada.png)

**Assim, o projeto está finalizado! Podendo alterar a aplicação que será gerado automaticamente uma nova imagem e com um simples clique para aceitar o Pull Request é possível adiciona-la no manifesto da aplicação e rodar com o ArgoCD sempre verificando a branch principal para alterar**
