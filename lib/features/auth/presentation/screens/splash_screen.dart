import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/build_info.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isLocationDenied = false;
  bool _isCheckingLocation = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Start Check Loop
    _checkLocationAndAuth();
  }

  Future<void> _checkLocationAndAuth() async {
    debugPrint('Splash: Starting checks...');
    await Future.delayed(const Duration(seconds: 3));
    debugPrint('Splash: 3s delay over. Checking location...');
    await _enforceLocationPermission();
  }

  Future<void> _enforceLocationPermission() async {
    if (!mounted) return;
    debugPrint('Splash: Enforcing location permission...');
    
    // Bypass location check in Debug Mode (Web/Windows) to prevent stuck splash
    if (kDebugMode) {
      debugPrint('Splash: Debug mode detected. Bypassing location check.');
      _checkAuth();
      return;
    }

    setState(() => _isCheckingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check Service
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Splash: Location service disabled.');
      if (mounted) {
         setState(() {
           _isLocationDenied = true;
           _isCheckingLocation = false;
         });
         _showLocationDialog('Location services are disabled. Please enable them to continue.');
      }
      return;
    }

    // 2. Check Permission
    permission = await Geolocator.checkPermission();
    debugPrint('Splash: Current permission: $permission');
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('Splash: Requested permission result: $permission');
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLocationDenied = true;
            _isCheckingLocation = false;
          });
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Splash: Permission denied forever.');
      if (mounted) {
          setState(() {
            _isLocationDenied = true;
            _isCheckingLocation = false;
          });
          _showLocationDialog('Location permissions are permanently denied. Please enable them in settings to continue.');
      }
      return;
    }

    // Permission Granted -> Proceed to Auth Check
    debugPrint('Splash: Location granted. Checking auth...');
    _checkAuth();
  }

  void _showLocationDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Required'),
        content: Text(message),
        actions: [
          if (_isLocationDenied)
             TextButton(
               onPressed: () {
                 Navigator.pop(context);
                 _enforceLocationPermission();
               },
               child: const Text('Retry'),
             ),
          if (_isLocationDenied)
             TextButton(
               onPressed: () {
                 Geolocator.openAppSettings();
               },
               child: const Text('Open Settings'),
             ),
        ],
      ),
    );
  }

  Future<void> _checkAuth() async {
    debugPrint('Splash: _checkAuth started.');
    if (mounted) {
      final hasSession = SupabaseConfig.currentUser != null || SupabaseConfig.isOfflineLoggedIn;
      debugPrint('Splash: Has Session? $hasSession');
      
      if (hasSession) {
        debugPrint('Splash: Session detected. Loading profile...');
        
        // Ensure dynamic permissions/role are loaded before navigating
        await ref.read(authProvider.notifier).loadDynamicPermissions();

        debugPrint('Splash: Triggering Sync...');
        ref.read(syncServiceProvider).syncAll();
        
        debugPrint('Splash: Navigating to /workspace-selection');
        context.go('/workspace-selection');
      } else {
        debugPrint('Splash: No session, navigating to /login');
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Stack(
          children: [
            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.transparent, 
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: const Column(
                      children: [
                        SizedBox(height: 16),
                        Text(
                          'Order Mate',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Contrast on dark gradient
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_isLocationDenied && !_isCheckingLocation)
                    Column(
                      children: [
                         const Text(
                          'Location Access Required',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _enforceLocationPermission,
                          child: const Text('Grant Permission'),
                        )
                      ],
                    )
                  else
                    FadeTransition(
                      opacity: _opacityAnimation,
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.loginGradientStart),
                      ),
                    ),
                ],
              ),
            ),
            
            // Footer (Powered By + Version)
            Positioned(
              bottom: 24,
              right: 24,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Powered by ',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,),
                        ),
                        // Triangletech Logo
                        Image.asset(
                          'assets/images/triangletech_logo.jpg',
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $appVersion • $buildTime',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
