# Primeiro envio para o GitHub (Godot 4)

## 1. Preparar

Instale [Git](https://git-scm.com/) e [Git LFS](https://git-lfs.com/).
No GitHub, crie um repositório **vazio**, sem README, licença ou `.gitignore`.
Os comandos abaixo destinam-se ao PowerShell; substitua nome, email e URL.
Execute cada passo apenas se o anterior terminar sem erros.

```powershell
Set-Location "C:\Users\JV\Desktop\GAME"
git --version
git lfs version
git init -b main
git config user.name "O seu nome"
git config user.email "O seu email ou email noreply do GitHub"
git lfs install --local
```

Instale o LFS **antes de adicionar assets**. O `.gitattributes` já contém as
regras; não é necessário repetir `git lfs track` para as extensões configuradas.
Todos os PNG dessas extensões usam LFS, mesmo pequenos: o Git não filtra por
tamanho no `.gitattributes`. Novos formatos pesados precisam de regras próprias.

## 2. Criar commits organizados

Primeiro, versionar a política de armazenamento:

```powershell
git add .gitignore .gitattributes
git commit -m "chore: configure Godot ignores and Git LFS"
```

Depois, preparar e verificar o projeto:

```powershell
git add .
git status --short
git diff --cached --stat
git ls-files -- .godot
git lfs ls-files
git check-attr filter diff merge text -- assets/example.png assets/example.wav
```

`git ls-files -- .godot` deve ficar vazio. `git lfs ls-files` lista os assets
realmente adicionados ao LFS; fica vazio se ainda não existirem assets abrangidos.
Os caminhos `assets/example.*` são exemplos: `check-attr` valida as regras mesmo
sem esses ficheiros e deve indicar `filter/diff/merge: lfs` e `text: unset`.

```powershell
git commit -m "feat: add initial Godot project"
git lfs fsck
git status
```

## 3. Associar o remoto e enviar

```powershell
git remote add origin https://github.com/UTILIZADOR/REPOSITORIO.git
git remote -v
git push -u origin main
```

Autentique-se pelo gestor de credenciais do Git ou por token quando solicitado;
a palavra-passe da conta GitHub não funciona para Git via HTTPS. O hook instalado
pelo LFS envia automaticamente os objetos antes do push dos commits.

## 4. Limites e ficheiros que devem ser preservados

- `.godot/` é cache regenerável. Já os ficheiros `*.import` junto dos assets
  contêm opções de importação e devem ser versionados, tal como `*.uid`,
  `project.godot`, `export_presets.cfg`, `*.tscn` e `*.tres`.
- Guarde exports em `build/`, `builds/`, `dist/`, `export/` ou `exports/`.
  Distribua builds através de GitHub Releases, em vez de commits.
- O GitHub bloqueia ficheiros acima de **100 MiB no Git normal**. LFS armazena
  ponteiros no Git, mas tem quotas de armazenamento/tráfego e limites por ficheiro
  dependentes do plano. Consulte os [limites atuais do LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage)
  antes de enviar assets volumosos; LFS não é armazenamento ilimitado.
- `-text` nas regras LFS impede alterações de finais de linha nos binários.
  Fontes Godot usam LF e continuam disponíveis para diff e merge normais.
- Estas instruções pressupõem um repositório novo. Adicionar regras LFS ou ignore
  não remove binários nem caches de commits antigos; um histórico existente exige
  migração própria antes do push.

## 5. Clonar noutra máquina

Instale Git e Git LFS, depois:

```powershell
git lfs install
git clone https://github.com/UTILIZADOR/REPOSITORIO.git
Set-Location REPOSITORIO
git lfs pull
```

Abra `project.godot`; o Godot reconstruirá `.godot/` a partir dos assets originais.
