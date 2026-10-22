import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/config/truck_setup_screen.dart';
import 'package:gps_camioneiro_pro/views/map/map_screen.dart';
import 'package:gps_camioneiro_pro/views/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Na tela de login a musica de entrada continua tocando.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<AudioProvider>().tocarMusica();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          tooltip: 'Voltar',
          onPressed: _voltar,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping, size: 80, color: kEmergencyRed),
              const SizedBox(height: 12),
              Text(
                'GPS Caminhoneiro Pro',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Entrar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await auth.login(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                    if (!mounted) return;
                    if (ok) {
                      _abrirApp(auth, navigator);
                    } else if (auth.requiresVerification) {
                      await _verificarEmail(
                          auth.pendingEmail ?? _emailController.text.trim());
                    } else if (auth.error != null) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(auth.error!)),
                      );
                    }
                  },
                  child: const Text('ENTRAR'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _recuperarSenha,
                  child: const Text(
                    'Esqueci minha senha',
                    style: TextStyle(color: kLightText),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _abrirCadastro,
                child: const Text('Criar conta',
                    style: TextStyle(color: kLightText)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _cancelar,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kLightText),
                    foregroundColor: kLightText,
                  ),
                  child: const Text('CANCELAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ajudante entra direto no mapa: nao configura caminhao nem monta rota.
  void _abrirApp(AuthProvider auth, NavigatorState navigator) {
    final settings = context.read<SettingsProvider>();
    // Primeira vez: configuracao unica do perfil (motorista ou ajudante).
    if (!settings.perfilPronto) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }
    final driver = auth.driver;
    final isAjudante = driver?.role == 'ajudante';
    if (isAjudante && driver != null) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => MapScreen(
            driverId: driver.driverId,
            driverName: driver.name ?? 'Ajudante',
          ),
        ),
      );
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const TruckSetupScreen()),
    );
  }

  void _voltar() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  void _cancelar() {
    _emailController.clear();
    _passwordController.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login cancelado.')),
    );
  }

  Future<void> _abrirCadastro() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var role = 'motorista';
    String helpType = AppConstants.helperTypes.first;
    String icon = AppConstants.truckIcons.first;
    var helperIcon = AppConstants.helperIcons.first;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Criar conta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'motorista',
                      label: Text('Motorista'),
                      icon: Icon(Icons.local_shipping, size: 16),
                    ),
                    ButtonSegment(
                      value: 'ajudante',
                      label: Text('Ajudante'),
                      icon: Icon(Icons.handshake, size: 16),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (v) => setState(() => role = v.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
                if (role == 'ajudante') ...[
                  DropdownButtonFormField<String>(
                    initialValue: helpType,
                    items: AppConstants.helperTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => helpType = v ?? helpType),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: AppConstants.helperIcons.map((e) {
                        final selected = e == helperIcon;
                        return GestureDetector(
                          onTap: () => setState(() => helperIcon = e),
                          child: Container(
                            width: 48,
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? kEmergencyRed.withValues(alpha: 0.25)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    selected ? kEmergencyRed : Colors.white24,
                              ),
                            ),
                            child:
                                Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: role == 'ajudante'
                        ? 'Nome do ajudante'
                        : 'Nome do motorista',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('CADASTRAR'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe e-mail e senha para cadastrar.')),
      );
      return;
    }

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.register(
      email: emailController.text.trim(),
      password: passwordController.text,
      name: nameController.text.trim(),
      role: role,
      helpType: role == 'ajudante' ? helpType : null,
      truckIcon: role == 'ajudante' ? helperIcon : icon,
    );

    if (ok) {
      if (auth.requiresVerification) {
        if (!mounted) return;
        await _verificarEmail(emailController.text.trim());
      } else {
        _abrirApp(auth, navigator);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Não foi possível cadastrar.')),
      );
    }
  }

  /// Fluxo de recuperacao de senha: e-mail -> codigo -> nova senha.
  Future<void> _recuperarSenha() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final auth = context.read<AuthProvider>();

    // 1) Pede o e-mail e envia o codigo.
    final emailOk = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe o e-mail cadastrado. Enviaremos um código para '
              'você definir uma nova senha.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                Navigator.pop(dialogContext, false);
                return;
              }
              final sent = await auth.requestPasswordReset(email);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, sent);
            },
            child: const Text('ENVIAR CÓDIGO'),
          ),
        ],
      ),
    );

    if (emailOk != true) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Se o e-mail estiver cadastrado, enviamos o código de recuperação.',
        ),
      ),
    );

    // 2) Pede o codigo e a nova senha.
    final codeController = TextEditingController();
    final senhaController = TextEditingController();
    final senha2Controller = TextEditingController();

    final redefinido = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nova senha'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Digite o código de 6 dígitos enviado por e-mail e a nova senha.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código de recuperação',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nova senha'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: senha2Controller,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Repetir a nova senha'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                final senha = senhaController.text;
                if (code.isEmpty || senha.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Informe o código e a nova senha.'),
                    ),
                  );
                  return;
                }
                if (senha != senha2Controller.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('As senhas não são iguais.'),
                    ),
                  );
                  return;
                }
                if (senha.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('A senha precisa ter ao menos 6 caracteres.'),
                    ),
                  );
                  return;
                }
                final ok = await auth.resetPassword(
                  email: emailController.text.trim(),
                  code: code,
                  newPassword: senha,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, ok);
              },
              child: const Text('SALVAR SENHA'),
            ),
          ],
        ),
      ),
    );

    if (redefinido == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Senha redefinida. Faça login novamente.')),
      );
    }
  }

  Future<void> _verificarEmail(String email) async {
    final codeController = TextEditingController();
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirme seu e-mail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enviamos um código de 6 dígitos para $email. '
              'Ele expira em 10 minutos.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Código de confirmação',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final sent = await auth.resendCode(email);
              if (!dialogContext.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(sent
                      ? 'Novo código enviado para $email.'
                      : 'Não foi possível reenviar o código.'),
                ),
              );
            },
            child: const Text('Reenviar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, codeController.text.trim()),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (action == null || action.isEmpty) return;
    final ok = await auth.verifyCode(email: email, code: action);
    if (!mounted) return;
    if (ok) {
      _abrirApp(auth, navigator);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Código inválido.')),
      );
    }
  }
}
