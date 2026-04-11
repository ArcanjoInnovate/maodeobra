# Mao de Obra

O **Mao de Obra** e o marketplace e rede social profissional feito para a construcao civil. Conectamos trabalhadores, empreiteiros e empresas de forma simples, rapida e profissional.

## Tecnologias

- **Flutter** (Dart) - Framework mobile multiplataforma
- **Firebase** - Backend (Realtime Database, Auth, Storage, Cloud Functions, Messaging)
- **Provider** - Gerenciamento de estado
- **Hive** - Cache local

## Estrutura do Projeto

```
lib/
  main.dart                    # Ponto de entrada do app
  firebase_options.dart        # Configuracoes Firebase

  core/                        # Nucleo da aplicacao
    constants/                 # Constantes e configuracoes (Firebase paths, etc.)
    repositories/              # Repositorios de dados (UserRepository)
    utils/                     # Utilitarios (formatacao de datas, etc.)

  models/                      # Modelos de dados
    user_model.dart
    chat/                      # Modelos de chat (Chat, Message, Participant)
    search/                    # Modelos de busca (Professional, Vacancy)

  controllers/                 # Controllers (ChangeNotifier)
    chat_controller.dart
    feed_controller.dart
    search_controller.dart

  services/                    # Camada de servicos
    auth/                      # Autenticacao
    badge/                     # Badges e notificacoes nao lidas
    cache/                     # Cache local (Hive)
    chat/                      # Servicos de chat
    complaint/                 # Denuncias
    feed/                      # Feed de vagas e profissionais
    notifications/             # Notificacoes push
    search/                    # Busca e filtros
    storage/                   # Upload de imagens/arquivos
    vacancy/                   # Gestao de vagas

  screens/                     # Telas da aplicacao
    admin/                     # Acoes administrativas (ban, suspensao, advertencia)
    auth/                      # Autenticacao (login, registro, splash, onboarding)
    chat/                      # Telas de chat
    complaints/                # Telas de denuncia
    configurations/            # Configuracoes do app
    feed/                      # Feed principal
    home/                      # Tela principal
    profile/                   # Edicao de perfil
    search/                    # Busca de vagas e profissionais
    vacancy/                   # Gestao de vagas

  widgets/                     # Componentes reutilizaveis
    common/                    # Widgets genericos
    chat/                      # Widgets de chat
    feed/                      # Cards de profissional e vaga
    permissions/               # Utilitarios de permissao
    vacancy/                   # Controles de vaga

scripts/                       # Scripts utilitarios
cloud_functions/               # Cloud Functions (Node.js)
```

## Configuracao

### Pre-requisitos

- Flutter SDK >= 3.5.0
- Dart SDK >= 3.5.0
- Firebase CLI

### Instalacao

```bash
# Instalar dependencias
flutter pub get

# Rodar o app
flutter run
```

### Firebase

O projeto usa Firebase com as seguintes funcionalidades:
- **Realtime Database** - Dados de usuarios, chats, vagas e profissionais
- **Authentication** - Login com email/senha
- **Storage** - Upload de imagens e videos
- **Cloud Functions** - Funcoes serverless (Node.js)
- **Cloud Messaging** - Notificacoes push
