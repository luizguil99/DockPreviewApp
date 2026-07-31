# DockPreviewApp

Um aplicativo macOS que exibe visualizações de janelas abertas ao passar o mouse sobre ícones no Dock, estilo Windows.

## Requisitos

- macOS 14.0 ou superior (testado no macOS 15)
- Permissões de Acessibilidade (necessário para ler a posição do Dock e janelas)
- Permissões de Gravação de Tela são opcionais. Sem elas, o overlay mostra detalhes da janela e controles; com elas, adiciona uma miniatura visual.

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

- **Permissões**: A permissão de Acessibilidade é necessária para detectar o Dock e controlar janelas. A permissão de Gravação de Tela só é necessária para as miniaturas visuais.
- **Sem miniaturas**: Sem Gravação de Tela, o app usa automaticamente cards com ícone, título, documento/perfil e estado da janela; o restante do overlay continua funcionando.
- **Ativar miniaturas reais**: Clique no botão de olho riscado no cabeçalho do overlay e autorize `Gravação de Tela`. O app captura somente a janela usada na miniatura e não salva o resultado em arquivo.
Para iniciar automaticamente com o Mac:
Vá em Ajustes do Sistema → Geral → Itens de Início
Clique em + e adicione DockPreviewApp

open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"


cd DockPreviewApp
swift build
./.build/debug/DockPreviewApp
