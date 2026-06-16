import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:student_ai/config/app_links.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../Providers/notesProvider.dart';
import '../../config/creditConfig.dart';
import '../../models/notesModel.dart';
import '../../services/adService.dart';
import '../../services/creditService.dart';
import '../../widgets/showNotes/noteCard.dart';
import '../AuthWrapper.dart';
import '../addnotes/add_notes_screen.dart';
import '../notesFeed/showNotesDetail.dart';

class NotesFeedScreen extends StatefulWidget {
  const NotesFeedScreen({super.key});

  @override
  State<NotesFeedScreen> createState() => _NotesFeedScreenState();
}

class _NotesFeedScreenState extends State<NotesFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  bool showFavOnly = false;
  String searchQuery = '';
  User? _currentUser;
  BannerAd? _bannerAd;
  bool _isPro = false;
  StreamSubscription? _proSub;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;

    if (_currentUser != null) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      provider.loadNotes();
    }

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final provider = Provider.of<NotesProvider>(context, listen: false);
        if (provider.hasMore) provider.loadNotes(query: searchQuery);
      }
    });

    _checkProStatus();
  }

  void _checkProStatus() {
    if (_currentUser == null) return;
    _proSub = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).snapshots().listen((snap) {
      if (snap.exists) {
        setState(() {
          _isPro = snap.data()?['isPro'] ?? false;
          if (_isPro) {
            _bannerAd?.dispose();
            _bannerAd = null;
          } else if (_bannerAd == null) {
            _loadBanner();
          }
        });
      }
    });
  }

  void _loadBanner() {
    _bannerAd = AdService.createBannerAd();
    setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bannerAd?.dispose();
    _proSub?.cancel();
    super.dispose();
  }

  void _openShareDialog(NoteModel note) {
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: 'Search users by name or email',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor:
                          Theme.of(context).brightness == Brightness.dark
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
                                  onPressed: () {
                                    Share.share('Check out Mentor AI: ' + appStoreUrl);
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
                                backgroundImage:
                                (u['profilePic'] != null &&
                                    (u['profilePic'] as String)
                                        .isNotEmpty)
                                    ? NetworkImage(u['profilePic'])
                                    : null,
                                child:
                                (u['profilePic'] == null ||
                                    (u['profilePic'] as String)
                                        .isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(u['name'] ?? 'User'),
                              subtitle:
                              (u['email'] != null &&
                                  (u['email'] as String).isNotEmpty)
                                  ? Text(u['email'])
                                  : null,
                              trailing: disabled
                                  ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(
                                    .15,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Shared',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                                  : Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  if (disabled) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Note already shared with this user',
                                        ),
                                      ),
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
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Note already shared with this user',
                                      ),
                                    ),
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
                          onPressed: selected.isEmpty
                              ? null
                              : () async {
                            await CreditsService.confirmAndDeductCredits(
                              context: context,
                              cost: CreditsConfig.shareNote,
                              actionName: "Share Notes",
                              onConfirmedAction: () async {
                                final (added, alreadyDup) = await provider
                                    .shareNoteWithUsers(
                                  note: note,
                                  targetUids: selected.toList(),
                                );

                                if (alreadyDup.isNotEmpty) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Already shared with: ${alreadyDup.length} user(s)',
                                      ),
                                    ),
                                  );
                                }
                                if (added.isNotEmpty) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Shared with ${added.length} user(s) 🎉 -${CreditsConfig.shareNote} credits',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                if (mounted) Navigator.pop(context);
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

  void onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    final provider = Provider.of<NotesProvider>(context, listen: false);
    provider.loadNotes(reset: true, query: query);
  }

  Widget _buildLoggedOutScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Notes Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.note_alt_rounded,
                  size: 60,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 32),

              // Welcome Text
              Text(
                "Organize Your Learning",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                "Create, manage, and access your study notes anytime, anywhere. Login to sync across all your devices.",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Features Grid
              _buildNotesFeaturesGrid(isDark),
              const SizedBox(height: 40),

              // Action Buttons
              Column(
                children: [
                  // Login Button
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
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                        shadowColor: Colors.deepPurple.withOpacity(0.4),
                      ),
                      child: const Text(
                        'Login to Access Notes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthWrapper(isHome: true),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: Colors.deepPurple,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Additional Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? null
                      : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_sync_rounded,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Your notes will be safely backed up and available on all your devices when you login.",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
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

  Widget _buildNotesFeaturesGrid(bool isDark) {
    final features = [
      {
        'icon': Icons.create_rounded,
        'title': 'Create Notes',
        'description': 'Write and organize your study materials',
        'color': Colors.purple,
      },
      {
        'icon': Icons.search_rounded,
        'title': 'Smart Search',
        'description': 'Quickly find notes by title or tags',
        'color': Colors.blue,
      },
      {
        'icon': Icons.favorite_rounded,
        'title': 'Favorites',
        'description': 'Bookmark important notes for easy access',
        'color': Colors.red,
      },
      {
        'icon': Icons.share_rounded,
        'title': 'Share Notes',
        'description': 'Collaborate with friends and classmates',
        'color': Colors.green,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: feature['color'] as Color? ?? Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  feature['icon'] as IconData? ?? Icons.star_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                feature['title'] as String? ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                feature['description'] as String? ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    // Check if user is logged in
    if (_currentUser == null) {
      return _buildLoggedOutScreen(isDark);
    }

    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final displayedNotes = showFavOnly
            ? provider.notes.where((n) => provider.isFavorite(n)).toList()
            : provider.notes;

        return Scaffold(
          backgroundColor: backgroundColor,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_bannerAd != null && !_isPro)
                SafeArea(
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
            ],
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.grey[800],
                  elevation: 0,
                  pinned: true,
                  floating: true,
                  title: Text(
                    "My Notes",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.grey[800],
                      decoration: TextDecoration.none,
                    ),
                  ),
                  actions: [
                    // Reload button
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? null
                            : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          final provider = Provider.of<NotesProvider>(
                            context,
                            listen: false,
                          );
                          provider.loadNotes(reset: true, query: searchQuery);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notes refreshed'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        tooltip: 'Refresh notes',
                      ),
                    ),
                    // Favorite button
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? null
                            : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          showFavOnly ? Icons.favorite : Icons.favorite_border,
                          color: showFavOnly
                              ? Colors.redAccent
                              : Colors.grey[600],
                        ),
                        onPressed: () =>
                            setState(() => showFavOnly = !showFavOnly),
                        tooltip: showFavOnly
                            ? 'Show all notes'
                            : 'Show favorites only',
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(80),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? null
                              : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search notes by title or tag...',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              decoration: TextDecoration.none,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey[500],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              onPressed: () {
                                onSearchChanged('');
                                FocusScope.of(context).unfocus();
                              },
                            )
                                : null,
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey[800],
                            decoration: TextDecoration.none,
                          ),
                          onChanged: onSearchChanged,
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: provider.isLoading && provider.notes.isEmpty
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF7E57C2),
                ),
              ),
            )
                : displayedNotes.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    showFavOnly
                        ? Icons.favorite_border_rounded
                        : Icons.search_off_rounded,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    showFavOnly
                        ? 'No favorite notes yet'
                        : 'No notes found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showFavOnly
                        ? 'Tap the heart icon on any note to add it to favorites'
                        : 'Try adjusting your search or create a new note',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!showFavOnly)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return AddNotesScreen();
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create New Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E57C2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () async =>
                  provider.loadNotes(reset: true, query: searchQuery),
              color: const Color(0xFF7E57C2),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            showFavOnly ? 'Favorite Notes' : 'All Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600],
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${displayedNotes.length} ${displayedNotes.length == 1 ? 'note' : 'notes'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.48,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          if (index >= displayedNotes.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: CircularProgressIndicator(
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                    Color(0xFF7E57C2),
                                  ),
                                ),
                              ),
                            );
                          }
                          final note = displayedNotes[index];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isDark
                                  ? null
                                  : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    0.1,
                                  ),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: NoteCard(
                                note: note,
                                isFavorite: provider.isFavorite(note),
                                onFavToggle: () =>
                                    provider.toggleFavorite(note),
                                onShare: () => _openShareDialog(note),
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoteDetailScreen(
                                        note: note,
                                        onShare: () =>
                                            _openShareDialog(note),
                                      ),
                                    ),
                                  );
                                },
                                onTap: () {
                                  AdService.showInterstitialAndNavigate(
                                    context,
                                    NoteDetailScreen(
                                      note: note,
                                      onShare: () {
                                        _openShareDialog(note);
                                      },
                                    ),
                                  );
                                },
                                onDelete: () async {
                                  try {
                                    await provider.deleteNote(note.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Note "${note.title}" deleted successfully',
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(
                                            seconds: 2,
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to delete note: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(
                                            seconds: 3,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                        childCount:
                        displayedNotes.length +
                            (provider.hasMore ? 1 : 0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}