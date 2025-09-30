import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();

  // Animation controllers - simplified
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  int _currentPage = 0;
  bool _isLoading = false;
  String _selectedGender = '';
  bool _hasGenderError = false; // NEW: Gender validation state
  bool _makeFieldsOptional = false; // NEW: Optional fields toggle

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Simplified animations - only fade for page content
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _fadeAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // NEW: Progress indicator
            _buildProgressIndicator(theme, colorScheme),

            // PageView content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  // Restart animation only for content, not conflicting with PageView
                  _fadeAnimationController.reset();
                  _fadeAnimationController.forward();
                },
                children: [
                  _buildWelcomePage(context, colorScheme, theme),
                  _buildUserInfoPage(context, colorScheme, theme),
                  _buildCompletePage(context, colorScheme, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Progress indicator widget
  Widget _buildProgressIndicator(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isActive = index == _currentPage;
              final isCompleted = index < _currentPage;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: isActive ? 24 : 8,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // Page indicator text
          Text(
            'Step ${_currentPage + 1} of 3',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Page 1: Welcome & App Introduction
  Widget _buildWelcomePage(
      BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // App Logo & Name with hero animation
            Hero(
              tag: 'app_logo',
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.psychology,
                  size: 80,
                  color: colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'PersonalMedAI',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              'Your Personal Health Assistant',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Enhanced features list
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  _buildFeatureItem(
                    Icons.psychology,
                    'AI-Powered Health Insights',
                    'Get personalized health recommendations',
                    colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.medication,
                    'Medication Management',
                    'Track medications and check interactions',
                    colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.chat,
                    '24/7 AI Health Chat',
                    'Ask health questions anytime, anywhere',
                    colorScheme,
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _navigateToPage(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Get Started',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Page 2: Enhanced User Information Form
  Widget _buildUserInfoPage(
      BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () => _dismissKeyboard(), // NEW: Dismiss keyboard on tap
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header with skip option
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tell us about yourself',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This helps us provide personalized health recommendations',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // NEW: Quick setup toggle
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _makeFieldsOptional = !_makeFieldsOptional;
                        });
                      },
                      icon:
                          Icon(_makeFieldsOptional ? Icons.tune : Icons.speed),
                      label: Text(_makeFieldsOptional
                          ? 'Detailed Setup'
                          : 'Quick Setup'),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            colorScheme.primaryContainer.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        // Name field - always required for personalization
                        _buildEnhancedTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          icon: Icons.person,
                          isRequired: true,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Email field - optional in quick mode
                        _buildEnhancedTextField(
                          controller: _emailController,
                          label:
                              'Email Address${_makeFieldsOptional ? ' (Optional)' : ''}',
                          hint: 'Enter your email address',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          isRequired: !_makeFieldsOptional,
                          validator: _makeFieldsOptional
                              ? null
                              : (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                        ),

                        const SizedBox(height: 20),

                        // Age field - always required for medical relevance
                        _buildEnhancedTextField(
                          controller: _ageController,
                          label: 'Age',
                          hint: 'Enter your age',
                          icon: Icons.cake,
                          keyboardType: TextInputType.number,
                          isRequired: true,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your age';
                            }
                            final age = int.tryParse(value);
                            if (age == null || age < 1 || age > 150) {
                              return 'Please enter a valid age (1-150)';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Enhanced Gender selection with error state
                        _buildGenderSelector(colorScheme, theme),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              // Enhanced navigation buttons
              _buildNavigationButtons(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Enhanced gender selector with error state
  Widget _buildGenderSelector(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasGenderError
              ? Colors.red.withOpacity(0.8)
              : colorScheme.outline.withOpacity(0.2),
          width: _hasGenderError ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wc,
                color: _hasGenderError ? Colors.red : colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Gender *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _hasGenderError ? Colors.red : colorScheme.primary,
                ),
              ),
              if (_hasGenderError) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 16,
                ),
              ],
            ],
          ),

          if (_hasGenderError) ...[
            const SizedBox(height: 8),
            Text(
              'Please select your gender',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Gender options with enhanced feedback
          Row(
            children: [
              Expanded(
                child: _buildGenderOption('Male', Icons.male),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderOption('Female', Icons.female),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderOption('Other', Icons.person),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Enhanced text field with better styling
  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textCapitalization: keyboardType == TextInputType.name
          ? TextCapitalization.words
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: isRequired
            ? Icon(Icons.star, color: Colors.red.shade300, size: 12)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      onTap: () {
        // Clear gender error when user interacts with form
        if (_hasGenderError) {
          setState(() {
            _hasGenderError = false;
          });
        }
      },
    );
  }

  // Enhanced navigation buttons
  Widget _buildNavigationButtons(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateToPage(0),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitUserInfo,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(_isLoading ? 'Processing...' : 'Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Page 3: Completion (enhanced)
  Widget _buildCompletePage(
      BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Enhanced success animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.2),
                          Colors.green.withOpacity(0.1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.green,
                        ),
                        // Animated ring
                        SizedBox(
                          height: 100,
                          width: 100,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green.withOpacity(0.3),
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            Text(
              'Welcome to PersonalMedAI!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Consumer<AppState>(
              builder: (context, appState, child) {
                return Text(
                  'Hi ${appState.userName}! 👋\n\nYou\'re all set to start your personalized health journey with AI-powered insights and recommendations.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),

            const SizedBox(height: 40),

            // Enhanced features preview
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.3),
                    colorScheme.secondaryContainer.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'You can now:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReadyFeature(
                      Icons.chat, 'Chat with AI about health questions'),
                  const SizedBox(height: 12),
                  _buildReadyFeature(
                      Icons.medication, 'Check medication interactions'),
                  const SizedBox(height: 12),
                  _buildReadyFeature(Icons.search, 'Analyze your symptoms'),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Enhanced start button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _completeOnboarding,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Start Using PersonalMedAI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for navigation with keyboard dismissal
  void _navigateToPage(int page) {
    _dismissKeyboard();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // NEW: Dismiss keyboard
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Widget _buildFeatureItem(
      IconData icon, String title, String subtitle, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
          _hasGenderError = false; // Clear error on selection
        });

        // Haptic feedback
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(height: 4),
            Text(
              gender,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _submitUserInfo() async {
    _dismissKeyboard(); // Dismiss keyboard first

    // Reset gender error state
    setState(() {
      _hasGenderError = false;
    });

    // Validate form and gender
    bool isFormValid = _formKey.currentState!.validate();
    bool isGenderValid = _selectedGender.isNotEmpty;

    if (!isFormValid || !isGenderValid) {
      if (!isGenderValid) {
        setState(() {
          _hasGenderError = true;
        });

        // Enhanced error feedback
        HapticFeedback.mediumImpact();

        // Show in-context error instead of SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Please select your gender to continue'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      // Save user information
      appState.setUserName(_nameController.text.trim());

      // Save email only if provided (supports optional mode)
      if (_emailController.text.trim().isNotEmpty) {
        appState.setUserEmail(_emailController.text.trim());
      }

      appState.setUserAge(int.parse(_ageController.text.trim()));
      appState.setUserGender(_selectedGender);

      // Enhanced processing delay with haptic feedback
      await Future.delayed(const Duration(milliseconds: 1200));
      HapticFeedback.mediumImpact();

      _navigateToPage(2);
    } catch (e) {
      // Enhanced error handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Something went wrong. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _submitUserInfo(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _completeOnboarding() async {
    await OnboardingService.completeOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
