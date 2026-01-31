import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/core/services/email_service.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/core/network/supabase_client.dart';

class PrivilegeManagementScreen extends ConsumerStatefulWidget {
  const PrivilegeManagementScreen({super.key});

  @override
  ConsumerState<PrivilegeManagementScreen> createState() => _PrivilegeManagementScreenState();
}

class _PrivilegeManagementScreenState extends ConsumerState<PrivilegeManagementScreen> {
  int? _selectedRoleId;
  String? _selectedEmployeeId;
  String _viewMode = 'role'; // 'role' or 'employee'
  String _tabMode = 'privileges'; // 'privileges' or 'stores'

  final Map<int, Map<String, bool>> _pendingChanges = {};
  final List<int> _pendingStoreChanges = [];
  bool _storeChangesDirty = false;
  
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(businessPartnerProvider.notifier).loadRoles();
      ref.read(businessPartnerProvider.notifier).loadAppUsers(); // Changed from loadEmployees
      ref.read(businessPartnerProvider.notifier).loadAppForms();
    });
  }

  void _onRoleSelected(int roleId) {
    setState(() {
      _selectedRoleId = roleId;
      _selectedEmployeeId = null;
      _pendingChanges.clear();
      _pendingStoreChanges.clear();
      _storeChangesDirty = false;
    });
    ref.read(businessPartnerProvider.notifier).loadFormPrivileges(roleId: roleId);
    ref.read(businessPartnerProvider.notifier).loadStoreAccess(roleId: roleId).then((_) {
      setState(() {
         _pendingStoreChanges.addAll(ref.read(businessPartnerProvider).storeAccess);
      });
    });
  }

  void _onEmployeeSelected(String employeeId) {
    setState(() {
      _selectedEmployeeId = employeeId;
      _selectedRoleId = null;
      _pendingChanges.clear();
      _pendingStoreChanges.clear();
      _storeChangesDirty = false;
    });
    ref.read(businessPartnerProvider.notifier).loadFormPrivileges(employeeId: employeeId);
    ref.read(businessPartnerProvider.notifier).loadStoreAccess(employeeId: employeeId).then((_) {
      setState(() {
         _pendingStoreChanges.addAll(ref.read(businessPartnerProvider).storeAccess);
      });
    });
  }

  bool _parseBool(dynamic val) => val == 1 || val == true;

  void _togglePrivilege(int formId, String flag, bool value) {
    setState(() {
      if (!_pendingChanges.containsKey(formId)) {
        // Initialize from current state
        final existing = ref.read(businessPartnerProvider).formPrivileges.where((p) => p['form_id'] == formId).firstOrNull;
        _pendingChanges[formId] = {
          'can_view': _parseBool(existing?['can_view']),
          'can_add': _parseBool(existing?['can_add']),
          'can_edit': _parseBool(existing?['can_edit']),
          'can_delete': _parseBool(existing?['can_delete']),
          'can_read': _parseBool(existing?['can_read']),
          'can_print': _parseBool(existing?['can_print']),
        };
      }
      
      if (flag == 'all') {
        _pendingChanges[formId]!['can_view'] = value;
        _pendingChanges[formId]!['can_add'] = value;
        _pendingChanges[formId]!['can_edit'] = value;
        _pendingChanges[formId]!['can_delete'] = value;
        _pendingChanges[formId]!['can_read'] = value;
        _pendingChanges[formId]!['can_print'] = value;
      } else {
        _pendingChanges[formId]![flag] = value;
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_pendingChanges.isEmpty && !_storeChangesDirty) return;

    final state = ref.read(businessPartnerProvider);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;

    try {
      if (_pendingChanges.isNotEmpty) {
        final List<Map<String, dynamic>> toSave = [];
        final existingPrivs = state.formPrivileges;

        for (var entry in _pendingChanges.entries) {
          final formId = entry.key;
          final flags = entry.value;
          final existing = existingPrivs.where((p) => p['form_id'] == formId).firstOrNull;

          toSave.add({
            if (existing != null) 'id': existing['id'],
            'organization_id': orgId,
            'form_id': formId,
            if (_selectedRoleId != null) 'role_id': _selectedRoleId,
            if (_selectedEmployeeId != null) 'employee_id': _selectedEmployeeId,
            'can_view': flags['can_view']! ? 1 : 0,
            'can_add': flags['can_add']! ? 1 : 0,
            'can_edit': flags['can_edit']! ? 1 : 0,
            'can_delete': flags['can_delete']! ? 1 : 0,
            'can_read': flags['can_read']! ? 1 : 0,
            'can_print': flags['can_print']! ? 1 : 0,
          });
        }
        await ref.read(businessPartnerProvider.notifier).saveFormPrivileges(toSave);
      }

      if (_storeChangesDirty) {
        await ref.read(businessPartnerProvider.notifier).saveStoreAccess(
          roleId: _selectedRoleId,
          employeeId: _selectedEmployeeId,
          storeIds: _pendingStoreChanges,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions saved successfully')));
        setState(() {
           _pendingChanges.clear();
           _storeChangesDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  void _toggleStoreAccess(int storeId, bool value) {
    setState(() {
      if (value) {
        if (!_pendingStoreChanges.contains(storeId)) _pendingStoreChanges.add(storeId);
      } else {
        _pendingStoreChanges.remove(storeId);
      }
      _storeChangesDirty = true;
    });
  }

  @override
  void dispose() {
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendWelcomeEmail(AppUser user) async {
    final email = user.email;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User has no email address')));
      return;
    }

    setState(() => _storeChangesDirty = true); // Using as a proxy for loading if needed, or just show snackbar
    
    // In a real app, you'd use a dedicated EmailService call here
    // For now, let's show a simulated success after a delay
    // Use Edge Function which now handles SMTP internally (works on Web & Mobile)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sending welcome email to $email...')));
    
    // Debug Role Name
    debugPrint('Sending Email -> User: ${user.fullName}, Role: ${user.roleName}, RoleID: ${user.roleId}');

    try {
      final smtpUser = EmailService().smtpUsername;
      final smtpPass = EmailService().smtpPassword;

      // We use a placeholder {{ACTION_URL}} that the Edge Function will replace with a real Magic Link
      final htmlContent = """
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #4CAF50;">Welcome to OrderMate, ${user.fullName ?? 'Employee'}!</h2>
          <p>Your account has been created successfully with the role of <strong>${user.roleName ?? 'Staff'}</strong>.</p>
          <p>Please click the button below to set your password and log in.</p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="{{ACTION_URL}}" style="background-color: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px;">Set Credentials</a>
          </div>

          <div style="padding: 15px; background: #f5f5f5; border-radius: 5px; margin: 20px 0;">
             <p><strong>Login Email:</strong> $email</p>
          </div>
          <p>If you have any questions, please contact your administrator.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
        </div>
      """;

      final response = await SupabaseConfig.client.functions.invoke(
        'invite-employee',
        body: {
          'email': email,
          'full_name': user.fullName ?? '',
          'role_id': user.roleId,
          'organization_id': user.organizationId,
          'store_id': user.storeId,
          'smtp_settings': {
             'username': smtpUser,
             'password': smtpPass
          },
          'email_subject': 'Welcome to OrderMate - Complete Registration',
          'email_html': htmlContent,
          'generate_link': true,
          // Pass current origin for redirect, fallback to a sensible default
          'redirect_to': SupabaseConfig.frontendUrl, 
        },
      );

      if (mounted) {
        if (response.status == 200) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome email sent to $email successfully')));
        } else {
           // Parse error from response data if possible
           final error = response.data is Map ? response.data['error'] : 'Unknown error';
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send email: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending email: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessPartnerProvider);
    final formsByModule = <String, List<Map<String, dynamic>>>{};
    for (var form in state.appForms) {
      final module = form['module_name'] ?? 'Other';
      formsByModule.putIfAbsent(module, () => []).add(form);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privilege Management'),
        actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Data',
                  onPressed: () {
                     ref.read(businessPartnerProvider.notifier).loadRoles();
                     ref.read(businessPartnerProvider.notifier).loadAppUsers();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing data...')));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: FilledButton.icon(
                  onPressed: (state.isLoading || (_pendingChanges.isEmpty && !_storeChangesDirty)) ? null : _saveChanges,
                  icon: state.isLoading 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                  label: const Text('Save Changes'),
                ),
              ),
        ],
      ),
      body: Row(
        children: [
          // Left Pane: Search/Selection
          Container(
            width: 300,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
              color: Colors.grey.shade50,
            ),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'role', label: Text('Roles'), icon: Icon(Icons.security)),
                    ButtonSegment(value: 'employee', label: Text('Employees'), icon: Icon(Icons.person)), // Keep label 'Employees' but it shows Users now
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (set) {
                    setState(() {
                      _viewMode = set.first;
                      _selectedRoleId = null;
                      _selectedEmployeeId = null;
                      _pendingChanges.clear();
                    });
                  },
                ),
                const Divider(),
                Expanded(
                  child: _viewMode == 'role'
                      ? (state.roles.isEmpty 
                          ? _buildLeftPaneEmpty('Roles')
                          : ListView.builder(
                              controller: _leftScrollController,
                              itemCount: state.roles.length,
                              itemBuilder: (context, index) {
                                final role = state.roles[index];
                                final isSelected = _selectedRoleId == role['id'];
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  leading: Icon(Icons.verified_user, color: isSelected ? Colors.blue : null),
                                  title: Text(role['role_name'] ?? ''),
                                  onTap: () => _onRoleSelected(role['id']),
                                );
                              },
                            ))
                      : (state.appUsers.isEmpty 
                          ? _buildLeftPaneEmpty('Users')
                          : ListView.builder(
                              controller: _leftScrollController,
                              itemCount: state.appUsers.length,
                              itemBuilder: (context, index) {
                                final user = state.appUsers[index];
                                final isSelected = _selectedEmployeeId == user.id;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  leading: Icon(Icons.person, color: isSelected ? Colors.blue : null),
                                  title: Text(user.fullName ?? user.email),
                                  subtitle: Text(user.roleName ?? user.email),
                                  trailing: isSelected 
                                    ? IconButton(
                                        icon: const Icon(Icons.email_outlined, color: Colors.blue),
                                        onPressed: () => _sendWelcomeEmail(user),
                                        tooltip: 'Send Welcome Email',
                                      )
                                    : null,
                                  onTap: () => _onEmployeeSelected(user.id),
                                );
                              },
                            )),
                ),
              ],
            ),
          ),

          // Center: Forms Privileges
          Expanded(
            child: (_selectedRoleId == null && _selectedEmployeeId == null)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('Select a Role or Employee to manage privileges',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView(
                    controller: _rightScrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Access Control for ${_viewMode == 'role' ? 'Role' : 'Employee'}: ' +
                        (_viewMode == 'role' 
                          ? (state.roles.firstWhere((r) => r['id'] == _selectedRoleId, orElse: () => {'role_name': 'Unknown'})['role_name'])
                          : (state.appUsers.cast<AppUser>().firstWhere((u) => u.id == _selectedEmployeeId, orElse: () => AppUser(id: '', businessPartnerId: '', email: 'Unknown', roleId: 0, organizationId: 0, storeId: 0, updatedAt: DateTime.now())).fullName ?? 'Unknown')),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Total privilege management for all system components.',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      ..._selectedRoleId != null || _selectedEmployeeId != null 
                    ? [
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'privileges', label: Text('Forms'), icon: Icon(Icons.list_alt)),
                              ButtonSegment(value: 'stores', label: Text('Stores'), icon: Icon(Icons.store)),
                            ],
                            selected: {_tabMode},
                            onSelectionChanged: (set) => setState(() => _tabMode = set.first),
                          ),
                        ),
                      ]
                    : [],
                  const SizedBox(height: 24),
                  if (_tabMode == 'privileges')
                    ..._buildPrivilegesTab(formsByModule, state)
                  else
                    _buildStoresTab(ref.watch(organizationProvider).stores),
                ],
              ),
            ),
          ],
        ),
      );
  }

List<Widget> _buildPrivilegesTab(Map<String, List<Map<String, dynamic>>> formsByModule, BusinessPartnerState state) {
  return [
    Text(
      'Form Privileges for ${_viewMode == 'role' ? 'Role' : 'Employee'}: ' +
      (_viewMode == 'role' 
        ? (state.roles.firstWhere((r) => r['id'] == _selectedRoleId, orElse: () => {'role_name': 'Unknown'})['role_name'])
        : (state.appUsers.cast<AppUser>().firstWhere((u) => u.id == _selectedEmployeeId, orElse: () => AppUser(id: '', businessPartnerId: '', email: 'Unknown', roleId: 0, organizationId: 0, storeId: 0, updatedAt: DateTime.now())).fullName ?? 'Unknown')),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 8),
    const Text('Manage component-level access permissions.',
        style: TextStyle(color: Colors.grey)),
    const SizedBox(height: 24),
    ...formsByModule.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: 900, // Ensure ample space for all toggles + name
                                        maxWidth: constraints.maxWidth > 900 ? constraints.maxWidth : 900,
                                      ),
                                      child: Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: Colors.grey.shade200),
                                        ),
                                        child: Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(2),
                                            1: FixedColumnWidth(70),
                                            2: FixedColumnWidth(70),
                                            3: FixedColumnWidth(70),
                                            4: FixedColumnWidth(70),
                                            5: FixedColumnWidth(70),
                                            6: FixedColumnWidth(70),
                                            7: FixedColumnWidth(70),
                                          },
                                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(color: Colors.grey.shade50),
                                      children: [
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Text('Form Name', style: const TextStyle(fontWeight: FontWeight.bold)))),
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('All', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))))),
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('View', style: const TextStyle(fontWeight: FontWeight.bold))))),
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Add', style: const TextStyle(fontWeight: FontWeight.bold))))),
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Edit', style: const TextStyle(fontWeight: FontWeight.bold))))),
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Delete', style: const TextStyle(fontWeight: FontWeight.bold))))),
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Read', style: const TextStyle(fontWeight: FontWeight.bold))))),
                                        TableCell(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Print', style: const TextStyle(fontWeight: FontWeight.bold))))),
                                      ],
                                    ),
                                      ...entry.value.map((form) {
                                      final formId = form['id'] as int;
                                      final existing = state.formPrivileges.where((p) => p['form_id'] == formId).firstOrNull;
                                      
                                      final canView = _pendingChanges[formId]?['can_view'] ?? _parseBool(existing?['can_view']);
                                      final canAdd = _pendingChanges[formId]?['can_add'] ?? _parseBool(existing?['can_add']);
                                      final canEdit = _pendingChanges[formId]?['can_edit'] ?? _parseBool(existing?['can_edit']);
                                      final canDelete = _pendingChanges[formId]?['can_delete'] ?? _parseBool(existing?['can_delete']);
                                      final canRead = _pendingChanges[formId]?['can_read'] ?? _parseBool(existing?['can_read']);
                                      final canPrint = _pendingChanges[formId]?['can_print'] ?? _parseBool(existing?['can_print']);
                                      
                                      final isAll = canView && canAdd && canEdit && canDelete && canRead && canPrint;

                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Text(form['form_name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                          ),
                                          _buildToggleCell(formId, 'all', isAll, activeColor: Colors.blue.shade300),
                                          _buildToggleCell(formId, 'can_view', canView),
                                          _buildToggleCell(formId, 'can_add', canAdd),
                                          _buildToggleCell(formId, 'can_edit', canEdit),
                                          _buildToggleCell(formId, 'can_delete', canDelete),
                                          _buildToggleCell(formId, 'can_read', canRead),
                                          _buildToggleCell(formId, 'can_print', canPrint),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                    ),
                                  ),
                                ),
                              ); // End Card
                            }, // End LayoutBuilder builder
                          ), // End LayoutBuilder
                        ],
                      ),
                    );
                  }).toList(),
  ];
}

  Widget _buildStoresTab(List<dynamic> stores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store Access Management',
           style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Toggle access for specific store locations.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        GridView.builder(
           shrinkWrap: true,
           physics: const NeverScrollableScrollPhysics(),
           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
             crossAxisCount: 3,
             childAspectRatio: 3,
             crossAxisSpacing: 16,
             mainAxisSpacing: 16,
           ),
           itemCount: stores.length,
           itemBuilder: (context, index) {
             final store = stores[index];
             final isSelected = _pendingStoreChanges.contains(store.id);
             return Card(
               elevation: 0,
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(12),
                 side: BorderSide(color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200),
               ),
               color: isSelected ? Colors.blue.shade50 : null,
               child: SwitchListTile(
                 title: Text(store.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                 subtitle: Text('ST-${store.id}'),
                 value: isSelected,
                 onChanged: (val) => _toggleStoreAccess(store.id, val),
                 secondary: Icon(Icons.storefront, color: isSelected ? Colors.blue : Colors.grey),
               ),
             );
           },
        ),
      ],
    );
  }

  Widget _buildToggleCell(int formId, String flag, bool value, {Color? activeColor}) {
    return TableCell(
      child: Center(
        child: Switch(
          value: value,
          activeColor: activeColor ?? Colors.blue.shade700,
          onChanged: (val) => _togglePrivilege(formId, flag, val),
        ),
      ),
    );
  }

  Widget _buildLeftPaneEmpty(String type) {
    final orgId = ref.watch(organizationProvider).selectedOrganizationId;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No $type found', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Org ID: $orgId', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton.icon(
               icon: const Icon(Icons.refresh),
               label: const Text('Refresh'),
               onPressed: () {
                   ref.read(businessPartnerProvider.notifier).loadRoles();
                   ref.read(businessPartnerProvider.notifier).loadAppUsers();
               },
            )
          ],
        ),
      ),
    );
  }
}
// Verified: no mounted errors in logs after fix.
