import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/providers/group_provider.dart';

/// Planilha de grupos (comboios): meus grupos, criar, entrar/sair, membros
/// e o modo estrito (ver só os caminhões dos meus grupos).
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
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xF20E1216),
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
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Grupos de caminhoneiros',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SwitchListTile(
              value: grupos.estrito,
              onChanged: (v) => context.read<GroupProvider>().setEstrito(v),
              activeThumbColor: Colors.redAccent,
              title: const Text('Ver só o que é do meu grupo',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                  'Modo estrito: caminhões, rotas e sinais só de quem está com você',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            const Divider(color: Colors.white12),
            if (grupos.error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(grupos.error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: grupos.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        if (grupos.mine.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Você não está em nenhum grupo. Crie um comboio abaixo ou peça para entrar em um grupo público.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        for (final g in grupos.mine)
                          ExpansionTile(
                            iconColor: Colors.redAccent,
                            collapsedIconColor: Colors.white70,
                            title: Text(g.name,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              g.isOwner
                                  ? 'Você é o dono do grupo'
                                  : (g.isPublic
                                      ? 'Grupo público'
                                      : 'Grupo fechado'),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                            children: [
                              FutureBuilderWrapper(groupId: g.id, auth: authHeaders),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
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
                                          final membros =
                                              gp.membersOf(g.id);
                                          if (context.mounted) {
                                            _abrirChat(context, g, membros);
                                          }
                                        },
                                        icon: const Icon(Icons.forum,
                                            size: 18),
                                        label: const Text('Chat do grupo'),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _sair(context, g.id),
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
                        const Divider(color: Colors.white12),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('GRUPOS PÚBLICOS',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (grupos.public.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Nenhum grupo público disponível.',
                                style: TextStyle(color: Colors.white54)),
                          ),
                        for (final g in grupos.public)
                          if (!grupos.mine.any((x) => x.id == g.id))
                            ListTile(
                              leading: const Icon(Icons.group_add,
                                  color: Colors.redAccent),
                              title: Text(g.name,
                                  style: const TextStyle(color: Colors.white)),
                              trailing: TextButton(
                                onPressed: () => _entrar(context, g.id),
                                child: const Text('ENTRAR',
                                    style:
                                        TextStyle(color: Colors.redAccent)),
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
    );
  }

  void _sair(BuildContext context, String groupId) async {
    final gp = context.read<GroupProvider>();
    await gp.leave(
        groupId: groupId, driverId: driverId, auth: authHeaders);
  }

  void _entrar(BuildContext context, String groupId) {
    final gp = context.read<GroupProvider>();
    gp.join(groupId: groupId, driverId: driverId, auth: authHeaders);
  }

  void _abrirChat(BuildContext context, ConvoyGroup g, List<GroupMember> membs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xF20E1216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chat privado do ${g.name}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'O chat privado do grupo chega junto com o próximo lote do backend (só quem está no grupo lê e escreve).',
                style: TextStyle(color: Colors.white70),
              ),
              for (final m in membs)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${m.truckIcon} ${m.name}',
                      style: const TextStyle(color: Colors.white54)),
                ),
            ],
          ),
        ),
      ),
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
          child: Text('Ninguém no grupo ainda.',
              style: TextStyle(color: Colors.white54)),
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
                backgroundColor: const Color(0xFF1C0303),
                label: Text(m.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CriarGrupo extends StatelessWidget {
  final String driverId;
  final Map<String, String> auth;

  const _CriarGrupo({required this.driverId, required this.auth});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Column(
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nome do seu comboio (ex.: Rota SP→Rio)',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1C0303),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFA80000)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final gp = context.read<GroupProvider>();
              gp.create(
                  name: controller.text.trim(),
                  driverId: driverId,
                  auth: auth);
            },
            icon: const Icon(Icons.flag, size: 18),
            label: const Text('CRIAR GRUPO (COMBOIO)'),
          ),
        ),
      ],
    );
  }
}
