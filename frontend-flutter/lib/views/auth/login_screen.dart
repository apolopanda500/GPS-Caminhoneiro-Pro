import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/views/config/truck_setup_screen.dart';
import 'package:gps_camioneiro_pro/views/map/map_screen.dart';
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
              const Icon(Icons.local_shipping,
                  size: 80, color: kEmergencyRed),
              const SizedBox(height: 12),
              const Text(
                'GPS Caminhoneiro Pro',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entrar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
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
                    final ok = await auth.login(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                    if (ok) {
                      _abrirApp(auth, navigator);
                    } else if (auth.requiresVerification) {
                      if (!mounted) return;
                      await _verificarEmail(
                          auth.pendingEmail ?? _emailController.text.trim());
                    }
                  },
                  child: const Text('ENTRAR'),
                ),
              ),
              const SizedBox(height: 16),
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

  void _voltar() {    final navigator = Navigator.of(context);
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
                              color: selected ? kEmergencyRed : Colors.white24,
                            ),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 22)),
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
                  labelText:
                      role == 'ajudante' ? 'Nome do ajudante' : 'Nome do motorista',
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
