// lib/features/accounting/presentation/screens/account_type_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class AccountTypeFormScreen extends ConsumerStatefulWidget {
  final int? accountTypeId;
  const AccountTypeFormScreen({super.key, this.accountTypeId});

  @override
  ConsumerState<AccountTypeFormScreen> createState() =>
      _AccountTypeFormScreenState();
}

class _AccountTypeFormScreenState extends ConsumerState<AccountTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nameController;
  bool _isActive = true;
  bool _isSystem = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _nameController = TextEditingController();

    if (widget.accountTypeId != null) {
      final type = ref
          .read(accountingProvider)
          .types
          .firstWhere((t) => t.id == widget.accountTypeId);
      _idController.text = type.id.toString();
      _nameController.text = type.typeName;
      _isActive = type.status;
      _isSystem = type.isSystem;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final orgId = ref.read(organizationProvider).selectedOrganization?.id;
      final type = AccountType(
        id: int.parse(_idController.text),
        typeName: _nameController.text.trim(),
        status: _isActive,
        isSystem: _isSystem,
        organizationId: orgId ?? 0,
      );
      final notifier = ref.read(accountingProvider.notifier);

      if (widget.accountTypeId == null) {
        await notifier.addAccountType(type, organizationId: orgId);
      } else {
        await notifier.updateAccountType(type, organizationId: orgId);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account type saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountTypeId == null
            ? 'Add Account Type'
            : 'Edit Account Type'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'Type ID (Integer)',
                        border: OutlineInputBorder(),
                        helperText: 'e.g. 1, 2, 3...',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: widget.accountTypeId == null,
                      validator: (value) =>
                          (value == null || int.tryParse(value) == null)
                              ? 'Invalid ID'
                              : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Type Name',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Asset, Liability, Income...',
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Is Active'),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    if (widget.accountTypeId == null)
                      SwitchListTile(
                        title: const Text('Is System'),
                        subtitle:
                            const Text('System accounts cannot be deleted'),
                        value: _isSystem,
                        onChanged: (val) => setState(() => _isSystem = val),
                      ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Save Account Type'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
