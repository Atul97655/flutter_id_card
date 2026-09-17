import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/managed_user.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Admin screen for managing user accounts and operator access control.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  static const String routePath = '/admin/users';

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'All'; // All, Active, Disabled, School, Admin

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ManagedUser> _filterUsers(List<ManagedUser> all) {
    final String query = _search.text.trim().toLowerCase();
    return all.where((ManagedUser u) {
      if (_filter == 'Active' && !u.active) return false;
      if (_filter == 'Disabled' && u.active) return false;
      if (_filter == 'School' && u.role != UserRole.school) return false;
      if (_filter == 'Admin' && u.role != UserRole.admin) return false;

      if (query.isEmpty) return true;
      return u.email.toLowerCase().contains(query) ||
          u.displayName.toLowerCase().contains(query) ||
          (u.schoolId ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ManagedUser>> usersAsync = ref.watch(
      allUsersProvider,
    );
    final AsyncValue<List<SchoolConfig>> schoolsAsync = ref.watch(
      allSchoolsProvider,
    );
    final List<SchoolConfig> schools =
        schoolsAsync.value ?? const <SchoolConfig>[];

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: <Widget>[
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.primary,
            ),
            onPressed: () => _openCreateUserDialog(context, schools),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Add User'),
          ),
          const SizedBox(width: AppTheme.gutter),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateUserDialog(context, schools),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New Account'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              12,
              AppTheme.gutter,
              8,
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by email, name or school...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        <String>['All', 'Active', 'Disabled', 'School', 'Admin']
                            .map(
                              (String f) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(f),
                                  selected: _filter == f,
                                  onSelected: (_) =>
                                      setState(() => _filter = f),
                                  showCheckmark: false,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SmoothSwitcher(
              alignment: Alignment.center,
              child: usersAsync.when(
                loading: () => const Center(
                  key: ValueKey<String>('loading'),
                  child: CircularProgressIndicator(),
                ),
                error: (Object e, StackTrace s) => Center(
                  key: const ValueKey<String>('error'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.gutter),
                    child: Text('Failed to load users: $e'),
                  ),
                ),
                data: (List<ManagedUser> all) {
                  final List<ManagedUser> list = _filterUsers(all);
                  if (list.isEmpty) {
                    return Center(
                      key: const ValueKey<String>('empty'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            all.isEmpty
                                ? 'No user accounts created yet.'
                                : 'No matching users found.',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (all.isEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () =>
                                  _openCreateUserDialog(context, schools),
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Account'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    key: ValueKey<int>(list.length),
                    padding: const EdgeInsets.all(AppTheme.gutter),
                    itemCount: list.length,
                    separatorBuilder: (BuildContext _, int _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext ctx, int i) {
                      final ManagedUser user = list[i];
                      final SchoolConfig? school = schools
                          .where((SchoolConfig s) => s.id == user.schoolId)
                          .firstOrNull;

                      return FadeSlideIn(
                        index: i,
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user.isAdmin
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.secondaryContainer,
                              child: Icon(
                                user.isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.school,
                                color: user.isAdmin
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            title: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    user.displayName.isEmpty
                                        ? user.email
                                        : user.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: user.active
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: user.active
                                          ? Colors.green.shade300
                                          : Colors.red.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    user.active ? 'ACTIVE' : 'DISABLED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: user.active
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (user.role == UserRole.school) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    'School: ${school?.name ?? user.schoolId ?? "None"}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (user.lastLoginDate != null) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Last Login: ${DateFormat.yMMMd().add_jm().format(user.lastLoginDate!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Switch(
                              value: user.active,
                              activeThumbColor: Colors.green,
                              onChanged: (bool nextActive) =>
                                  _toggleActive(user, nextActive),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(ManagedUser user, bool nextActive) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .toggleUserActive(user.uid, nextActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive
                ? 'Enabled access for ${user.displayName.isEmpty ? user.email : user.displayName}'
                : 'Disabled access for ${user.displayName.isEmpty ? user.email : user.displayName}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openCreateUserDialog(
    BuildContext context,
    List<SchoolConfig> schools,
  ) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController identifierCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController passCtrl = TextEditingController();

    UserRole selectedRole = UserRole.school;
    String? selectedSchoolId = schools.firstOrNull?.id;
    bool obscurePass = true;
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Create User Account'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SegmentedButton<UserRole>(
                          segments: const <ButtonSegment<UserRole>>[
                            ButtonSegment<UserRole>(
                              value: UserRole.school,
                              label: Text('School Operator'),
                              icon: Icon(Icons.school_outlined),
                            ),
                            ButtonSegment<UserRole>(
                              value: UserRole.admin,
                              label: Text('Admin'),
                              icon: Icon(Icons.admin_panel_settings_outlined),
                            ),
                          ],
                          selected: <UserRole>{selectedRole},
                          onSelectionChanged: (Set<UserRole> set) {
                            setDialogState(() => selectedRole = set.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: identifierCtrl,
                          decoration: InputDecoration(
                            labelText: selectedRole == UserRole.school
                                ? 'School Code / Login ID'
                                : 'Admin Email',
                            hintText: selectedRole == UserRole.school
                                ? 'e.g. stjohns'
                                : 'e.g. admin@school.edu',
                            prefixIcon: const Icon(
                              Icons.account_circle_outlined,
                            ),
                          ),
                          validator: (String? v) => (v ?? '').trim().isEmpty
                              ? 'This field is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Operator / Display Name',
                            hintText: 'e.g. John Doe / Front Desk',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (selectedRole == UserRole.school) ...<Widget>[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedSchoolId,
                            decoration: const InputDecoration(
                              labelText: 'Assigned School',
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                            items: schools
                                .map(
                                  (SchoolConfig s) => DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) =>
                                setDialogState(() => selectedSchoolId = v),
                            validator: (String? v) =>
                                v == null ? 'Please select a school' : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: passCtrl,
                          obscureText: obscurePass,
                          decoration: InputDecoration(
                            labelText: 'Initial Password',
                            hintText: 'Minimum 6 characters',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePass
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setDialogState(
                                () => obscurePass = !obscurePass,
                              ),
                            ),
                          ),
                          validator: (String? v) {
                            if ((v ?? '').trim().length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => busy = true);

                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .createUserAccount(
                                  email: identifierCtrl.text.trim(),
                                  password: passCtrl.text.trim(),
                                  role: selectedRole,
                                  schoolId: selectedRole == UserRole.school
                                      ? selectedSchoolId
                                      : null,
                                  displayName: nameCtrl.text.trim(),
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'User account created successfully',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => busy = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );

    identifierCtrl.dispose();
    nameCtrl.dispose();
    passCtrl.dispose();
  }
}
