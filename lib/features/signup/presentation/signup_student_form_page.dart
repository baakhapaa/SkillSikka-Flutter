import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

Future<String?> _pickOption(
  BuildContext context,
  String title,
  List<String> options,
) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          ...options.map(
            (option) => ListTile(
              title: Text(option),
              onTap: () => Navigator.pop(context, option),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class SignupStudentFormPage extends StatefulWidget {
  const SignupStudentFormPage({super.key});

  @override
  State<SignupStudentFormPage> createState() => _SignupStudentFormPageState();
}

class _SignupStudentFormPageState extends State<SignupStudentFormPage> {
  final _controllers = <String, TextEditingController>{};
  bool _obscurePassword = true;

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

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
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                      child: Column(
                        children: [
                          const _ProfileUpload(),
                          const SizedBox(height: 24),
                          _Field(
                            label: 'Full Name',
                            hint: 'e.g. Skill Sikka',
                            requiredField: true,
                            controller: _controller('name'),
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Email Address',
                            hint: 'e.g. skill@email.com',
                            requiredField: true,
                            leading: 'assets/figma/signup_mail.svg',
                            controller: _controller('email'),
                          ),
                          const SizedBox(height: 16),
                          _PasswordField(
                            label: 'Password',
                            controller: _controller('password'),
                            requiredField: true,
                            obscure: _obscurePassword,
                            onToggle: _togglePassword,
                          ),
                          const SizedBox(height: 16),
                          _PasswordField(
                            label: 'Confirm Password',
                            controller: _controller('confirm'),
                            requiredField: true,
                            obscure: _obscurePassword,
                            onToggle: _togglePassword,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Field(
                                  label: 'Gender',
                                  hint: 'Select gender',
                                  requiredField: true,
                                  trailing:
                                      'assets/figma/signup_chevron_down.svg',
                                  controller: _controller('gender'),
                                  onTap: () => _selectGender(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Field(
                                  label: 'Date of Birth',
                                  hint: 'DD / MM / YYYY',
                                  requiredField: true,
                                  controller: _controller('dob'),
                                  onTap: () => _selectDateOfBirth(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Phone Number',
                            hint: '+977 98XXXXXXXX',
                            requiredField: true,
                            controller: _controller('phone'),
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Location',
                            hint: 'Enter your current location',
                            requiredField: true,
                            leading: 'assets/figma/signup_location.svg',
                            controller: _controller('location'),
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Class / Grade',
                            hint: 'Select your class',
                            requiredField: true,
                            trailing: 'assets/figma/signup_chevron_down.svg',
                            controller: _controller('class'),
                            onTap: () => _selectClass(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Field(
                                  label: 'Province',
                                  hint: 'Select province',
                                  hintFontSize: 12,
                                  requiredField: true,
                                  trailing:
                                      'assets/figma/signup_chevron_down.svg',
                                  controller: _controller('province'),
                                  onTap: () => _selectProvince(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Field(
                                  label: 'District',
                                  hint: 'Select province first',
                                  hintFontSize: 11,
                                  requiredField: true,
                                  trailing:
                                      'assets/figma/signup_chevron_down.svg',
                                  controller: _controller('district'),
                                  enabled: _controller(
                                    'province',
                                  ).text.isNotEmpty,
                                  onTap: () => _selectDistrict(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'School / College (Select district first)',
                            hint: 'Select school or college',
                            trailing: 'assets/figma/signup_chevron_down.svg',
                            controller: _controller('school'),
                            enabled: _controller('district').text.isNotEmpty,
                            onTap: () => _selectSchool(),
                          ),
                          const SizedBox(height: 16),
                          const _UploadCard(),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
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
                                const SizedBox(width: 8),
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
          ],
        ),
      ),
    );
  }

  void _togglePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  Future<void> _selectGender() async {
    final value = await _pickOption(context, 'Select gender', const [
      'Female',
      'Male',
      'Other',
    ]);
    if (value != null) setState(() => _controller('gender').text = value);
  }

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      setState(() => _controller('dob').text = '$day / $month / ${date.year}');
    }
  }

  Future<void> _selectClass() async {
    final value = await _pickOption(context, 'Select class', const [
      'Class 8',
      'Class 9',
      'Class 10',
      'Class 11',
      'Class 12',
    ]);
    if (value != null) setState(() => _controller('class').text = value);
  }

  Future<void> _selectProvince() async {
    final value = await _pickOption(context, 'Select province', const [
      'Bagmati',
      'Gandaki',
      'Koshi',
      'Lumbini',
    ]);
    if (value != null) {
      setState(() {
        _controller('province').text = value;
        _controller('district').clear();
        _controller('school').clear();
      });
    }
  }

  Future<void> _selectDistrict() async {
    if (_controller('province').text.isEmpty) return;
    final value = await _pickOption(context, 'Select district', const [
      'Kathmandu',
      'Lalitpur',
      'Bhaktapur',
      'Chitwan',
    ]);
    if (value != null) {
      setState(() {
        _controller('district').text = value;
        _controller('school').clear();
      });
    }
  }

  Future<void> _selectSchool() async {
    if (_controller('district').text.isEmpty) return;
    final value = await _pickOption(context, 'Select school or college', const [
      'Skill Sikka Academy',
      'Kathmandu Model College',
      'National College',
    ]);
    if (value != null) setState(() => _controller('school').text = value);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
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

class _ProfileUpload extends StatelessWidget {
  const _ProfileUpload();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFFFBF0), width: 2),
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 244, 240, 230),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(10),
          child: SvgPicture.asset('assets/figma/signup_camera.svg'),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Upload Profile Photo',
        style: GoogleFonts.manrope(
          color: const Color(0xFF111827),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        'Clear face photo (JPG, PNG • Max 5MB)',
        style: GoogleFonts.manrope(
          color: const Color.fromARGB(255, 111, 113, 117),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.requiredField = false,
    this.leading,
    this.trailing,
    this.trailingWidget,
    this.onTap,
    this.enabled = true,
    this.obscureText = false,
    this.hintFontSize = 14,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool requiredField;
  final String? leading;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final bool enabled;
  final bool obscureText;
  final double hintFontSize;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
        text: TextSpan(
          style: GoogleFonts.manrope(
            color: const Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w700,
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
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        enabled: enabled,
        readOnly: onTap != null,
        onTap: onTap,
        obscureText: obscureText,
        style: GoogleFonts.manrope(
          color: const Color(0xFF111827),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
            color: const Color(0xFF9CA3AF),
            fontSize: hintFontSize,
          ),
          prefixIcon: leading == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(14),
                  child: SvgPicture.asset(leading!, width: 16, height: 16),
                ),
          suffixIcon:
              trailingWidget ??
              (trailing == null
                  ? null
                  : IconButton(
                      onPressed: onTap,
                      icon: SvgPicture.asset(trailing!, width: 16, height: 16),
                    )),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF2F1F7),
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
          disabledBorder: OutlineInputBorder(
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.requiredField,
    required this.obscure,
    required this.onToggle,
  });
  final String label;
  final TextEditingController controller;
  final bool requiredField;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => _Field(
    label: label,
    requiredField: requiredField,
    hint: '••••••••••••',
    controller: controller,
    leading: 'assets/figma/signup_lock.svg',
    trailingWidget: IconButton(
      onPressed: onToggle,
      tooltip: obscure ? 'Show password' : 'Hide password',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: obscure
            ? const Icon(
                Icons.visibility_off_outlined,
                key: ValueKey('password-hidden'),
                color: Color(0xFF4B5462),
                size: 20,
              )
            : SvgPicture.asset(
                'assets/figma/signup_eye.svg',
                key: const ValueKey('password-visible'),
                width: 16,
                height: 16,
              ),
      ),
    ),
    obscureText: obscure,
  );
}

class _UploadCard extends StatelessWidget {
  const _UploadCard();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Student ID Card',
        style: GoogleFonts.manrope(
          color: const Color(0xFF111827),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
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
              child: SvgPicture.asset('assets/figma/signup_student_file.svg'),
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
              'Supported formats: PDF, JPG, PNG (Max 5MB)',
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
