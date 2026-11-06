# Como enviar assets novos (passo a passo)

1. No computador, junta o pack numa pasta e faz um **.zip** (botão direito → Comprimir).
   Um zip conta como 1 ficheiro; o GitHub pelo browser só aceita 100 ficheiros de cada vez.
2. No GitHub, abre esta pasta **`entrada`** e carrega em **Add file → Upload files**.
3. Arrasta o .zip, escreve uma frase em baixo (ex.: "pack de mechs") e carrega em **Commit changes**.
4. Diz no chat que enviaste. O Claude organiza tudo em `assets/` e apaga daqui.

**O que incluir num pack de modelos:** a versão **glTF** (ou **FBX**) se existir — é a que traz as
**animações** — e as **texturas** (.png). A versão .obj não tem animações.

Ficheiro maior que 25 MB: em vez do passo 2, cria uma **release-rascunho** (Releases → Draft a new
release) e anexa lá o zip; não é preciso publicar.
