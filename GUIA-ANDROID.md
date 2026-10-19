# 📱 GUIA: Rodar o GPS Caminhoneiro Pro no Android

---

## 1. Instalar Flutter SDK

```powershell
# Baixe em: https://docs.flutter.dev/get-started/install
# Extraia em C:\flutter
# Adicione C:\flutter\bin ao PATH do Windows
flutter doctor
```

---

## 2. Habilitar Depuração USB no Celular

1. Acesse **Configurações > Sobre o telefone**
2. Toque 7 vezes em **"Número da compilação"**
3. Acesse **Configurações > Opções do desenvolvedor**
4. Ative **Depuração USB**
5. Conecte o celular via cabo USB
6. Autorize a depuração quando solicitado

---

## 3. Rodar o App

```powershell
cd C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter
flutter create . --platforms=android --org com.gpscamioneiro --project-name gps_camioneiro_pro
flutter pub get
flutter run
```

O app será instalado automaticamente no celular conectado.

---

## 4. Gerar APK de Release

```powershell
flutter build apk --release --target-platform android-arm64
```

O APK será gerado em:
```
build/app/outputs/flutter-apk/app-release.apk
```

Instale este APK em qualquer celular Android para testar.

---

## 5. Verificar se está funcionando

- [ ] App abre sem erro
- [ ] Tela de login aparece
- [ ] Mapa carrega (OpenStreetMap/Satélite)
- [ ] Botão "Avisar Via" funciona
- [ ] Chat Rádio PX funciona
- [ ] Outro caminhoneiro aparece no mapa (V2X)