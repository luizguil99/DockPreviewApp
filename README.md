# DockPreviewApp

Um aplicativo macOS que exibe visualizações de janelas abertas ao passar o mouse sobre ícones no Dock, estilo Windows.

## Requisitos

- macOS 14.0 ou superior (testado no macOS 15)
- Permissões de Acessibilidade (necessário para ler a posição do Dock e janelas)
- Permissões de Gravação de Tela (necessário para tirar screenshots das janelas)

## Como Compilar e Rodar

1. Abra o terminal na pasta do projeto.
2. Compile o projeto:
   ```bash
   swift build
   ```
3. Execute o aplicativo:
   ```bash
   ./.build/debug/DockPreviewApp
   ```

## Solução de Problemas

- **Permissões**: Na primeira execução, o macOS deve solicitar permissões de Acessibilidade e Gravação de Tela. Se não solicitar, vá em `Ajustes do Sistema` -> `Privacidade e Segurança` -> `Acessibilidade` e adicione o seu Terminal (ou o aplicativo compilado se movido para um bundle). O mesmo para `Gravação de Tela`.
- **Tela Preta/Vazia**: Se as visualizações aparecerem pretas ou vazias, verifique a permissão de Gravação de Tela.


cd DockPreviewApp
swift build
./.build/debug/DockPreviewApp
