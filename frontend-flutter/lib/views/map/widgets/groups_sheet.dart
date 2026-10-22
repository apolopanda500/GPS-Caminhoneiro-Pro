import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/providers/group_provider.dart';

/// Planilha de grupos (comboios): meus grupos, criar, entrar/sair, membros
/// e o modo estrito (ver só os caminhões dos meus grupos).
/// Todas as cores derivam do tema para acompanhar a cor escolhida.
class GroupsSheet extends StatelessWidget {
  final String driverId;
  final Map<String, String> authHeaders;

  const GroupsSheet({
    super.key,
    required this.driverId,
    required this.authHeaders,
  });

  static Future<void> show(
    BuildContext context, {
    required String driverId,
    required Map<String, String> authHeaders,
  }) {
    context.read<GroupProvider>().load(driverId: driverId, auth: authHeaders);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GroupsSheet(
        driverId: driverId,
        authHeaders: authHeaders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = context.watch<GroupProvider>();
    final tema = Theme.of(context);
    final media = MediaQuery.of(context);
    final altura = (media.size.height - media.viewInsets.bottom) * 0.78;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: altura,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Grupos de caminhoneiros', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              value: grupos.estrito,
              onChanged: (v) => context.read<GroupProvider>().setEstrito(v),
              title: const Text('Ver só o que é do meu grupo'),
              subtitle: const Text(
                  'Modo estrito: caminhões, rotas e sinais só de quem está com você',
                  style: TextStyle(fontSize: 12)),
            ),
            const Divider(),
            if (grupos.error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(grupos.error!,
                    style:
                        TextStyle(color: tema.colorScheme.error, fontSize: 13)),
              ),
            Expanded(
              child: grupos.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        if (grupos.mine.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Você não está em nenhum grupo. Crie um comboio abaixo ou entre em um grupo público.',
                              style: tema.textTheme.bodyMedium,
                            ),
                          ),
                        for (final g in grupos.mine)
                          Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ExpansionTile(
                              title: Text(g.name),
                              subtitle: Text(
                                g.isOwner
                                    ? 'Você é o dono do grupo'
                                    : (g.isPublic
                                        ? 'Grupo público'
                                        : 'Grupo fechado'),
                                style: const TextStyle(fontSize: 12),
                              ),
                              children: [
                                FutureBuilderWrapper(
                                    groupId: g.id, auth: authHeaders),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () async {
                                            final gp =
                                                context.read<GroupProvider>();
                                            await gp.loadMembers(
                                                groupId: g.id,
                                                auth: authHeaders);
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              _abrirChat(context, g,
                                                  gp.membersOf(g.id));
                                            }
                                          },
                                          icon:
                                              const Icon(Icons.forum, size: 18),
                                          label: const Text('Chat do grupo'),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () => _sair(context, g.id),
                                          icon: const Icon(Icons.logout,
                                              size: 18),
                                          label: const Text('Sair do grupo'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('GRUPOS PÚBLICOS',
                              style: tema.textTheme.labelSmall),
                        ),
                        if (grupos.public.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('Nenhum grupo público disponível.',
                                style: tema.textTheme.bodySmall),
                          ),
                        for (final g in grupos.public)
                          if (!grupos.mine.any((x) => x.id == g.id))
                            ListTile(
                              leading: const Icon(Icons.group_add),
                              title: Text(g.name),
                              trailing: TextButton(
                                onPressed: () => _entrar(context, g.id),
                                child: const Text('ENTRAR'),
                              ),
                            ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _CriarGrupo(
                driverId: driverId,
                auth: authHeaders,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  void _sair(BuildContext context, String groupId) async {
    final gp = context.read<GroupProvider>();
    await gp.leave(groupId: groupId, driverId: driverId, auth: authHeaders);
  }

  void _entrar(BuildContext context, String groupId) {
    final gp = context.read<GroupProvider>();
    gp.join(groupId: groupId, driverId: driverId, auth: authHeaders);
  }

  void _abrirChat(
      BuildContext context, ConvoyGroup g, List<GroupMember> membs) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final tema = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chat privado do ${g.name}',
                    style: tema.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'O chat privado do grupo chega junto com o próximo lote do backend (só quem está no grupo lê e escreve).',
                  style: tema.textTheme.bodyMedium,
                ),
                for (final m in membs)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${m.truckIcon} ${m.name}',
                        style: tema.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Componente que carrega membros do grupo ao expandir (lazy).
class FutureBuilderWrapper extends StatefulWidget {
  final String groupId;
  final Map<String, String> auth;

  const FutureBuilderWrapper({
    super.key,
    required this.groupId,
    required this.auth,
  });

  @override
  State<FutureBuilderWrapper> createState() => _FutureBuilderWrapperState();
}

class _FutureBuilderWrapperState extends State<FutureBuilderWrapper> {
  @override
  void initState() {
    super.initState();
    final gp = context.read<GroupProvider>();
    if (gp.membersOf(widget.groupId).isEmpty) {
      gp.loadMembers(groupId: widget.groupId, auth: widget.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GroupProvider>();
    final membros = gp.membersOf(widget.groupId);
    if (membros.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Ninguém no grupo ainda.'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final m in membros)
              Chip(
                avatar: Text(m.truckIcon),
                label: Text(m.name, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CriarGrupo extends StatefulWidget {
  final String driverId;
  final Map<String, String> auth;

  const _CriarGrupo({required this.driverId, required this.auth});

  @override
  State<_CriarGrupo> createState() => _CriarGrupoState();
}

class _CriarGrupoState extends State<_CriarGrupo> {
  final _controller = TextEditingController();
  bool _criando = false;
  String? _erroLocal;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty || _criando) return;
    setState(() {
      _criando = true;
      _erroLocal = null;
    });
    final ok = await context.read<GroupProvider>().create(
          name: nome,
          driverId: widget.driverId,
          auth: widget.auth,
        );
    if (!mounted) return;
    setState(() {
      _criando = false;
      if (ok) {
        _controller.clear();
      } else {
        _erroLocal =
            'Nao deu para criar o grupo. Confira o nome e tente de novo.';
      }
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Comboio criado! Ele ja aparece na lista.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _criar(),
          decoration: InputDecoration(
            hintText: 'Nome do seu comboio (ex.: Rota SP→Rio)',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: tema.colorScheme.primary),
            ),
          ),
        ),
        if (_erroLocal != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _erroLocal!,
              style: TextStyle(color: tema.colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _criando ? null : _criar,
            icon: _criando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag, size: 18),
            label: Text(_criando ? 'CRIANDO...' : 'CRIAR GRUPO (COMBOIO)'),
          ),
        ),
      ],
    );
  }
}
