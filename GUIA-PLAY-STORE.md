# 🏪 GUIA: Publicar na Google Play Store

---

## 1. Criar Conta de Desenvolvedor

1. Acesse [https://play.google.com/console](https://play.google.com/console)
2. Clique em "Registrar-se como desenvolvedor"
3. Pague a taxa única de **US$ 25**
4. Aguarde a aprovação (pode levar até 2 dias)

---

## 2. Preparar o App para Publicação

### 2.1 Gerar APK ou AAB
O Google Play recomenda o formato AAB (Android App Bundle):

```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter
flutter build appbundle --release
```

O arquivo será gerado em:
```
build/app/outputs/bundle/release/app-release.aab
```

Ou se preferir APK:
```powershell
flutter build apk --release --target-platform android-arm64
```

### 2.2 Gerar Chave de Assinatura (Keystore)
Se não tiver uma, crie:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Guarde este arquivo com cuidado! Você precisará dele para futuras atualizações.

### 2.3 Configurar signing no Android
Abra:
```
android/app/build.gradle
```

Adicione a configuração de signing conforme documentação do Flutter.

---

## 3. Criar o Aplicativo no Console

1. No Play Console, clique em **"Criar aplicativo"**
2. Preencha:
   - **Nome do aplicativo**: GPS Caminhoneiro Pro
   - **Idioma padrão**: Português (Brasil)
   - **Tipo**: Aplicativo
   - **Categoria**: Mapas e navegação / Veículos

---

## 4. Configurar a Página da Loja

Prepare os seguintes materiais:

| Item | Especificação |
|------|---------------|
| **Ícone do app** | 512x512 px, PNG, fundo preto/vermelho |
| **Capturas de tela** | Celular: 3-8 imagens, tablet: opcional |
| **Vídeo promocional** | Opcional, YouTube |
| **Descrição curta** | Até 80 caracteres |
| **Descrição completa** | Até 4.000 caracteres |
| **Política de privacidade** | URL obrigatória |
| **Classificação por etar** | Preencha o questionário |

---

## 5. Enviar o Build

1. Vá em **Produção > Versões > Criar versão**
2. Faça upload do arquivo `.aab` ou `.apk`
3. Adicione notas de lançamento
4. Clique em **Revisar**
5. Clique em **Iniciar lançamento para a produção**

---

## 6. Aguardar a Revisão do Google

- Primeira submissão: 3-7 dias
- Atualizações: 24-48 horas
- Você receberá e-mail quando estiver publicado

---

## 📋 Checklist Play Store

- [ ] Conta de desenvolvedor criada (US$ 25)
- [ ] Keystore gerado e guardado com segurança
- [ ] APK/AAB gerado com `flutter build`
- [ ] Nome do app definido
- [ ] Ícone 512x512 criado
- [ ] Capturas de tela do app prontas
- [ ] Descrição curta e completa escritas
- [ ] URL da política de privacidade definida
- [ ] Classificação etária preenchida
- [ ] Build enviado ao Play Console
- [ ] Revisão do Google concluída
- [ ] App publicado na Play Store

---

## 🔗 Links Úteis

- [Play Console](https://play.google.com/console)
- [Documentação de assinatura de apps](https://developer.android.com/studio/publish/app-signing)
- [Políticas do Google Play](https://support.google.com/googleplay/android-developer/answer/9894752)