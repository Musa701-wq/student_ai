// lib/screens/ai_planner_screen.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/notesProvider.dart';
import '../../Providers/studyPlannerProvider.dart';
import '../../config/creditConfig.dart';
import '../../services/creditService.dart';



class AiPlannerScreen extends StatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _goalController = TextEditingController();
  DateTime? _examDate;
  DateTime? _startDate;
  int studyDaysPerWeek = 5;
  double hoursPerDay = 2;
  List<String> selectedNotes = [];

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _pickDate(BuildContext context, bool isExamDate) async {
    final now = DateTime.now();
    await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              height: 180,
              child: CupertinoDatePicker(
                initialDateTime: isExamDate
                    ? (_examDate ?? (_startDate ?? now))
                    : (_startDate ?? now),
                mode: CupertinoDatePickerMode.date,
                minimumDate: isExamDate ? (_startDate ?? now) : now,
                onDateTimeChanged: (date) {
                  setState(() {
                    if (isExamDate) {
                      _examDate = date;
                    } else {
                      _startDate = date;
                    }
                  });
                },
              ),
            ),
            CupertinoButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _generatePlan(BuildContext context) async {
    if (_goalController.text.isEmpty || _examDate == null || _startDate == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Missing Information'),
          content: const Text(
              'Please fill all required fields to generate your study plan.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    // Validate that exam date is strictly after preparation start date
    if (!_examDate!.isAfter(_startDate!)) {
      showCupertinoDialog(
        context: context,
        builder: (context) => const CupertinoAlertDialog(
          title: Text('Invalid Dates'),
          content: Text('Exam date must be after the preparation start date.'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    await CreditsService.confirmAndDeductCredits(
      context: context,
      cost: CreditsConfig.aiPlanner, // ✅ configurable from credits_config.dart
      actionName: "AI Study Planner",
      onConfirmedAction: () async {
        final provider =
        Provider.of<StudyPlannerProvider>(context, listen: false);
        await provider.generatePlan(
          goal: _goalController.text,
          examDate: _examDate!.toIso8601String(),
          startDate: _startDate!.toIso8601String(),
          selectedNotes: selectedNotes,
          studyDaysPerWeek: studyDaysPerWeek,
          hoursPerDay: hoursPerDay.toInt(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Study Plan generated! -${CreditsConfig.aiPlanner} credits",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Consumer2<StudyPlannerProvider, NotesProvider>(
      builder: (context, plannerProvider, notesProvider, _) {
        return CupertinoPageScaffold(
          resizeToAvoidBottomInset: true,
          navigationBar: CupertinoNavigationBar(
            middle: const Text("AI Study Planner"),
            backgroundColor: isDark ? null : Colors.white,
            border: null,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  const Color(0xFF0F3460),
                ]
                    : [
                  const Color(0xFFFFFF),
                  const Color(0xFFFFFF),
                  const Color(0xFFFFFF),
                ],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      setState(() {});
                    },
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Welcome header
                        _buildHeader(context),
                        const SizedBox(height: 24),

                        // Goal input
                        _buildSectionHeader('Study Goal', Icons.flag),
                        const SizedBox(height: 8),
                        _buildGoalInput(),
                        const SizedBox(height: 24),

                        // Date selection
                        _buildSectionHeader('Timeline', Icons.calendar_today),
                        const SizedBox(height: 8),
                        _buildDateSelection(),
                        const SizedBox(height: 24),

                        // Study preferences
                        _buildSectionHeader('Study Preferences', Icons.settings),
                        const SizedBox(height: 8),
                        _buildStudyPreferences(),
                        const SizedBox(height: 24),

                        // Notes selection
                        if (notesProvider.notes.isNotEmpty) ...[
                          _buildSectionHeader('Select Notes (Optional)', Icons.note),
                          const SizedBox(height: 8),
                          _buildNotesSelection(notesProvider),
                          const SizedBox(height: 24),
                        ],

                        // Generate button
                        _buildGenerateButton(plannerProvider),
                        const SizedBox(height: 20),

                        // Generated plan
                        if (plannerProvider.studyPlan != null)
                          _buildStudyPlan(plannerProvider),
                      ]),
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

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFAB47BC), Color(0xFF8E24AA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Study Plan',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white,

                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(1, 1),

                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let AI help you create a personalized study schedule',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,

                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF333333),

              decoration: TextDecoration.none,
              fontWeight: FontWeight.bold
          ),
        ),
      ],
    );
  }

  Widget _buildGoalInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CupertinoTextField(
        controller: _goalController,
        placeholder: 'e.g., Final Exams, Math Test, etc.',
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: null,
        ),
        style: const TextStyle(fontSize: 16,

            decoration: TextDecoration.none,
            fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildDateSelection() {
    return Row(
      children: [
        Expanded(
          child: _buildDateButton(
            'Preparation Start Date',
            _startDate,
                () => _pickDate(context, false),
            const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDateButton(
            'Exam Date',
            _examDate,
                () => _pickDate(context, true),
            const LinearGradient(
              colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
            ),
          ),
        ),


      ],
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onPressed, Gradient gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.calendar,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              date == null ? label : '${date.day}/${date.month}/${date.year}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,

                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyPreferences() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Days per week
          _buildSliderPreference(
            label: 'Days per week',
            value: studyDaysPerWeek.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            onChanged: (value) => setState(() => studyDaysPerWeek = value.toInt()),
            gradient: const LinearGradient(
              colors: [Color(0xFFAB47BC), Color(0xFF8E24AA)],
            ),
          ),
          const SizedBox(height: 20),

          // Hours per day
          _buildSliderPreference(
            label: 'Hours per day',
            value: hoursPerDay.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            valueFormatter: (value) => value.toStringAsFixed(1),
            onChanged: (value) => setState(() => hoursPerDay = value),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderPreference({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required Gradient gradient,
    String Function(double)? valueFormatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333)
                  ,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.bold
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                valueFormatter?.call(value) ?? value.toInt().toString(),
                style: const TextStyle(
                  color: Colors.white
                    ,
                    fontSize: 20,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // REPLACED Material Slider with CupertinoSlider
        CupertinoSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: const Color(0xFF4A90E2),
        ),
      ],
    );
  }

  Widget _buildNotesSelection(NotesProvider notesProvider) {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: notesProvider.notes.map((note) {
          final isSelected = selectedNotes.contains(note.content);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedNotes.remove(note.content);
                } else {
                  selectedNotes.add(note.content);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                  colors: [Color(0xFFAB47BC), Color(0xFF8E24AA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : const LinearGradient(
                  colors: [Color(0xFFE0E0E0), Color(0xFFF5F5F5)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFAB47BC).withOpacity(0.4)
                        : Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note,
                    color: isSelected ? Colors.white : const Color(0xFF666666),
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenerateButton(StudyPlannerProvider plannerProvider) {
    return plannerProvider.isLoading
        ? const Center(
      child: CupertinoActivityIndicator(),
    )
        : Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        borderRadius: BorderRadius.circular(16),
        onPressed: () => _generatePlan(context),
        color: const Color(0xFF4A90E2),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 10),
            Text(
              "Generate Study Plan",
              style: TextStyle(
                color: Colors.white,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyPlan(StudyPlannerProvider plannerProvider) {
    if (plannerProvider.studyPlan == null || plannerProvider.studyPlan!.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic> planJson;

    // Step 2: Parse JSON using the provider's robust method
    final parsedPlan = plannerProvider.parsePlan(plannerProvider.studyPlan!);
    
    if (parsedPlan == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to parse study plan from AI response',
          style: TextStyle(
            color: const Color(0xFF333333),
            fontSize: 16,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.normal
          ),
        ),
      );
    }
    
    planJson = parsedPlan;


    // Step 3: Extract topics safely
    final topics = (planJson['topics'] as List<dynamic>?)
        ?.map((t) => t as Map<String, dynamic>)
        .toList() ??
        [];

    final Map<String, Map<String, dynamic>> scheduleMap = {};

    for (var topic in topics) {
      final topicName = topic['name']?.toString() ?? 'Unnamed Topic';
      final hours =
          double.tryParse(topic['estimatedTime']?.toString() ?? '1') ?? 1;
      final assignedDays = (topic['assignedDays'] as List<dynamic>?)
          ?.map((d) => d.toString().split('T').first) // remove time
          .toList() ??
          [];

      for (var day in assignedDays) {
        if (scheduleMap.containsKey(day)) {
          (scheduleMap[day]!['topics'] as List).add(topicName);
          scheduleMap[day]!['hours'] += hours;
        } else {
          scheduleMap[day] = {
            'day': day,
            'topics': [topicName],
            'hours': hours,
          };
        }
      }
    }

    final studySchedule = scheduleMap.values.toList()
      ..sort((a, b) => a['day'].toString().compareTo(b['day'].toString()));

    final reminders = (planJson['reminders'] as List<dynamic>?)
        ?.map((r) => r.toString())
        .toList() ??
        [];

    if (studySchedule.isEmpty && reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'AI returned no study plan. Try adjusting your goal or dates.',
          style: TextStyle(
            color: const Color(0xFF333333),
            fontSize: 16
              ,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.normal
          ),
        ),
      );
    }

    // Step 4: Build UI
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (studySchedule.isNotEmpty) ...[
          _buildSectionHeader('Your Study Plan', Icons.schedule),
          const SizedBox(height: 12),
          ...studySchedule.map((dayPlan) {
            final day = dayPlan['day'];
            final topicsList = (dayPlan['topics'] as List).join(', ');
            final hours = dayPlan['hours'];
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day,
                      style: const TextStyle(
                          fontSize: 16,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.bold,
                      color: Colors.black)),
                  const SizedBox(height: 6),
                  Text('Topics: $topicsList',
                      style: const TextStyle(fontSize: 14,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.normal)),
                  const SizedBox(height: 4),
                  Text('Hours: $hours',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700],
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.normal)),
                ],
              ),
            );
          }).toList(),
        ],
        if (reminders.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Reminders', Icons.notifications),
          const SizedBox(height: 12),
          ...reminders.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                    ),
                  ),
                  child: const Icon(Icons.circle, size: 8, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(r,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                        decoration: TextDecoration.none,
                          fontWeight: FontWeight.normal
                        ))),
              ],
            ),
          )),
        ],
      ],
    );
  }
}