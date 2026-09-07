import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupInstructorFormPage extends StatefulWidget {
  const SignupInstructorFormPage({super.key});

  @override
  State<SignupInstructorFormPage> createState() =>
      _SignupInstructorFormPageState();
}

class _SignupInstructorFormPageState extends State<SignupInstructorFormPage> {
  final _controllers = <String, TextEditingController>{};
  bool _obscurePassword = true;

  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(key, TextEditingController.new);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              _Header(onBack: () => context.pop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                child: Column(
                  children: [
                    const _ProfileUpload(),
                    const SizedBox(height: 24),
                    _FormField(
                      label: 'Full Name',
                      requiredField: true,
                      hint: 'e.g. Skill sikka',
                      controller: _controller('name'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _FormField(
                            label: 'Gender',
                            requiredField: true,
                            hint: 'Select gender',
                            trailingAsset:
                                'assets/figma/signup_chevron_down.svg',
                            controller: _controller('gender'),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _FormField(
                            label: 'Date of Birth',
                            requiredField: true,
                            hint: 'DD / MM / YYYY',
                            controller: _controller('dob'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Email',
                      hint: 'e.g. skill@email.com',
                      leadingAsset: 'assets/figma/signup_mail.svg',
                      controller: _controller('email'),
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      label: 'Password',
                      controller: _controller('password'),
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      label: 'Confirm Password',
                      controller: _controller('confirmPassword'),
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Phone Number',
                      hint: '98XXXXXXXX',
                      controller: _controller('phone'),
                      leadingText: '🇳🇵 +977',
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Location',
                      requiredField: true,
                      hint: 'Enter your current location',
                      leadingAsset: 'assets/figma/signup_location.svg',
                      controller: _controller('location'),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Highest Qualification / Degree',
                      requiredField: true,
                      hint: 'e.g. Master of Computer Applications',
                      controller: _controller('degree'),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Subject Expertise',
                      requiredField: true,
                      hint: 'e.g. Physics, Fullstack Web Dev',
                      controller: _controller('subject'),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Years of Experience',
                      requiredField: true,
                      hint: 'e.g. 5 Years',
                      controller: _controller('experience'),
                    ),
                    const SizedBox(height: 20),
                    const _UploadCard(
                      title: 'CV / Resume',
                      formats: 'Supported formats: PDF, DOCX (Max 5MB)',
                      asset: 'assets/figma/signup_file_text.svg',
                    ),
                    const SizedBox(height: 20),
                    const _UploadCard(
                      title: 'Certificates & Recommendation Letters',
                      formats: 'Supported formats: PDF, JPG, PNG (Max 10MB)',
                      asset: 'assets/figma/signup_file.svg',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            'assets/figma/signup_info.svg',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Our admin team reviews all verification requests within 24-48 business hours. You'll receive an email notification once approved.",
                              style: GoogleFonts.manrope(
                                color: const Color(0xFF2F2600),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => context.push('/signup/verify'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE6B800),
                          foregroundColor: const Color(0xFF111827),
                          elevation: 4,
                          shadowColor: const Color(0x40E6B800),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Submit Verification',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              icon: SvgPicture.asset(
                'assets/figma/signup_arrow_left.svg',
                width: 50,
                height: 50,
              ),
              style: IconButton.styleFrom(shape: const CircleBorder()),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Step: 2 of 4',
              style: GoogleFonts.manrope(
                color: const Color.fromARGB(255, 44, 43, 45),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileUpload extends StatelessWidget {
  const _ProfileUpload();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFFFBF0), width: 2),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBF0),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset('assets/figma/signup_camera.svg'),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Upload Profile Photo',
          style: GoogleFonts.manrope(
            color: const Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Clear face photo (JPG, PNG • Max 5MB)',
          style: GoogleFonts.manrope(
            color: const Color(0xFF9CA3AF),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.requiredField = false,
    this.leadingAsset,
    this.trailingAsset,
    this.obscureText = false,
    this.onTrailingTap,
    this.leadingText,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool requiredField;
  final String? leadingAsset;
  final String? trailingAsset;
  final String? leadingText;
  final bool obscureText;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label: label, requiredField: requiredField),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.manrope(
            color: const Color(0xFF111827),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              color: const Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            prefixText: leadingText,
            prefixIcon: leadingAsset == null
                ? null
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: SvgPicture.asset(
                      leadingAsset!,
                      width: 16,
                      height: 16,
                    ),
                  ),
            suffixIcon: trailingAsset == null
                ? null
                : IconButton(
                    onPressed: onTrailingTap,
                    icon: SvgPicture.asset(
                      trailingAsset!,
                      width: 16,
                      height: 16,
                    ),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6B800)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _FormField(
      label: label,
      hint: '••••••••••••',
      controller: controller,
      leadingAsset: 'assets/figma/signup_lock.svg',
      trailingAsset: 'assets/figma/eye.svg',
      obscureText: obscure,
      onTrailingTap: onToggle,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.requiredField});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.manrope(
          color: const Color(0xFF111827),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: label),
          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.title,
    required this.formats,
    required this.asset,
  });

  final String title;
  final String formats;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label: title, requiredField: false),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            border: Border.all(
              color: const Color(0xFFE6B800),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6B800),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(asset),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Document',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF2F2600),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formats,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: const Color(0xFF4B5563),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
