import 'package:assignment/models/experience.dart';
import 'package:assignment/screens/experience_selection/widgets/squiggly_progressbar.dart';
import 'package:assignment/screens/onboarding_question/onboarding_question_screen.dart';

// import 'package:assignment/screens/onboarding_question/onboarding_question_screen.dart';
import 'package:assignment/services/experience_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ExperienceSelectionScreen extends StatefulWidget {
  const ExperienceSelectionScreen({super.key});

  @override
  State<ExperienceSelectionScreen> createState() =>
      _ExperienceSelectionScreenState();
}

class _ExperienceSelectionScreenState extends State<ExperienceSelectionScreen> {
  List<Experience> experiences = [];
  List<int> selectedIds = [];
  final TextEditingController _textController = TextEditingController();
  bool isLoading = true;
List<Experience> originalOrder = [];
  @override
  void initState() {
    super.initState();
    loadExperiences();
  }

Future<void> loadExperiences() async {
  final data = await ExperienceService.getExperiences();
  setState(() {
    experiences = data;
    originalOrder = List.from(data); // ✅ store original order
    isLoading = false;
  });
}
void toggleSelection(int id) {
  setState(() {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }

    // Rebuild visible list:
    final selected = originalOrder.where((e) => selectedIds.contains(e.id)).toList();
    final unselected = originalOrder.where((e) => !selectedIds.contains(e.id)).toList();

    experiences = [...selected, ...unselected];
  });
}

  void onNext() async {
  final box = Hive.box('host_data');

  //  Save text input
  box.put('host_reason', _textController.text.trim());

  //  Save selected experiences also if needed later
  box.put('selected_experiences', selectedIds);

  print("Saved to Hive:");
  print("Reason: ${box.get('host_reason')}");
  print("Choices: ${box.get('selected_experiences')}");

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const HostReasonScreen(step: 4),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;
    // This is the real condition for proceeding
    final canProceed = hasText && selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Padding(        
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 22),
                        ),
                        const SquigglyProgressBar(step: 2),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 28),
                        ),
                      ],
                    ),

                    // MIDDLE CONTENT 
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 130),

                            const Text(
                              "01",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 8),

                            const Text(
                              "What kind of hotspots do you want to host?",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 25),

                            // Card List
                        AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: SizedBox(
                                key: ValueKey(selectedIds.join(",")), // forces animation when order changes
                                height: 115,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: experiences.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final exp = experiences[index];
                                    final isSelected = selectedIds.contains(exp.id);

                                    return GestureDetector(
                                      onTap: () => toggleSelection(exp.id),
                                      child: Transform.rotate(
                                        angle: index.isEven ? -0.05 : 0.04,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOut,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.transparent, width: 0),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isSelected
                                                    ? Colors.white.withOpacity(0.38)
                                                    : Colors.black.withOpacity(0.35),
                                                blurRadius: isSelected ? 22 : 6,
                                                spreadRadius: isSelected ? 3 : -1,
                                                offset: const Offset(0, 0),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: ColorFiltered(
                                              colorFilter: isSelected
                                                  ? const ColorFilter.mode(
                                                      Colors.transparent,
                                                      BlendMode.multiply,
                                                    )
                                                  : const ColorFilter.matrix([
                                                      0.2126, 0.7152, 0.0722, 0, 0,
                                                      0.2126, 0.7152, 0.0722, 0, 0,
                                                      0.2126, 0.7152, 0.0722, 0, 0,
                                                      0, 0, 0, 1, 0,
                                                    ]),
                                              child: Image.network(
                                                exp.imageUrl,
                                                width: 120,
                                                height: 130,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Text Input
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.18)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              child: TextField(
                                controller: _textController,
                                maxLines: 4,
                                maxLength: 250,
                                onChanged: (_) => setState(() {}),
                                cursorColor: Colors.white,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "/ Describe your perfect hotspot",
                                  hintStyle: TextStyle(color: Colors.white54),
                                  counterText: "",
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // BOTTOM BAR
                    GestureDetector(
                      onTap: canProceed ? onNext : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white
                                .withOpacity(canProceed ? 0.9 : 0.4),
                            width: 1.4,
                          ),
                          boxShadow: canProceed
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.33),
                                    blurRadius: 22,
                                    spreadRadius: 3,
                                    offset: const Offset(0, 0),
                                  )
                                ]
                              : [],
                          color: canProceed
                              ? Colors.white.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Next",
                              style: TextStyle(
                                color: Colors.white
                                    .withOpacity(canProceed ? 1 : 0.6),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: Colors.white
                                  .withOpacity(canProceed ? 1 : 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}