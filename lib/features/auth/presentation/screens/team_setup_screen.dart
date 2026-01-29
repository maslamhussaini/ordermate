import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';

class TeamSetupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> onboardingData;

  const TeamSetupScreen({super.key, required this.onboardingData});

  @override
  ConsumerState<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends ConsumerState<TeamSetupScreen> {
  final List<Map<String, String>> _teamMembers = [];
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'Staff';
  bool _isLoading = false;

  void _addMember() {
    if (_nameController.text.isEmpty) return;
    
    setState(() {
      _teamMembers.add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
      });
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
    });
  }

  void _removeMember(int index) {
    setState(() {
      _teamMembers.removeAt(index);
    });
  }

  Future<void> _finish() async {
    setState(() => _isLoading = true);

    try {
      final orgId = widget.onboardingData['orgId'];
      final storeId = widget.onboardingData['storeId'];

      // Save team members to database if any
      for (var member in _teamMembers) {
        // Here we would typically call a repository to create these employees
        // For now, let's just insert into omtbl_businesspartners (is_employee = true)
        await SupabaseConfig.client.from('omtbl_businesspartners').insert({
          'name': member['name'],
          'email': member['email']!.isEmpty ? null : member['email'],
          'phone': member['phone']!,
          'is_employee': true,
          'organization_id': orgId,
          'store_id': storeId,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('All Set!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            content: const Text('Your account and team configuration is complete.', style: TextStyle(color: Colors.black87)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.go('/login');
                },
                child: const Text('Get Started', style: TextStyle(color: AppColors.loginGradientStart, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Team Setup',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.loginGradientStart, AppColors.loginGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const StepIndicator(
                currentStep: 3,
                totalSteps: 4,
                stepLabels: ['Account', 'Organization', 'Branch', 'Team'],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const Icon(Icons.group_add_outlined, size: 60, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Invite Your Team',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add staff members to help manage your business',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Add Member Form
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            _buildTextField(controller: _nameController, hint: 'Full Name', icon: Icons.person),
                            const SizedBox(height: 12),
                            _buildTextField(controller: _emailController, hint: 'Email Address', icon: Icons.email),
                            const SizedBox(height: 12),
                            _buildTextField(controller: _phoneController, hint: 'Phone Number', icon: Icons.phone),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedRole,
                                        isExpanded: true,
                                        items: ['Staff', 'Manager', 'Admin'].map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value, style: const TextStyle(color: Colors.black)),
                                          );
                                        }).toList(),
                                        onChanged: (val) => setState(() => _selectedRole = val!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _addMember,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.loginGradientStart,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Team List
                      if (_teamMembers.isNotEmpty) ...[
                        const Text(
                          'Team Members',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_teamMembers.length, (index) {
                          final member = _teamMembers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.loginGradientStart,
                                child: Text(member['name']![0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(member['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${member['role']} • ${member['phone']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeMember(index),
                              ),
                            ),
                          );
                        }),
                      ],
                      
                      const SizedBox(height: 40),
                      
                      _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : ElevatedButton(
                            onPressed: _finish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.loginGradientStart,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              _teamMembers.isEmpty ? 'Skip & Finish' : 'Complete Setup',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.loginGradientStart, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(color: Colors.black, fontSize: 14),
      ),
    );
  }
}
