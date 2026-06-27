import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/notification_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  bool _isRedeeming = false;
  Uint8List? _profileImageBytes;
  bool _isUploading = false;

  String? _lastUserId;
  bool _fetchedData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _refreshDashboard();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (auth.user?.id != _lastUserId) {
      _lastUserId = auth.user?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserData();
        _refreshDashboard();
      });
    }
  }

  Future<void> _refreshDashboard() async {
    if (_fetchedData) return;
    _fetchedData = true;
    final auth = context.read<AuthProvider>();
    await context.read<DashboardProvider>().fetchDashboardData(userId: auth.user?.id, showLoading: false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, DashboardProvider, ThemeProvider>(
      builder: (context, authProvider, dashProvider, themeProvider, child) {
        if (authProvider.user == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final c = themeProvider.colors;
        final user = authProvider.user!;
        final profile = dashProvider.data?.profile;
        final userRank = profile?.rank?.name ?? (profile != null ? 'Unranked' : 'Rank: Whale');
        return SafeArea(
          child: Column(
            children: [
              _buildHeader(context, user, c),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSection(user, userRank, profile, c),
                        const SizedBox(height: 24),
                        _buildPersonalInfoSection(c),
                        const SizedBox(height: 24),
                        _buildPromoSection(c),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
    );
  }

  Widget _buildHeader(BuildContext context, User user, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border(
          bottom: BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: c.accentBlue, size: 24),
          const SizedBox(width: 12),
          Text(
            'Profile',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(onTap: () => showNotificationSheet(context)),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surfaceBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: c.iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  user.username,
                  style: TextStyle(color: c.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(User user, String userRank, Profile? profile, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          // Profile Picture
          GestureDetector(
            onTap: _isUploading ? null : () => _pickAndUploadImage(),
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: c.surfaceBg,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: c.border),
                    image: _profileImageBytes != null
                        ? DecorationImage(image: MemoryImage(_profileImageBytes!), fit: BoxFit.cover)
                        : (profile?.profilePicture != null
                            ? _profileImageProvider(profile!.profilePicture!)
                            : null),
                  ),
                  child: _profileImageBytes == null && profile?.profilePicture == null
                      ? Icon(Icons.person, size: 50, color: c.iconColor)
                      : null,
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.accentBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Uploading...', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          Text(
            user.username,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userRank,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.accentBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: 'First Name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: c.surfaceBg,
              labelStyle: TextStyle(color: c.textSecondary),
              prefixIconColor: c.iconColor,
            ),
            style: TextStyle(color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'Last Name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: c.surfaceBg,
              labelStyle: TextStyle(color: c.textSecondary),
              prefixIconColor: c.iconColor,
            ),
            style: TextStyle(color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: c.surfaceBg,
              labelStyle: TextStyle(color: c.textSecondary),
              prefixIconColor: c.iconColor,
            ),
            style: TextStyle(color: c.textPrimary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _saveProfile(),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoSection(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined, color: c.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Promo Codes',
                style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _promoCodeController,
            decoration: InputDecoration(
              labelText: 'Enter Promo Code',
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: c.surfaceBg,
              labelStyle: TextStyle(color: c.textSecondary),
              prefixIconColor: c.iconColor,
            ),
            style: TextStyle(color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRedeeming ? null : () => _redeemPromoCode(),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isRedeeming
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Redeem Promo'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.accentBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.telegram, color: c.accentBlue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Promo codes are only available through our Telegram channels. Join us to get exclusive codes.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  DecorationImage? _profileImageProvider(String url) {
    if (url.startsWith('data:image')) {
      final parts = url.split(',');
      if (parts.length < 2) return null;
      try {
        final bytes = base64Decode(parts[1]);
        return DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover);
      } catch (_) {
        return null;
      }
    }
    return DecorationImage(image: NetworkImage(url), fit: BoxFit.cover);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final sizeKb = bytes.length / 1024;
      if (sizeKb > 500) {
        Fluttertoast.showToast(msg: 'Image max 500KB', backgroundColor: Colors.red, textColor: Colors.white);
        return;
      }

      final ext = picked.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        Fluttertoast.showToast(msg: 'Invalid file type. Please upload JPEG, PNG, GIF, or WebP images.', backgroundColor: Colors.red, textColor: Colors.white);
        return;
      }

      setState(() {
        _profileImageBytes = bytes;
        _isUploading = true;
      });

      final base64 = base64Encode(bytes);
      final dataUrl = 'data:image/$ext;base64,$base64';

      final token = await AuthService.getToken();
      if (token == null) {
        setState(() => _isUploading = false);
        return;
      }
      final baseUrl = context.read<DashboardProvider>().apiBaseUrl;
      final authed = ApiService(baseUrl: baseUrl, authToken: token);
      final res = await authed.updateProfile({'profile_picture': dataUrl});

      if (res.success) {
        Fluttertoast.showToast(msg: 'Profile picture updated', backgroundColor: Colors.green, textColor: Colors.white);
        final provider = context.read<DashboardProvider>();
        await provider.fetchDashboardData(showLoading: false);
      } else {
        Fluttertoast.showToast(msg: res.message, backgroundColor: Colors.red, textColor: Colors.white);
        setState(() {
          _profileImageBytes = null;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload image. Please try again.', backgroundColor: Colors.red, textColor: Colors.white);
      setState(() {
        _profileImageBytes = null;
      });
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      Fluttertoast.showToast(msg: 'Email is required', backgroundColor: Colors.red, textColor: Colors.white);
      return;
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final api = ApiService(baseUrl: 'https://copybloomfx-mobile-app-backend-dmgy.onrender.com', authToken: token);
      final res = await api.updateProfile({'email': email});
      if (res.success) {
        Fluttertoast.showToast(msg: 'Profile updated successfully!', backgroundColor: Colors.green, textColor: Colors.white);
        await context.read<DashboardProvider>().fetchDashboardData(showLoading: false);
      } else {
        Fluttertoast.showToast(msg: res.message, backgroundColor: Colors.red, textColor: Colors.white);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update profile. Please try again.', backgroundColor: Colors.red, textColor: Colors.white);
    }
  }

  Future<void> _redeemPromoCode() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isRedeeming = true);
    final success = await context.read<DashboardProvider>().redeemPromo(code);
    setState(() => _isRedeeming = false);

    if (success) {
      Fluttertoast.showToast(
        msg: "Promo code applied! Bonus added to tradable balance.",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      _promoCodeController.clear();
    } else {
      final error = context.read<DashboardProvider>().errorMessage;
      Fluttertoast.showToast(
        msg: error ?? "Invalid or expired promo code.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

}
