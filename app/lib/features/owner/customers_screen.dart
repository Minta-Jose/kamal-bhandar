import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/firebase.dart';
import '../../core/data/orders.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  static const _tabs = [UserStatus.pending, UserStatus.approved, UserStatus.blocked, UserStatus.rejected];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customers'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final s in _tabs)
                Tab(text: switch (s) {
                  UserStatus.pending => 'Waiting (${ref.watch(pendingCustomersProvider).value?.length ?? 0})',
                  UserStatus.approved => 'Approved',
                  UserStatus.blocked => 'Blocked',
                  UserStatus.rejected => 'Rejected',
                }),
            ],
          ),
        ),
        body: TabBarView(children: [for (final s in _tabs) _CustomerList(status: s)]),
      ),
    );
  }
}

class _CustomerList extends ConsumerStatefulWidget {
  const _CustomerList({required this.status});
  final UserStatus status;

  @override
  ConsumerState<_CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends ConsumerState<_CustomerList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.status == UserStatus.pending
        ? ref.watch(pendingCustomersProvider)
        : ref.watch(customersProvider(widget.status));
    return AsyncView(
      value: list,
      data: (users) {
        final shown = _query.isEmpty
            ? users
            : users.where((u) => u.fullName.toLowerCase().contains(_query) || u.mobile.contains(_query)).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.status != UserStatus.pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Search name or mobile', prefixIcon: Icon(Icons.search), isDense: true),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            if (shown.isEmpty)
              EmptyState(
                icon: Icons.people_outline,
                title: widget.status == UserStatus.pending ? 'Nobody is waiting' : 'No customers here',
              ),
            for (final u in shown) ...[_CustomerCard(user: u), const SizedBox(height: 10)],
          ],
        );
      },
    );
  }
}

class _CustomerCard extends ConsumerStatefulWidget {
  const _CustomerCard({required this.user});
  final AppUser user;

  @override
  ConsumerState<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends ConsumerState<_CustomerCard> {
  bool _busy = false;

  Future<void> _set(String status, {String reason = ''}) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).setUserStatus(widget.user.uid, status, reason: reason);
      if (mounted) {
        showSnack(context, switch (status) {
          'approved' => '${widget.user.firstName} approved and notified',
          'rejected' => '${widget.user.firstName} rejected',
          _ => '${widget.user.firstName} blocked',
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Reject ${widget.user.firstName}?'),
        content: TextField(
          controller: c,
          maxLength: 200,
          decoration: const InputDecoration(hintText: 'Reason shown to the customer, e.g. "Mobile number does not match"'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason != null) await _set('rejected', reason: reason);
  }

  Future<void> _block() async {
    final ok = await confirm(
      context,
      title: 'Block ${widget.user.firstName}?',
      message: 'They are signed out and cannot see the shop or place orders. You can unblock them later.',
      ok: 'Block',
      cancel: 'Back',
      danger: true,
    );
    if (ok) await _set('blocked');
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(u.fullName, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                IconButton.filledTonal(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: u.mobile)),
                  icon: const Icon(Icons.call),
                  tooltip: 'Call to check',
                ),
              ],
            ),
            Text(u.mobile, style: t.bodyLarge),
            if (u.email != null) Text(u.email!, style: t.bodySmall?.copyWith(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(u.address.oneLine),
            if (u.createdAt != null)
              Text('Signed up ${formatDate(u.createdAt)}', style: t.bodySmall?.copyWith(color: Colors.black54)),
            if (u.rejectReason?.isNotEmpty == true)
              Text('Reason: ${u.rejectReason}', style: t.bodySmall?.copyWith(color: Colors.deepOrange)),
            const SizedBox(height: 12),
            if (_busy)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (u.status != UserStatus.approved)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _set('approved'),
                      icon: const Icon(Icons.check),
                      label: Text(u.status == UserStatus.blocked ? 'Unblock' : 'Approve'),
                    ),
                  if (u.status == UserStatus.pending)
                    OutlinedButton.icon(onPressed: _reject, icon: const Icon(Icons.close), label: const Text('Reject')),
                  if (u.status != UserStatus.blocked)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: _block,
                      icon: const Icon(Icons.block),
                      label: const Text('Block'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
