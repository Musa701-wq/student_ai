import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:student_ai/config/app_links.dart';
import 'package:student_ai/Screens/sharedItems/sharedContentHub.dart';
import '../Providers/authProvider.dart';
import '../Providers/notesProvider.dart';
import '../Screens/profile/profileScreen.dart';
import '../config/creditConfig.dart';
import '../google_analytics.dart';
import '../models/notesModel.dart';
import '../services/creditService.dart';
import 'addPlans/addPlan.dart';
import 'addPlans/showPlanFeed.dart';
import 'addQuiz/addQuiz.dart';
import 'addQuiz/quizListScreen.dart';
import 'addnotes/add_notes_screen.dart';
import 'dependency_graph/dependency_graph_hub_screen.dart';
import 'mindmap/mindmap_screen.dart';
import 'authwrapper.dart';
import 'tutor/AITutorScreen.dart';
import 'homeworkHelper/homeworkScreen.dart';
import 'notesFeed/notesFeedScreen.dart';
import '../Providers/homeStatsProvider.dart';
import 'notesFeed/showNotesDetail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marquee/marquee.dart';
import 'syllabus/SyllabusHubScreen.dart';
import 'purchaseScreen/specialOfferScreen.dart';
import 'addnotes/NotesCleanerScreen.dart';
import 'flashcards/FlashcardHubScreen.dart';
import 'flashcards/FlashcardGeneratorScreen.dart';
import 'eli5/ELI5Screen.dart';
import 'infographic/InfographicHubScreen.dart';
import 'dependency_graph/dependency_graph_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/adService.dart';


class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _showTooltip = true;
  bool _isProUser = false;
  StreamSubscription? _proSubscription;
  int _notesKey = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showTooltip = false);
      }
    });

    Future.microtask(
          () => Provider.of<HomeStatsProvider>(
        context,
        listen: false,
      ).fetchRecommendedNotes(),
    );

    // Set up listener for pro status
    _setupProStatusListener();
  }

  void _setupProStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _proSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (doc) {
          if (doc.exists) {
            setState(() {
              _isProUser = doc.data()?['isPro'] ?? false;
            });
          }
        },
        onError: (error) {
          debugPrint('Error listening to pro status: $error');
        },
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _proSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<authProvider1>(context);
    final profile = authProv.userModel;

    final List<Widget> _screens = [
      HomeBody(
        profile: profile,
        animation: _fadeAnimation,
        isProUser: _isProUser,
        onNavigateToIndex: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 1) {
              _notesKey = DateTime.now().millisecondsSinceEpoch;
            }
          });
        },
      ),
      NotesFeedScreen(key: ValueKey(_notesKey)),
      QuizListScreen(),
      PlanFeedScreen(),
      ProfileScreen(uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ];

    return Scaffold(
      body: SafeArea(child: _screens[_selectedIndex]),
      bottomNavigationBar: _buildResponsiveBottomNavBar(),
      floatingActionButton: _buildResponsiveFAB(),
    );
  }

  Widget _buildResponsiveBottomNavBar() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;
    final double iconSize = isSmallScreen ? 22 : 28;
    final double fontSize = isSmallScreen ? 10 : 12;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: NavigationBar(
            height: 70,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(
                    () => {
                  _selectedIndex = index,
                  if (index == 1)
                    {_notesKey = DateTime.now().millisecondsSinceEpoch},
                },
              );
            },
            indicatorColor: const Color(0xFF6C63FF).withOpacity(0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.home,
                  size: iconSize,
                  color: const Color(0xFF6C63FF),
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.note_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.note,
                  size: iconSize,
                  color: const Color(0xFF6C63FF),
                ),
                label: 'Notes',
              ),
              NavigationDestination(
                icon: Icon(Icons.quiz_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.quiz,
                  size: iconSize,
                  color: const Color(0xFF6C63FF),
                ),
                label: 'Quiz',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_play_next_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.queue_play_next,
                  size: iconSize,
                  color: const Color(0xFF6C63FF),
                ),
                label: 'Plans',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, size: iconSize),
                selectedIcon: Icon(
                  Icons.person,
                  size: iconSize,
                  color: const Color(0xFF6C63FF),
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveFAB() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (_showTooltip)
          Positioned(
            bottom: isSmallScreen ? 70 : 80,
            right: isSmallScreen ? 12 : 16,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 10 : 12,
                vertical: isSmallScreen ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                "Upload your notes, let's chat!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ),
          ),
        FloatingActionButton(
          backgroundColor: const Color(0xFF6C63FF),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return const AITutorScreen();
                },
              ),
            );
          },
          child: Icon(
            Icons.chat_bubble,
            color: Colors.white,
            size: isSmallScreen ? 20 : 24,
          ),
        ),
      ],
    );
  }
}

class HomeBody extends StatelessWidget {
  final dynamic profile;
  final Animation<double> animation;
  final bool isProUser;
  final void Function(int index)? onNavigateToIndex;

  const HomeBody({
    super.key,
    required this.profile,
    required this.animation,
    required this.isProUser,
    this.onNavigateToIndex,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;


    return FadeTransition(
      opacity: animation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F5FF), Color(0xFFE6E6FF)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Home",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D2B4E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Marquee Banner
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SpecialOfferScreen()),
                              );
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Marquee(
                                text: '  🔥 SPECIAL OFFER: Get 50 credits for a quick recharge! Click here to grab it now! 🚀  ',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                scrollAxis: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                blankSpace: 20.0,
                                velocity: 50.0,
                                pauseAfterRound: const Duration(seconds: 1),
                                accelerationDuration: const Duration(seconds: 1),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(milliseconds: 500),
                                decelerationCurve: Curves.easeOut,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Show different header based on login status
                          if (isLoggedIn)
                            _buildWelcomeHeader(
                              context,
                              profile,
                              isDark,
                              isProUser,
                            )
                          else
                            _buildGuestWelcomeHeader(context, isDark),

                          const SizedBox(height: 10),

                          // Show different content based on login status
                          if (isLoggedIn) ...[
                            _buildProgressOverview(
                              context,
                              screenWidth,
                              screenHeight,
                            ),
                            const SizedBox(height: 32),
                            _buildQuickActions(context),
                            const SizedBox(height: 32),
                            _buildRecommendedResources(
                              context,
                              screenWidth,
                              screenHeight,
                            ),
                            const SizedBox(height: 32),
                            _buildELI5Section(context),
                          ] else ...[
                            _buildGuestQuickActions(context),
                            const SizedBox(height: 32),
                            _buildGuestFeatures(context),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Guest Welcome Header
  Widget _buildGuestWelcomeHeader(BuildContext context, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
            const Color(0xFF7C4DFF),
            const Color(0xFF448AFF),
            const Color(0xFF00B0FF),
          ]
              : [
            const Color(0xFF6A1B9A),
            const Color(0xFF8E24AA),
            const Color(0xFFAB47BC),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guest Icon
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.amber.shade200,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: isLargeScreen ? 28 : 24,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: isLargeScreen ? 26 : 22,
                    color: const Color(0xFF6A1B9A),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Welcome Message for Guest
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome to Mentor AI! 👋",
                      style: TextStyle(
                        fontSize: isLargeScreen ? 20 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Join thousands of students boosting their productivity",
                      style: TextStyle(
                        fontSize: isLargeScreen ? 14 : 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Login/Signup Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthWrapper(isHome: true),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthWrapper(isHome: true),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_rounded,
                              size: 18,
                              color: const Color(0xFF6A1B9A),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Sign Up",
                              style: TextStyle(
                                color: const Color(0xFF6A1B9A),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Guest Quick Actions
  Widget _buildGuestQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Get Started',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 24 : 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: isSmallScreen ? 146 : 166,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildActionCard(
                title: 'ELI5 Mode',
                icon: Icons.child_care_rounded,
                subtitle: 'Simplify concepts',
                colors: const [Color(0xFF6C63FF), Color(0xFF8E24AA)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ELI5Screen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Infographic AI',
                icon: Icons.auto_awesome_mosaic_rounded,
                subtitle: 'Visual summaries',
                colors: const [Color(0xFFFFB300), Color(0xFFFF6F00)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InfographicHubScreen()),
                  );
                },
                context: context,
              ),
              /* _buildGuestActionCard(
                title: 'Create Study Plans',
                icon: Icons.auto_awesome_mosaic_rounded,
                subtitle: 'Plan your learning journey',
                colors: const [Color(0xFF2196F3), Color(0xFF03A9F4)],
                context: context,
              ),*/
              _buildActionCard(
                title: 'Create Study Plan',
                icon: Icons.auto_awesome_mosaic_rounded,
                subtitle: 'Plan your study',
                colors: const [Color(0xFF2196F3), Color(0xFF03A9F4)],
                onTap: () {
                  AnalyticsService.logCreatePlanClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AiPlannerScreen()),
                  );
                },
                context: context,
              ),
              _buildGuestActionCard(
                title: 'Take Quizzes',
                icon: Icons.quiz_rounded,
                subtitle: 'Test your knowledge',
                colors: const [Color(0xFFFF9800), Color(0xFFFF5722)],
                context: context,
              ),
              /*_buildGuestActionCard(
                title: 'Create Notes',
                icon: Icons.note_add_rounded,
                subtitle: 'Organize your study materials',
                colors: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
                context: context,
              ),*/
              _buildActionCard(
                title: 'Add Notes',
                icon: Icons.note_add_rounded,
                subtitle: 'Create new notes',
                colors: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
                onTap: () {
                  AnalyticsService.logCreateNoteClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddNotesScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Notes Cleaner',
                icon: Icons.cleaning_services_rounded,
                subtitle: 'Structure messy notes',
                colors: const [Color(0xFF00C853), Color(0xFF1B5E20)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotesCleanerScreen()),
                  );
                },
                context: context,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestActionCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required List<Color> colors,
    required BuildContext context,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Container(
      width: isSmallScreen ? 140 : 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _showLoginPrompt(context);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 22 : 26,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Guest Features Section
  Widget _buildGuestFeatures(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Why Join Mentor AI?',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 24 : 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildFeatureItem(
                icon: Icons.auto_awesome_rounded,
                title: "AI-Powered Learning",
                subtitle: "Smart study plans and personalized recommendations",
                color: Colors.purple,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.track_changes_rounded,
                title: "Progress Tracking",
                subtitle: "Monitor your learning journey with detailed analytics",
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.share_rounded,
                title: "Collaborative Learning",
                subtitle: "Share notes and quizzes with friends",
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.workspace_premium_rounded,
                title: "Premium Features",
                subtitle: "Ad-free experience with advanced tools",
                color: Colors.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuthWrapper(isHome: true),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
              shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
            ),
            child: const Text(
              'Start Your Learning Journey',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2B4E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.login_rounded, color: Color(0xFF6C63FF)),
              SizedBox(width: 12),
              Text(
                "Join Mentor AI",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2B4E),
                ),
              ),
            ],
          ),
          content: const Text(
            "Please login or create an account to access this feature and start your learning journey!",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Later',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthWrapper(isHome: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Login / Sign Up'),
            ),
          ],
        );
      },
    );
  }

  // Original Welcome Header for logged-in users
  Widget _buildWelcomeHeader(
      BuildContext context,
      dynamic profile,
      bool isDark,
      bool isProUser,
      ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;
    final bool isLargeScreen = screenWidth > 600;

    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
            const Color(0xFF7C4DFF),
            const Color(0xFF448AFF),
            const Color(0xFF00B0FF),
          ]
              : [
            const Color(0xFF6A1B9A),
            const Color(0xFF8E24AA),
            const Color(0xFFAB47BC),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Consumer<HomeStatsProvider>(
        builder: (context, stats, _) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.amber.shade200,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: isLargeScreen ? 28 : 24,
                          backgroundColor: Colors.white,
                          backgroundImage: profile?.profilePic != null
                              ? NetworkImage(profile.profilePic)
                              : null,
                          child: profile?.profilePic == null
                              ? Icon(
                            Icons.person,
                            size: isLargeScreen ? 26 : 22,
                            color: const Color(0xFF6A1B9A),
                          )
                              : null,
                        ),
                      ),
                      if (isProUser)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 1.5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.workspace_premium,
                              color: Colors.deepPurple,
                              size: isLargeScreen ? 12 : 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "Welcome back, ${profile?.name?.split(' ').first ?? 'Student'}! 👋",
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 20 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isProUser
                              ? "Premium experience activated! ✨"
                              : "Let's make today productive! 💪",
                          style: TextStyle(
                            fontSize: isLargeScreen ? 14 : 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: IconButton(
                      iconSize: isLargeScreen ? 20 : 18,
                      tooltip: 'Share App',
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () {
                        Share.share(appStoreUrl);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: stats.loading
                    ? Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Loading progress...",
                      style: TextStyle(
                        fontSize: isLargeScreen ? 13 : 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: isLargeScreen ? 18 : 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Daily Progress",
                            style: TextStyle(
                              fontSize: isLargeScreen ? 13 : 12,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${stats.completedPlans}/${stats.completedPlans + stats.incompletePlans} tasks",
                            style: TextStyle(
                              fontSize: isLargeScreen ? 14 : 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final totalTasks = stats.completedPlans + stats.incompletePlans;
                                  final completionRate = totalTasks > 0
                                      ? (stats.completedPlans / totalTasks)
                                      : 0;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOut,
                                    height: 6,
                                    width: constraints.maxWidth * completionRate,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.greenAccent.shade400,
                                          Colors.blueAccent.shade400,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${(((stats.completedPlans + stats.incompletePlans) > 0 ? (stats.completedPlans / (stats.completedPlans + stats.incompletePlans)) : 0) * 100).round()}% complete",
                            style: TextStyle(
                              fontSize: isLargeScreen ? 11 : 10,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      icon: Icons.quiz_rounded,
                      value: "Quizzes",
                      count: stats.totalQuizzes,
                      context: context,
                      onTap: () {
                        onNavigateToIndex?.call(2);
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                      icon: Icons.notes_rounded,
                      value: "Notes",
                      count: stats.recommendedNotes.length,
                      context: context,
                      onTap: () {
                        onNavigateToIndex?.call(1);
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                      icon: Icons.flag_rounded,
                      value: "Goals",
                      count: stats.totalPlans,
                      context: context,
                      onTap: () {
                        onNavigateToIndex?.call(3);
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required int count,
    required BuildContext context,
    VoidCallback? onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isLargeScreen ? 16 : 14,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: isLargeScreen ? 16 : 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: isLargeScreen ? 12 : 11,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep all your existing methods for logged-in users
  Widget _buildELI5Section(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Text(
                'ELI5 Mode',
                style: TextStyle(
                  fontSize: screenWidth > 600 ? 24 : 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF2D2B4E),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildEli5MiniCard(
                title: 'ELI5 Mentor',
                subtitle: 'Simplify logic',
                icon: Icons.child_care_rounded,
                colors: [const Color(0xFF6C63FF), const Color(0xFF8E24AA)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ELI5Screen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEli5MiniCard(
                title: 'Infographic AI',
                subtitle: 'Visual study',
                icon: Icons.auto_awesome_mosaic_rounded,
                colors: [const Color(0xFFFFB300), const Color(0xFFFF6F00)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InfographicHubScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildEli5MiniCard(
                title: 'Dependency Graph',
                subtitle: 'Chronological topics',
                icon: Icons.account_tree_rounded,
                colors: [const Color(0xFF2196F3), const Color(0xFF03A9F4)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DependencyGraphHubScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: const SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildEli5MiniCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140, // Fixed height to prevent layout crashes in scroll views
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 24 : 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: isSmallScreen ? 140 : 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              const SizedBox(width: 4),
              _buildActionCard(
                title: 'ELI5 Mode',
                icon: Icons.child_care_rounded,
                subtitle: 'Simplify concepts',
                colors: const [Color(0xFF6C63FF), Color(0xFF8E24AA)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ELI5Screen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Infographic AI',
                icon: Icons.auto_awesome_mosaic_rounded,
                subtitle: 'Visual summaries',
                colors: const [Color(0xFFFFB300), Color(0xFFFF6F00)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InfographicHubScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Auto Syllabus',
                icon: Icons.auto_stories_rounded,
                subtitle: 'Get roadmap',
                colors: const [Color(0xFF6C63FF), Color(0xFF4A47A3)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SyllabusHubScreen()),
                  );
                },
                context: context,
              ),

              _buildActionCard(
                title: 'Create Study Plan',
                icon: Icons.auto_awesome_mosaic_rounded,
                subtitle: 'Plan your study',
                colors: const [Color(0xFF2196F3), Color(0xFF03A9F4)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AiPlannerScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Create Quiz',
                icon: Icons.quiz_rounded,
                subtitle: 'Test your knowledge',
                colors: const [Color(0xFFFF9800), Color(0xFFFF5722)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddQuizScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Add Notes',
                icon: Icons.note_add_rounded,
                subtitle: 'Create new notes',
                colors: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddNotesScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'AI Mindmap',
                icon: Icons.account_tree_rounded,
                subtitle: 'Visualize your notes',
                colors: const [Color(0xFFE91E63), Color(0xFFC2185B)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MindmapScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Dependency Graph',
                icon: Icons.account_tree_rounded,
                subtitle: 'Topic prerequisites',
                colors: const [Color(0xFF2196F3), Color(0xFF03A9F4)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DependencyGraphHubScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Notes Cleaner',
                icon: Icons.cleaning_services_rounded,
                subtitle: 'Structure messy notes',
                colors: const [Color(0xFF00C853), Color(0xFF1B5E20)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotesCleanerScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'AI Flashcards',
                icon: Icons.style_rounded,
                subtitle: 'Generate study cards',
                colors: const [Color(0xFFFF5252), Color(0xFFD32F2F)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FlashcardHubScreen()),
                  );
                },
                context: context,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Popular Actions',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 24 : 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: isSmallScreen ? 140 : 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildActionCard(
                title: 'Homework Hub',
                icon: Icons.library_books_rounded,
                subtitle: 'Guide steps',
                colors: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomeworkHubScreen()),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Shared Items',
                icon: Icons.share_rounded,
                subtitle: 'Get help from your friends',
                colors: const [Color(0xFFFF9800), Color(0xFFFF5722)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SharedContentHub()),
                  );
                },
                context: context,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Container(
      width: isSmallScreen ? 140 : 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 22 : 26,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverview(
      BuildContext context,
      double screenWidth,
      double screenHeight,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSmallScreen = screenWidth < 375;

    return Consumer<HomeStatsProvider>(
      builder: (context, stats, _) {
        if (stats.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final statItems = [
          {
            'title': 'Quizzes',
            'value': stats.totalQuizzes.toString(),
            'progress': stats.avgQuizScore / 100,
            'color': Colors.orange,
            'icon': Icons.quiz_rounded,
            'subtitle': 'Score Avg: ${stats.avgQuizScore.toStringAsFixed(1)}%',
          },
          {
            'title': 'Planner',
            'value': '${stats.totalPlans} Plans',
            'progress': stats.totalPlans > 0 ? 0.6 : 0.0,
            'color': Colors.green,
            'icon': Icons.calendar_today_rounded,
            'subtitle': stats.latestExamDate != null
                ? "Exam: ${stats.latestExamDate}"
                : "No exam set",
          },
          {
            'title': 'Goals',
            'value':
            "${stats.completedPlans}/${stats.completedPlans + stats.incompletePlans}",
            'progress': (stats.completedPlans + stats.incompletePlans) > 0
                ? stats.completedPlans /
                (stats.completedPlans + stats.incompletePlans)
                : 0.0,
            'color': Colors.blue,
            'icon': Icons.flag_rounded,
            'subtitle': "Your goals",
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: screenWidth > 600 ? 24 : 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: isSmallScreen ? 145 : 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: statItems.length,
                itemBuilder: (context, index) {
                  final stat = statItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildStatCard(
                      title: stat['title'] as String,
                      value: stat['value'] as String,
                      progress: stat['progress'] as double,
                      color: stat['color'] as Color,
                      icon: stat['icon'] as IconData,
                      subtitle: stat['subtitle'] as String,
                      context: context,
                      stats: stats,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required double progress,
    required Color color,
    required IconData icon,
    required String subtitle,
    required BuildContext context,
    required HomeStatsProvider stats,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTiny = screenWidth < 340;
    final bool isSmallScreen = screenWidth < 375;
    final bool isMediumScreen = screenWidth < 420;

    return GestureDetector(
      onTap: () => _showStatDialog(context, title, stats),
      child: Container(
        width: isTiny ? 130 : (isSmallScreen ? 140 : (isMediumScreen ? 160 : 180)),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? null
              : [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTiny ? 10 : (isSmallScreen ? 12 : 14),
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTiny ? 6 : 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: isTiny ? 16 : (isSmallScreen ? 18 : (isMediumScreen ? 20 : 22)),
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTiny ? 14 : (isSmallScreen ? 16 : (isMediumScreen ? 18 : 20)),
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : (isSmallScreen ? 8 : 12)),
            Text(
              title,
              style: TextStyle(
                fontSize: isTiny ? 12 : (isSmallScreen ? 14 : 16),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isTiny ? 3 : (isSmallScreen ? 4 : 6)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isTiny ? 10 : (isSmallScreen ? 11 : 13),
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isTiny ? 6 : (isSmallScreen ? 8 : 12)),
            Stack(
              children: [
                Container(
                  height: isTiny ? 4 : 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: isTiny ? 4 : 6,
                  width: (isTiny ? 90 : (isSmallScreen ? 100 : (isMediumScreen ? 120 : 140))) * progress,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatDialog(
      BuildContext context,
      String title,
      HomeStatsProvider stats,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String dialogTitle;
    List<Widget> content = [];

    switch (title) {
      case 'Quizzes':
        dialogTitle = 'Quiz Statistics';
        content = [
          _buildDialogRow(
            'Total Quizzes Taken',
            '${stats.totalQuizzes}',
            Icons.quiz,
            context,
          ),
          _buildDialogRow(
            'Average Score',
            '${stats.avgQuizScore.toStringAsFixed(1)}%',
            Icons.grade,
            context,
          ),
          _buildDialogRow(
            'Current Streak',
            '${stats.streakCount} days',
            Icons.local_fire_department,
            context,
          ),
          if (stats.latestExamDate != null)
            _buildDialogRow(
              'Next Exam',
              stats.latestExamDate!.toLocal().toString().split(' ')[0],
              Icons.event,
              context,
            ),
        ];
        break;

      case 'Planner':
        dialogTitle = 'Study Plan Progress';
        content = [
          _buildDialogRow(
            'Total Plans',
            '${stats.totalPlans}',
            Icons.assignment,
            context,
          ),
          _buildDialogRow(
            'Completed Plans',
            '${stats.completedPlans}',
            Icons.check_circle,
            context,
          ),
          _buildDialogRow(
            'Incomplete Plans',
            '${stats.incompletePlans}',
            Icons.pending,
            context,
          ),
          _buildDialogRow(
            'Completion Rate',
            '${stats.totalPlans > 0 ? ((stats.completedPlans / stats.totalPlans) * 100).toStringAsFixed(1) : 0}%',
            Icons.trending_up,
            context,
          ),
        ];
        break;

      case 'Goals':
        dialogTitle = 'Goal Tracking';
        content = [
          _buildDialogRow(
            'Study Streak',
            '${stats.streakCount} days',
            Icons.local_fire_department,
            context,
          ),
          _buildDialogRow(
            'Quiz Average',
            '${stats.avgQuizScore.toStringAsFixed(1)}%',
            Icons.grade,
            context,
          ),
          _buildDialogRow(
            'Plans Completed',
            '${stats.completedPlans}',
            Icons.check_circle,
            context,
          ),
          _buildDialogRow(
            'Recommended Notes',
            '${stats.recommendedNotes.length}',
            Icons.lightbulb,
            context,
          ),
        ];
        break;

      default:
        dialogTitle = 'Statistics';
        content = [
          _buildDialogRow('No data available', '', Icons.info, context),
        ];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                _getIconForTitle(title),
                color: _getColorForTitle(title),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                dialogTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D2B4E),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: const Color(0xFF6C63FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow(
      String label,
      String value,
      IconData icon,
      BuildContext context,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Quizzes':
        return Icons.quiz;
      case 'Planner':
        return Icons.assignment;
      case 'Goals':
        return Icons.flag;
      default:
        return Icons.info;
    }
  }

  Color _getColorForTitle(String title) {
    switch (title) {
      case 'Quizzes':
        return Colors.blue;
      case 'Planner':
        return Colors.green;
      case 'Goals':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRecommendedResources(
      BuildContext context,
      double screenWidth,
      double screenHeight,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<HomeStatsProvider>(
      builder: (context, stats, _) {
        if (stats.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (stats.recommendedNotes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, top: 16),
            child: Text(
              "No notes to recommend yet",
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Recommended For You',
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 24 : 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: screenHeight * 0.35,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: stats.recommendedNotes.length,
                itemBuilder: (context, index) => FadeTransition(
                  opacity: animation,
                  child: _buildResourceCard(
                    note: stats.recommendedNotes[index],
                    index: index,
                    isDark: isDark,
                    context: context,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResourceCard({
    required int index,
    required bool isDark,
    required NoteModel note,
    required BuildContext context,
  }) {
    final random = Random();
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    final colors = [
      [const Color(0xFFFFA726), const Color(0xFFFF7043)],
      [const Color(0xFF42A5F5), const Color(0xFF4FC3F7)],
      [const Color(0xFF66BB6A), const Color(0xFF81C784)],
      [const Color(0xFFAB47BC), const Color(0xFFBA68C8)],
      [const Color(0xFFEF5350), const Color(0xFFE57373)],
    ];

    final icons = [
      Icons.school_rounded,
      Icons.timer_rounded,
      Icons.assignment_rounded,
      Icons.self_improvement_rounded,
      Icons.work_rounded,
    ];

    final times = [
      "5 min read",
      "7 min read",
      "10 min read",
      "12 min read",
      "15 min read",
      "20 min read",
    ];

    final tag = note.tags.isNotEmpty
        ? note.tags[random.nextInt(note.tags.length)]
        : ["Learning", "Productivity", "Academics", "Wellness", "Future"][random.nextInt(5)];

    return Container(
      width: isSmallScreen ? 180 : 220,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteDetailScreen(
                  note: note,
                  onShare: () {
                    _openShareDialog(note, context);
                  },
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors[index % colors.length],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icons[index % icons.length],
                    size: isSmallScreen ? 20 : 24,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  note.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: isSmallScreen ? 12 : 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      times[random.nextInt(times.length)],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: isSmallScreen ? 12 : 16,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: isSmallScreen ? 12 : 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openShareDialog(NoteModel note, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String q = '';
        Timer? _debounce;
        bool isLoading = false;
        List<Map<String, dynamic>> results = [];
        final provider = Provider.of<NotesProvider>(context, listen: false);
        final already = note.withShared.toSet();
        final selected = <String>{};

        return StatefulBuilder(
          builder: (context, setStateSB) {
            Future<void> runSearch(String query) async {
              setStateSB(() => isLoading = true);
              final res = await provider.searchUsers(query);
              setStateSB(() {
                results = res;
                isLoading = false;
              });
            }

            void onChanged(String v) {
              q = v;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () async {
                await runSearch(q);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Share note',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D2B4E),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: 'Search users by name or email',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    if (!isLoading)
                      Flexible(
                        child: results.isEmpty && q.isNotEmpty
                            ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No users found for "$q"',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('Share App'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Share.share('Check out Mentor AI: $appStoreUrl');
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final u = results[i];
                            final uid = u['uid'] as String;
                            final disabled = already.contains(uid);
                            final checked = selected.contains(uid);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (u['profilePic'] != null && (u['profilePic'] as String).isNotEmpty)
                                    ? NetworkImage(u['profilePic'])
                                    : null,
                                child: (u['profilePic'] == null || (u['profilePic'] as String).isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(u['name'] ?? 'User'),
                              subtitle: (u['email'] != null && (u['email'] as String).isNotEmpty)
                                  ? Text(u['email'])
                                  : null,
                              trailing: disabled
                                  ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Shared',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              )
                                  : Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  if (disabled) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Note already shared with this user')),
                                    );
                                    return;
                                  }
                                  if (v == true) {
                                    selected.add(uid);
                                  } else {
                                    selected.remove(uid);
                                  }
                                  setStateSB(() {});
                                },
                              ),
                              onTap: () {
                                if (disabled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Note already shared with this user')),
                                  );
                                } else {
                                  if (checked) {
                                    selected.remove(uid);
                                  } else {
                                    selected.add(uid);
                                  }
                                  setStateSB(() {});
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          onPressed: selected.isEmpty
                              ? null
                              : () async {
                            await CreditsService.confirmAndDeductCredits(
                              context: context,
                              cost: CreditsConfig.shareNote,
                              actionName: "Share Notes",
                              onConfirmedAction: () async {
                                final (added, alreadyDup) = await provider.shareNoteWithUsers(
                                  note: note,
                                  targetUids: selected.toList(),
                                );

                                if (alreadyDup.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Already shared with: ${alreadyDup.length} user(s)')),
                                  );
                                }
                                if (added.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Shared with ${added.length} user(s) 🎉 -${CreditsConfig.shareNote} credits'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}