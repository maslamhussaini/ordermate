import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/core/network/supabase_client.dart';

class AccountingSeedService {
  static const String _jsonPath = 'assets/json/accounting/default_accounting_data.json';

  Future<void> seedOrganization(int organizationId) async {
    try {
      final jsonString = await rootBundle.loadString(_jsonPath);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      await _seedAccountTypesAndCategories(organizationId, data);
      await _seedChartOfAccounts(organizationId, data);
      await _seedGLSetup(organizationId, data);
      await _seedRolesAndPrivileges(organizationId, data);
      
      debugPrint('Accounting seeding completed for Org ID: $organizationId');
    } catch (e) {
      debugPrint('Error seeding accounting data: $e');
      // Rethrow? Or just log? 
      // User might want to know if import failed.
      throw Exception('Failed to import default accounting data: $e');
    }
  }

  Future<void> _seedAccountTypesAndCategories(int orgId, Map<String, dynamic> data) async {
    final types = List<Map<String, dynamic>>.from(data['account_types']);
    final categories = List<Map<String, dynamic>>.from(data['account_categories']);

    // 1. Insert Account Types
    // We need to map Type Name -> ID for querying later (or just insert and assume ID generation)
    // Supabase insert returns data.
    final typeNameIdMap = <String, int>{};

    for (var type in types) {
      final res = await SupabaseConfig.client
          .from('omtbl_account_types')
          .insert({
            'type_name': type['type_name'],
            'status': type['status'],
            'is_system': true, // Mark as system/default
            'organization_id': orgId,
          })
          .select('id, type_name')
          .single();
      
      typeNameIdMap[res['type_name']] = res['id'];
    }

    // 2. Insert Account Categories
    final categoryNameIdMap = <String, int>{};

    for (var cat in categories) {
      final typeName = cat['type_name'];
      final typeId = typeNameIdMap[typeName];
      
      if (typeId == null) {
        debugPrint('Warning: Account Type "$typeName" not found for category "${cat['category_name']}"');
        continue;
      }

      final res = await SupabaseConfig.client
          .from('omtbl_account_categories')
          .insert({
            'category_name': cat['category_name'],
            'account_type_id': typeId,
            'status': cat['status'],
            'is_system': true,
            'organization_id': orgId,
          })
          .select('id, category_name')
          .single();
      
      categoryNameIdMap[res['category_name']] = res['id'];
    }
  }

  Future<void> _seedChartOfAccounts(int orgId, Map<String, dynamic> data) async {
    final accounts = List<Map<String, dynamic>>.from(data['chart_of_accounts']);
    
    // We need to fetch category IDs first if we didn't pass the map. 
    // Ideally we should cache them, but querying DB is safer for "transactional" integrity across functions.
    // Let's fetch categories for this Org.
    final categoriesRes = await SupabaseConfig.client
        .from('omtbl_account_categories')
        .select('id, category_name')
        .eq('organization_id', orgId);
    
    final categoryMap = {for (var c in categoriesRes) c['category_name'] as String: c['id'] as int};

    // Also need Types for CoA? The model allows null but schema might require it or it is redundant.
    // The JSON for CoA doesn't have type, only category. Category implies type.
    // The model `ChartOfAccountModel` has `accountTypeId` and `accountCategoryId`.
    // We should probably fill both if possible by looking up the category's type.
    
    // Let's get Categories with their Type IDs.
    final categoriesWithTypes = await SupabaseConfig.client
        .from('omtbl_account_categories')
        .select('id, category_name, account_type_id')
        .eq('organization_id', orgId);
        
    final catInfoMap = {for (var c in categoriesWithTypes) c['category_name'] as String: c};

    for (var acc in accounts) {
      final catName = acc['category_name'];
      final catInfo = catInfoMap[catName];
      
      if (catInfo == null) {
        debugPrint('Warning: Category "$catName" not found for account "${acc['account_title']}"');
        continue;
      }

      await SupabaseConfig.client.from('omtbl_chart_of_accounts').insert({
        'account_code': acc['account_code'],
        'account_title': acc['account_title'],
        'account_category_id': catInfo['id'],
        'account_type_id': catInfo['account_type_id'],
        'level': acc['level'],
        'is_system': acc['is_system'] ?? false,
        'organization_id': orgId,
        'is_active': true,
      });
    }
  }

  Future<void> _seedGLSetup(int orgId, Map<String, dynamic> data) async {
    final setup = data['gl_setup'] as Map<String, dynamic>;
    if (setup.isEmpty) return;

    // We need to resolve Account Codes to Account IDs
    final accountsRes = await SupabaseConfig.client
        .from('omtbl_chart_of_accounts')
        .select('id, account_code')
        .eq('organization_id', orgId);
    
    final codeToIdMap = {for (var a in accountsRes) a['account_code'] as String: a['id'] as String}; // IDs are UUIDs (String) in Dart/Supabase?
    // Wait, the model accounting_models.dart says:
    // ChartOfAccountModel id is String.
    // GLSetupModel IDs are Strings.

    String? getId(String key) {
      final code = setup[key];
      if (code == null) return null;
      return codeToIdMap[code];
    }

    // Construct insert map
    // Required fields in GLSetupModel: inventoryAccountId, cogsAccountId, salesAccountId
    // Others are optional.
    
    final insertData = {
      'organization_id': orgId,
      'inventory_account_id': getId('inventory_account_code'),
      'cogs_account_id': getId('cogs_account_code'),
      'sales_account_id': getId('sales_account_code'),
      'receivable_account_id': getId('receivable_account_code'),
      'payable_account_id': getId('payable_account_code'),
      'bank_account_id': getId('bank_account_code'), // Usually not in default JSON, might be user specific
      'cash_account_id': getId('cash_account_code'),
      'tax_output_account_id': getId('tax_output_account_code'),
      'tax_input_account_id': getId('tax_input_account_code'),
      'sales_discount_account_id': getId('sales_discount_account_code'),
      'purchase_discount_account_id': getId('purchase_discount_account_code'),
    };

    // Filter out nulls for required fields? No, allow failures if code mismatch?
    // Actually, create usually requires them.
    // If null, we might have issues.
    
      await SupabaseConfig.client.from('omtbl_gl_setup').insert(insertData);
    }
  }

  Future<void> _seedRolesAndPrivileges(int orgId, Map<String, dynamic> data) async {
    if (!data.containsKey('roles') || !data.containsKey('role_privileges')) {
      return;
    }

    final roles = List<Map<String, dynamic>>.from(data['roles']);
    final privileges = List<Map<String, dynamic>>.from(data['role_privileges']);

    // 1. Fetch Forms Map (Form Name -> Form ID)
    final formsRes = await SupabaseConfig.client
        .from('omtbl_forms')
        .select('id, form_name');
    
    final formNameIdMap = {
      for (var f in formsRes) 
        (f['form_name'] as String).toLowerCase(): f['id'] as int
    };

    // 2. Insert Roles & Collect IDs
    final roleNameIdMap = <String, int>{};

    for (var role in roles) {
      // Check if role exists (e.g. system default) or just insert
      // For a new org, we likely creating fresh roles.
      try {
        final res = await SupabaseConfig.client
            .from('omtbl_roles')
            .insert({
              'role_name': role['role_name'],
              'organization_id': orgId,
              'can_read': true, // Default permissions for the role itself?
              'can_write': true,
              'can_edit': true,
              'can_print': true,
              'status': true,
            })
            .select('id, role_name')
            .single();
        
        roleNameIdMap[res['role_name']] = res['id'];
      } catch (e) {
        debugPrint('Error creating role ${role['role_name']}: $e');
      }
    }

    // 3. Insert Privileges
    final privilegeInserts = <Map<String, dynamic>>[];

    for (var priv in privileges) {
      final roleName = priv['role_name'];
      final roleId = roleNameIdMap[roleName];
      
      if (roleId == null) {
        continue; 
      }

      final formName = priv['form_name'];
      final formId = formNameIdMap[formName.toString().toLowerCase()];

      if (formId == null) {
        debugPrint('Warning: Form "$formName" not found for role "$roleName"');
        continue;
      }

      privilegeInserts.add({
        'organization_id': orgId,
        'role_id': roleId,
        'form_id': formId,
        'can_view': priv['can_view'] == true ? 1 : 0,
        'can_add': priv['can_add'] == true ? 1 : 0,
        'can_edit': priv['can_edit'] == true ? 1 : 0,
        'can_delete': priv['can_delete'] == true ? 1 : 0,
        'can_read': priv['can_read'] == true ? 1 : 0,
        'can_print': priv['can_print'] == true ? 1 : 0,
      });
    }

    if (privilegeInserts.isNotEmpty) {
      // split into batches if too large, but typically small
      await SupabaseConfig.client
          .from('omtbl_role_form_privileges')
          .upsert(privilegeInserts);
    }
  }
}
