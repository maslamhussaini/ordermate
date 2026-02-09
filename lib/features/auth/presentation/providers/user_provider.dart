import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/auth/domain/entities/user.dart';

final userProfileProvider = FutureProvider<User?>((ref) async {
  // Watching authProvider ensures this refreshes on login/logout
  final authState = ref.watch(authProvider);
  if (!authState.isLoggedIn) return null;

  final sessionUser = SupabaseConfig.client.auth.currentUser;
  final userId = sessionUser?.id;
  if (userId == null) return null;

  try {
    final response = await SupabaseConfig.client
        .from('omtbl_users')
        .select()
        .or('id.eq.$userId,auth_id.eq.$userId,email.eq.${sessionUser!.email!}')
        .maybeSingle();

    if (response == null) return null;
    final data = response;
    var user = User(
      id: data['id'] as String,
      email: data['email'] as String,
      fullName: (data['full_name'] as String?) ??
          (sessionUser.userMetadata?['full_name'] as String?) ??
          '',
      phone: data['phone'] as String?,
      role: (data['role'] as String?) ?? 'employee',
      lastLatitude: (data['last_latitude'] as num?)?.toDouble(),
      lastLongitude: (data['last_longitude'] as num?)?.toDouble(),
      lastLocationUpdatedAt: data['last_location_updated_at'] != null
          ? DateTime.parse(data['last_location_updated_at'] as String)
          : null,
      isActive: (data['is_active'] as bool?) ?? true,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      organizationId: data['organization_id'] as int?,
      storeId: data['store_id'] as int?,
      roleId: data['role_id'] as int?,
      businessPartnerId: data['business_partner_id'] as String?,
    );

    // Auto-link Business Partner if missing but email matches
    if (user.businessPartnerId == null && user.email.isNotEmpty) {
      try {
        final partnerResponse = await SupabaseConfig.client
            .from('omtbl_businesspartners')
            .select('id')
            .eq('email', user.email)
            .maybeSingle();

        if (partnerResponse != null) {
          final bpId = partnerResponse['id'] as String;
          user = user.copyWith(businessPartnerId: bpId);

          // Optionally update the user record in Supabase to persist the link
          unawaited(SupabaseConfig.client
              .from('omtbl_users')
              .update({'business_partner_id': bpId}).eq('id', user.id));

          debugPrint(
              'Auto-linked user ${user.email} to Business Partner $bpId');
        }
      } catch (e) {
        debugPrint('Failed to auto-link BP: $e');
      }
    }

    // Cache locally
    try {
      final db = await DatabaseHelper.instance.database;
      final existing =
          await db.query('local_users', where: 'id = ?', whereArgs: [user.id]);
      if (existing.isNotEmpty) {
        await db.update(
            'local_users',
            {
              'full_name': user.fullName,
              'role': user.role,
              'business_partner_id': user.businessPartnerId
            },
            where: 'id = ?',
            whereArgs: [user.id]);
      } else {
        await db.insert('local_users', {
          'email': user.email,
          'id': user.id,
          'full_name': user.fullName,
          'role': user.role,
          'business_partner_id': user.businessPartnerId
        });
      }
    } catch (_) {}

    return user;
  } catch (e) {
    // Fallback 1: Local Database
    try {
      final db = await DatabaseHelper.instance.database;
      final maps =
          await db.query('local_users', where: 'id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        final data = maps.first;
        return User(
          id: data['id']! as String,
          email: data['email']! as String,
          fullName: (data['full_name'] as String?) ?? '',
          role: (data['role'] as String?) ?? 'employee',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch (_) {}

    // Fallback 2: Supabase Session Data (Last Resort)
    return User(
      id: userId,
      email: sessionUser?.email ?? 'Unknown',
      fullName: (sessionUser?.userMetadata?['full_name'] as String?) ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
});
