# Projeto GitOps Kubernetes

- [Objetivos](#Objetivos)
- [Pré-requisitos](#Pré-requisitos)

1. [Criar a aplicação FastAPI](#1-criar-a-aplicação-fastapi)
2. [Criar o GitHub Actions (CI/CD)](#2-criar-o-github-actions-cicd)

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

Primeiro é definida a imagem base, sendo ela o python com alpine, após é definida a pasta que servirá para os próximos códigos. É feita a instalação das dependencias, sendo elas o próprio FastAPI e o uvicorn, um servidor ASGI necessário quando é utilizado FastAPI. Em sequencia, é copiado o código python escrito anteriormente e é exposta a porta que será utilizada. Agora é feito o mapeamento do uvicorn para que o programa python possa ser executado na porta e endereço correto, essa etapa é importante pois garante que a aplicação possa ser acessada fora do container, quando as portas forem mapeadas.

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
            ${{secrets.DOCKER_NOMEUSUARIO}}/app-python:$${{github.sha}}

      - name: Checkout Repositório dos manifestos ArgoCD
        uses: actions/checkout@v4
        with:
          repository: yuri-ferreira/app-manifests
          token: ${{secrets.PAT}}
          path: app-manifests

      - name: Atualizar tag da imagem no manifesto Kubernetes
        run: |
          cd app-manifests
          sed -i 's|image: ${{ secrets.DOCKER_NOMEUSUARIO }}/app-python:.*|image: ${{ secrets.DOCKER_NOMEUSUARIO }}/app-python:${{ github.sha }}|g' deployment.yaml 
          git config user.name "GitHub Actions Bot"
          git config user.email "actions@github.com"
          git add deployment.yaml
          git commit -m "Atualizando a imagem do app-pyhon para ${{ github.sha }} 🥳" || echo "Nenhuma mudança 👍"

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

#### Para explicação será dividio em módulos:

Primeiro, será feita a declaração do nome, e quando deve ser executada. Após, é definido os jobs:

#### - Login no Docker HUB

lorem ipsum dolore

---

#### - Build e Push

---

#### - Checkout repositório dos manifestos ArgoCD

---

#### - Atualizar tag da imagem no manifesto

---

#### - Criar Pull Request para o manifesto
