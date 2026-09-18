import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/features/instructors/presentation/instructor_profile.dart';

class InstructorCarousel extends StatefulWidget {
  const InstructorCarousel({super.key});

  @override
  State<InstructorCarousel> createState() => _InstructorCarouselState();
}

class _InstructorCarouselState extends State<InstructorCarousel> {
  int _selectedIndex = 0;

  static const _instructors = [
    (
      image: 'instructor.png',
      name: 'Shuvanga Karki',
      specialty: 'Adobe Certified Instructor',
      students: '915,213 students',
      courses: '40 courses',
    ),
    (
      image: 'instructor2.png',
      name: 'Dr. Sarah Pakhrin',
      specialty: 'PhD in Pure Mathematics',
      students: '124,500 students',
      courses: '12 courses',
    ),
    (
      image: 'instructor3.png',
      name: 'Alexa Thapa',
      specialty: 'Senior Python Developer',
      students: '89,200 students',
      courses: '8 courses',
    ),
    (
      image: 'instructor4.png',
      name: 'Anush Shrestha',
      specialty: 'Senior Front-End Lead',
      students: '215,000 students',
      courses: '15 courses',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 420);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usableWidth = constraints.maxWidth - 32;
          final narrowWidth = usableWidth * 45.43 / (178 + 3 * 45.43);
          final wideWidth = usableWidth - 3 * narrowWidth;
          return SizedBox(
            height: 165,
            child: Row(
              children: [
                for (var index = 0; index < _instructors.length; index++) ...[
                  if (index > 0) SizedBox(width: index == 1 ? 16 : 8),
                  AnimatedContainer(
                    key: ValueKey('instructor-card-$index'),
                    duration: duration,
                    curve: Curves.easeInOutCubic,
                    width: index == _selectedIndex ? wideWidth : narrowWidth,
                    height: 165,
                    child: Semantics(
                      button: true,
                      selected: index == _selectedIndex,
                      label: 'Select ${_instructors[index].name}',
                      child: Material(
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            if (_selectedIndex != index) {
                              setState(() => _selectedIndex = index);
                              return;
                            }

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const InstructorProfilePage(),
                              ),
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Ink.image(
                                image: AssetImage(
                                  'assets/figma/homescreen/${_instructors[index].image}',
                                ),
                                fit: BoxFit.cover,
                              ),
                              if (index == _selectedIndex)
                                IgnorePointer(
                                  child: ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.bottomLeft,
                                      minWidth: wideWidth,
                                      maxWidth: wideWidth,
                                      child: _details(index),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _details(int index) {
    final instructor = _instructors[index];
    return Container(
      alignment: Alignment.bottomLeft,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x80000000)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            instructor.name,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: GoogleFonts.manrope(
              color: const Color(0xFFFFF8E2),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final text in [
            instructor.specialty,
            instructor.students,
            instructor.courses,
          ])
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: GoogleFonts.inter(
                color: const Color(0xFFFFF8E2),
                fontSize: 8,
                fontWeight: text == instructor.courses
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
