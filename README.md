# Edge Mouse Gestures para AutoHotkey v2

Script de gestos do mouse para Windows, feito para AutoHotkey v2.

## Recursos

- Botão direito + movimento: voltar, avançar, rolar para o início ou para o fim.
- Movimento para cima e depois para a esquerda/direita: troca de guia.
- Botão direito parado + roda: ajusta o volume.
- Botão direito + botão do meio: play/pause ou troca de música ao arrastar.
- `Ctrl + Alt + G`: ativa ou pausa os gestos.
- `Ctrl + Alt + V`: processa as linhas da área de transferência.
- Traço visual e quadro de ação na tela.
- Clique direito comum preservado quando não há movimento suficiente.

## Como usar no Windows

1. Instale o AutoHotkey v2.
2. Copie `Atualizar-EdgeMouseGestures.ps1`, `Iniciar-EdgeMouseGestures.cmd` e `EdgeMouseGestures.ahk` para a mesma pasta.
3. Execute `Iniciar-EdgeMouseGestures.cmd`.

O iniciador consulta o commit atual publicado no GitHub antes de executar o script. Se houver uma versão nova, ele cria uma cópia `.bak` da versão anterior e atualiza o arquivo local.

## Arquivos instalados

Na instalação padrão usada neste projeto, os arquivos ficam em:

`C:\Users\mrpir\OneDrive\Documentos`

O atualizador usa apenas HTTPS e não grava senha nem token do GitHub.
