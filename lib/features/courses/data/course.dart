import 'package:flutter/material.dart';

import '../../../core/widgets/course_detail_view.dart';

/// The seven "This course includes" rows, identical across the catalogue.
const _standardIncludes = <CourseInclude>[
  CourseInclude(Icons.play_circle_outline, 'On-demand video, yours to keep'),
  CourseInclude(Icons.quiz_outlined, 'Quizzes after every section'),
  CourseInclude(Icons.description_outlined, 'Downloadable support files'),
  CourseInclude(Icons.article_outlined, 'Written notes for each lesson'),
  CourseInclude(Icons.all_inclusive, 'Full lifetime access'),
  CourseInclude(Icons.devices, 'Access on mobile, desktop and TV'),
  CourseInclude(Icons.verified_outlined, 'Certificate of completion'),
];

/// The course catalogue, ordered by class.
///
/// **Presentation-only.** There is no `courses/` API and the dev database has no
/// published courses, so this is static demo content — the same status as every
/// other course screen in the app. Wiring it to a real endpoint is a separate
/// task; nothing here should be mistaken for fetched data.
///
/// One list serves everything: the Courses tab's grid, the home rail, and the
/// detail page each card opens. Both screens filter it by
/// [CourseDetailData.classLevel] using their own Class chips, which is why the
/// order matters — the home rail shows the **first four**, so the school classes
/// lead. `All` is not a value on any entry; it is the absence of a filter.
///
/// Every entry's [CourseDetailData.curriculumSummary] must agree with its
/// `modules`: the section count is `modules.length` and the lecture count is the
/// sum of the lesson lists. `test/course_detail_page_test.dart` asserts both.
const coursePool = <CourseDetailData>[
  CourseDetailData(
    image: 'assets/figma/homescreen/course-thumbnail3.png',
    title: 'Basic Geometry: Proofs & Shapes',
    subtitle:
        'Learn to construct a proof you can defend — from axioms and '
        'definitions to triangles, circles and congruence.',
    rating: '4.6',
    level: 'Beginner',
    category: 'Geometry',
    classLevel: 'Class 6',
    ratingsCount: '(5,471 ratings)',
    studentsEnrolled: '3,860 students enrolled',
    instructorName: 'K. Patel',
    instructorAvatar: 'assets/figma/instructors/instructor2.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English, Nepali, Hindi',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Write a two-column proof that another student can follow',
      'Know when triangles are congruent and when they only look it',
      'Use circle theorems instead of measuring and hoping',
      'Build a shape from a written construction with compass and straightedge',
    ],
    curriculumSummary: '3 sections • 9 lectures • 4h 51m total length',
    modules: [
      CourseModule('Axioms, definitions and the idea of proof', '41 mins', [
        CourseLesson('What a proof is, and what it is not', '05:12'),
        CourseLesson('Axioms, postulates and definitions', '06:40'),
        CourseLesson('Your first two-column proof', '08:05', isPreview: true),
      ]),
      CourseModule('Triangles, congruence and similarity', '1h 03m', [
        CourseLesson('Naming triangles and their parts', '04:55'),
        CourseLesson('The congruence tests, one at a time', '09:20'),
        CourseLesson('Similarity and the ratios it gives you', '07:35'),
      ]),
      CourseModule('Circles, constructions and loci', '48 mins', [
        CourseLesson('Chords, arcs and the centre', '06:10'),
        CourseLesson('Compass and straightedge: the basics', '07:25'),
        CourseLesson('Loci problems worth practising', '05:50'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with basic algebra',
      'A compass, a straightedge and paper — the constructions are hands-on',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - May 2026',
        body:
            'Added a full constructions module and worked every proof in the '
            'course on paper, on camera.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - November 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering axioms, triangles and circle theorems.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor2.png',
        name: 'K. Patel',
        title: 'Mathematics | Proof and Reasoning',
        rating: '4.5',
        reviews: '4,982',
        students: '27,640',
        courses: '10',
        bio:
            'A mathematics teacher who insists that a proof is a piece of '
            'writing, and marks it like one.',
      ),
    ],
    courseRating: '4.5',
    ratingBars: [
      RatingBar('5 ★', 62),
      RatingBar('4 ★', 26),
      RatingBar('3 ★', 8),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Bishal Karki',
        when: '10 days ago',
        body:
            'I could always do the calculations but never write the proof. '
            'That gap is closed now.',
      ),
      CourseReview(
        name: 'Muna Shrestha',
        when: '3 weeks ago',
        body: 'The constructions module is genuinely fun. Worth the compass.',
      ),
      CourseReview(
        name: 'Deepak Lama',
        when: '1 month ago',
        body: 'Clear and patient. Would like more on coordinate geometry.',
      ),
    ],
    totalTime: '4hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/course-thumbnail4.png',
    title: 'Introduction to Biology & Life',
    subtitle:
        'From cells to ecosystems: how living things are built, how they '
        'regulate themselves, and how they pass information on.',
    rating: '4.8',
    level: 'Beginner',
    category: 'Biology',
    classLevel: 'Class 6',
    ratingsCount: '(8,105 ratings)',
    studentsEnrolled: '6,412 students enrolled',
    instructorName: 'Dr. L. Chen',
    instructorAvatar: 'assets/figma/instructors/instructor4.png',
    lastUpdated: 'Last updated 09/2026',
    languages: 'English, Nepali, Hindi',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Explain how a cell maintains itself against its own chemistry',
      'Read a metabolic pathway and say where it would break',
      'Describe how a trait is inherited from a single gene pair',
      'Trace energy from a producer to the top of a food web',
    ],
    curriculumSummary: '3 sections • 9 lectures • 6h 12m total length',
    modules: [
      CourseModule('Cells, membranes and metabolism', '1h 02m', [
        CourseLesson('What makes something alive', '05:40'),
        CourseLesson('The cell and its membrane', '07:18'),
        CourseLesson(
          'Metabolism: where the energy goes',
          '09:02',
          isPreview: true,
        ),
      ]),
      CourseModule('Genetics and inheritance', '54 mins', [
        CourseLesson('DNA, genes and chromosomes', '06:25'),
        CourseLesson('Dominant, recessive and in between', '07:44'),
        CourseLesson('Reading a simple pedigree chart', '05:31'),
      ]),
      CourseModule('Ecology, energy and ecosystems', '49 mins', [
        CourseLesson('Producers, consumers and decomposers', '05:15'),
        CourseLesson('Food webs and energy loss', '06:48'),
        CourseLesson('Why ecosystems tip over', '05:02'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'No prior biology required',
      'High-school chemistry helps for the metabolism section',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - August 2026',
        body:
            'Rebuilt the metabolism module around pathways rather than lists, '
            'and added a full ecology section.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - March 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering cells, genetics and the basics of '
            'ecosystem energy flow.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor4.png',
        name: 'Dr. L. Chen',
        title: 'Cell Biology | Genetics',
        rating: '4.7',
        reviews: '7,630',
        students: '45,118',
        courses: '14',
        bio:
            'A cell biologist who explains living systems as engineering '
            'problems that evolution solved the long way round.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 73),
      RatingBar('4 ★', 19),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Sabina Maharjan',
        when: '6 days ago',
        body:
            'The pathway-first approach to metabolism is so much better than '
            'the memorisation I did at school.',
      ),
      CourseReview(
        name: 'Ramesh Gurung',
        when: '2 weeks ago',
        body:
            'Great visuals and a calm pace. The genetics section is the '
            'clearest I have found.',
      ),
      CourseReview(
        name: 'Kritika Basnet',
        when: '1 month ago',
        body: 'Thoroughly enjoyed it. Wanted more on human physiology.',
      ),
    ],
    totalTime: '6hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/course-thumbnail.png',
    title: 'Physical Chemistry Foundations',
    subtitle:
        'Build the physical-chemistry toolkit — gases, thermodynamics, '
        'kinetics and equilibrium — through worked numericals rather than '
        'formula memorisation.',
    rating: '4.7',
    level: 'Beginner',
    category: 'Chemistry',
    classLevel: 'Class 7',
    ratingsCount: '(6,842 ratings)',
    studentsEnrolled: '4,905 students enrolled',
    instructorName: 'Dr. S. Verma',
    instructorAvatar: 'assets/figma/instructors/instructor6.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Nepali, Hindi',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Apply the ideal gas law and its real-gas corrections to real problems',
      'Read a phase diagram and say what happens as conditions change',
      'Predict reaction direction from equilibrium constants',
      'Work numericals without memorising a formula sheet',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 44m total length',
    modules: [
      CourseModule('Gases and the kinetic model', '52 mins', [
        CourseLesson('Pressure, volume and temperature', '06:02'),
        CourseLesson('The ideal gas law in practice', '08:16'),
        CourseLesson(
          'When gases stop behaving ideally',
          '05:44',
          isPreview: true,
        ),
      ]),
      CourseModule('Thermodynamics and energetics', '1h 11m', [
        CourseLesson('Enthalpy and where it hides', '07:38'),
        CourseLesson('Entropy, in plain language', '08:55'),
        CourseLesson('Gibbs energy and spontaneity', '09:24'),
      ]),
      CourseModule('Kinetics, equilibrium and electrochemistry', '58 mins', [
        CourseLesson('Reaction rates and what changes them', '06:30'),
        CourseLesson('Equilibrium constants, worked through', '07:12'),
        CourseLesson('Electrochemical cells from scratch', '06:05'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'High-school chemistry and basic algebra',
      'A scientific calculator for the numericals',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - July 2026',
        body:
            'Rewrote the thermodynamics module around worked numericals and '
            'added a full electrochemistry section.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - January 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering gases, kinetics and equilibrium with a '
            'problem set after every lecture.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor6.png',
        name: 'Dr. S. Verma',
        title: 'Physical Chemistry | Numerical Methods',
        rating: '4.6',
        reviews: '5,318',
        students: '31,207',
        courses: '12',
        bio:
            'A chemistry lecturer who has taught the same numericals to three '
            'cohorts and still finds a better way to explain them each year.',
      ),
    ],
    courseRating: '4.6',
    ratingBars: [
      RatingBar('5 ★', 68),
      RatingBar('4 ★', 22),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Anjali Rana',
        when: '7 days ago',
        body:
            'The numericals are the whole point and there are plenty of '
            'them. Exactly what I needed before exams.',
      ),
      CourseReview(
        name: 'Sagar Poudel',
        when: '2 weeks ago',
        body:
            'Thermodynamics finally makes sense. The phase-diagram lesson is '
            'excellent.',
      ),
      CourseReview(
        name: 'Nirmala Devi',
        when: '1 month ago',
        body:
            'Good depth. The electrochemistry section could use more examples.',
      ),
    ],
    totalTime: '5hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/courses/python.png',
    title: 'Mathematics: Algebra Foundations',
    subtitle:
        'Build algebraic fluency from variables and expressions through linear '
        'equations, so later topics stop feeling like a bag of tricks.',
    rating: '4.7',
    level: 'Beginner',
    category: 'Mathematics',
    classLevel: 'Class 7',
    ratingsCount: '(4,918 ratings)',
    studentsEnrolled: '3,742 students enrolled',
    instructorName: 'R. Sharma',
    instructorAvatar: 'assets/figma/instructors/instructor7.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Nepali, Hindi',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Simplify an expression without losing a sign',
      'Translate a word problem into an equation you can solve',
      'Solve linear equations in one and two unknowns',
      'Check an answer instead of hoping it is right',
    ],
    curriculumSummary: '3 sections • 9 lectures • 3h 58m total length',
    modules: [
      CourseModule('Variables, terms and expressions', '46 mins', [
        CourseLesson('Why letters in maths are not scary', '05:08'),
        CourseLesson('Collecting like terms', '06:22'),
        CourseLesson(
          'Expanding and factorising brackets',
          '07:40',
          isPreview: true,
        ),
      ]),
      CourseModule('Linear equations in one unknown', '1h 04m', [
        CourseLesson('Keeping an equation balanced', '06:15'),
        CourseLesson('Equations with brackets and fractions', '08:02'),
        CourseLesson('Turning word problems into equations', '09:11'),
      ]),
      CourseModule('Two unknowns and graphs', '52 mins', [
        CourseLesson('Solving by substitution', '07:05'),
        CourseLesson('Solving by elimination', '06:48'),
        CourseLesson('Plotting a straight line from its equation', '06:20'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with arithmetic and negative numbers',
      'A notebook — the practice sets are the course',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - June 2026',
        body:
            'Added the word-problems section and a printable practice set '
            'after every lecture.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - December 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering expressions, linear equations and the '
            'basics of graphing.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor7.png',
        name: 'R. Sharma',
        title: 'Mathematics | Secondary Curriculum',
        rating: '4.7',
        reviews: '4,401',
        students: '29,884',
        courses: '16',
        bio:
            'A school mathematics teacher who has never once said "it just '
            'works" and meant it.',
      ),
    ],
    courseRating: '4.6',
    ratingBars: [
      RatingBar('5 ★', 67),
      RatingBar('4 ★', 23),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Aayush Bhandari',
        when: '5 days ago',
        body:
            'The "keeping an equation balanced" lecture undid two years of '
            'confusion in nine minutes.',
      ),
      CourseReview(
        name: 'Pratiksha Neupane',
        when: '3 weeks ago',
        body:
            'Practice sets after every lecture. That is the whole difference.',
      ),
      CourseReview(
        name: 'Sujal Adhikari',
        when: '1 month ago',
        body: 'Very clear. The graphing section felt rushed.',
      ),
    ],
    totalTime: '4hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/course-thumbnail2.png',
    title: 'World History: Middle Ages to Modern',
    subtitle:
        'Read the last thousand years as a chain of causes rather than a list '
        'of dates — trade, disease, empire and industry, and how they connect.',
    rating: '4.9',
    level: 'Beginner',
    category: 'History',
    classLevel: 'Class 8',
    ratingsCount: '(11,206 ratings)',
    studentsEnrolled: '9,338 students enrolled',
    instructorName: 'J. Okafor',
    instructorAvatar: 'assets/figma/instructors/instructor7.png',
    lastUpdated: 'Last updated 09/2026',
    languages: 'English, Nepali',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Explain how trade routes shaped political power across three continents',
      'Trace a single commodity from source to market and back to politics',
      'Separate a primary source from a later interpretation of it',
      'Argue a historical claim from evidence rather than from memory',
    ],
    curriculumSummary: '3 sections • 9 lectures • 7h 02m total length',
    modules: [
      CourseModule('Trade, plague and the medieval world', '1h 14m', [
        CourseLesson('The world in 1000 CE', '07:02'),
        CourseLesson('Silk, spice and the routes between', '09:18'),
        CourseLesson('Plague as a historical force', '08:36', isPreview: true),
      ]),
      CourseModule('Empire, exploration and exchange', '1h 06m', [
        CourseLesson('Why empires expand, and why they stop', '08:11'),
        CourseLesson('The Columbian exchange', '07:47'),
        CourseLesson('Colonialism and its ledgers', '09:05'),
      ]),
      CourseModule('Industry, revolution and the modern state', '55 mins', [
        CourseLesson('Coal, steam and the factory', '06:58'),
        CourseLesson('Revolutions in thought and in government', '07:24'),
        CourseLesson('How the modern state was built', '05:40'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'No prior history study needed',
      'Curiosity about why things happened, not just when',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 3.0 - June 2026',
        body:
            'Added a module on primary-source reading and rebuilt the '
            'trade-route maps.',
      ),
      CourseDescriptionBlock(heading: 'v 2.0 - September 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'Expanded the industrial-revolution material and added '
            'discussion questions to every lecture.',
      ),
      CourseDescriptionBlock(
        heading: 'v 1.0 - February 2025',
        body:
            'Initial release covering the medieval period to the modern state.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor7.png',
        name: 'J. Okafor',
        title: 'World History | Economic History',
        rating: '4.8',
        reviews: '9,447',
        students: '72,015',
        courses: '18',
        bio:
            'A historian who teaches the subject as a set of arguments rather '
            'than a timeline, and who will happily spend a whole lecture on '
            'one shipping ledger.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 79),
      RatingBar('4 ★', 15),
      RatingBar('3 ★', 4),
      RatingBar('2 ★', 1),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Prabin Adhikari',
        when: '3 days ago',
        body:
            'I have never enjoyed history before this. The causal thread '
            'through the whole course is what does it.',
      ),
      CourseReview(
        name: 'Sunita Regmi',
        when: '16 days ago',
        body: 'The primary-source module changed how I read everything else.',
      ),
      CourseReview(
        name: 'Hari Bahadur Thapa',
        when: '1 month ago',
        body: 'Superb teaching. A little long in the middle sections.',
      ),
    ],
    totalTime: '7hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse11.png',
    title: 'Science: Force, Motion & Energy',
    subtitle:
        'Understand why things move the way they do — speed, force, work and '
        'energy, with experiments you can run at a desk.',
    rating: '4.8',
    level: 'Intermediate',
    category: 'Science',
    classLevel: 'Class 8',
    ratingsCount: '(6,204 ratings)',
    studentsEnrolled: '5,113 students enrolled',
    instructorName: 'Dr. A. Thapa',
    instructorAvatar: 'assets/figma/instructors/instructor6.png',
    lastUpdated: 'Last updated 09/2026',
    languages: 'English, Nepali, Hindi',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Describe motion with graphs instead of just words',
      'Use Newton\'s laws to explain everyday situations',
      'Distinguish work, energy and power properly',
      'Measure something with a ruler and a stopwatch, and trust the number',
    ],
    curriculumSummary: '3 sections • 9 lectures • 4h 22m total length',
    modules: [
      CourseModule('Describing motion', '48 mins', [
        CourseLesson('Speed, velocity and acceleration', '06:12'),
        CourseLesson('Reading a distance-time graph', '07:30'),
        CourseLesson('Reading a velocity-time graph', '06:44', isPreview: true),
      ]),
      CourseModule('Forces and Newton\'s laws', '1h 08m', [
        CourseLesson('What a force actually is', '06:55'),
        CourseLesson('The three laws, with demos', '09:26'),
        CourseLesson('Friction, weight and normal force', '07:18'),
      ]),
      CourseModule('Work, energy and power', '56 mins', [
        CourseLesson('Work done, and when none is done', '06:40'),
        CourseLesson('Kinetic and potential energy', '08:02'),
        CourseLesson('Power, and why it costs money', '05:52'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Basic arithmetic and an interest in how things work',
      'A ruler, a stopwatch and a small ball for the experiments',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - July 2026',
        body:
            'Added a hands-on experiment to every lecture and rebuilt the '
            'graph-reading module.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - October 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'Initial release covering motion, forces and the energy chapter.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor6.png',
        name: 'Dr. A. Thapa',
        title: 'Physics | Science Education',
        rating: '4.8',
        reviews: '5,776',
        students: '38,205',
        courses: '11',
        bio:
            'A physics teacher who measures everything in front of the class, '
            'including the times the measurement goes wrong.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 74),
      RatingBar('4 ★', 18),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Nisha Tamang',
        when: '4 days ago',
        body:
            'The graph-reading lectures are worth the whole course. I stopped '
            'guessing at these.',
      ),
      CourseReview(
        name: 'Rabin Shakya',
        when: '2 weeks ago',
        body: 'Doing the experiments alongside made the laws stick.',
      ),
      CourseReview(
        name: 'Asmita Koirala',
        when: '1 month ago',
        body: 'Clear and well paced. More practice questions would help.',
      ),
    ],
    totalTime: '4hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/courses/ui-ux.png',
    title: 'UI/UX Design Fundamentals',
    subtitle:
        'Learn the end-to-end product design process — research, wireframes, '
        'prototypes and developer handoff — by rebuilding three real '
        'interfaces from scratch.',
    rating: '4.7',
    level: 'Beginner',
    category: 'Design',
    classLevel: 'Class 9',
    ratingsCount: '(12,480 ratings)',
    studentsEnrolled: '8,214 students enrolled',
    instructorName: 'SkillSikka Design Studio',
    instructorAvatar: 'assets/figma/stlearning/avatar.png',
    lastUpdated: 'Last updated 09/2026',
    languages: 'English, Nepali, Hindi',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Run user interviews and turn the notes into a defensible problem statement',
      'Build low-fidelity wireframes before touching a single colour',
      'Turn wireframes into a clickable prototype your team can test',
      'Hand off to engineering with tokens, spacing and states documented',
    ],
    curriculumSummary: '3 sections • 9 lectures • 6h 18m total length',
    modules: [
      CourseModule('Design thinking and the discovery brief', '48 mins', [
        CourseLesson('What problem are we actually solving', '05:35'),
        CourseLesson('Interviewing users without leading them', '08:20'),
        CourseLesson(
          'Writing a brief you can defend',
          '06:48',
          isPreview: true,
        ),
      ]),
      CourseModule('Wireframing and information architecture', '1h 04m', [
        CourseLesson('From flows to screens', '07:15'),
        CourseLesson('Layout, spacing and grids', '09:32'),
        CourseLesson('Testing a wireframe on paper', '06:26'),
      ]),
      CourseModule('Prototyping, testing and handoff', '52 mins', [
        CourseLesson('Making a prototype that answers a question', '07:04'),
        CourseLesson('What to watch in a usability test', '08:11'),
        CourseLesson('Handoff: tokens, states and redlines', '06:35'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'No design experience needed — we start from first principles',
      'Figma account (the free tier is enough for the whole course)',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 3.0 - August 2026',
        body:
            'Rebuilt the wireframing module around Figma auto-layout and '
            'added a full handoff walkthrough.',
      ),
      CourseDescriptionBlock(heading: 'v 2.0 - March 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'Refreshed the case studies and replaced the old Photoshop '
            'sections with modern component workflows.',
      ),
      CourseDescriptionBlock(
        heading: 'v 1.0 - November 2024',
        body: 'First release covering the core design process end to end.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor.png',
        name: 'Shuvanga Karki',
        title: 'Product Designer | Design Systems | Accessibility',
        rating: '4.5',
        reviews: '11,067',
        students: '68,611',
        courses: '15',
        bio:
            'A product designer who has shipped design systems for fintech '
            'and ed-tech teams, and teaches accessibility as a default rather '
            'than an afterthought.',
      ),
    ],
    courseRating: '4.6',
    ratingBars: [
      RatingBar('5 ★', 64),
      RatingBar('4 ★', 26),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Ajay Badukale',
        when: '11 days ago',
        body:
            'The handoff section alone was worth it. I stopped guessing '
            'spacing and started documenting it.',
      ),
      CourseReview(
        name: 'Sanchita Majumder Ghosh',
        when: '15 days ago',
        body:
            'Clear, practical, and no filler. The wireframing module fixed '
            'habits I had for years.',
      ),
      CourseReview(
        name: 'Flintin VF',
        when: '23 days ago',
        body: 'Good pacing for a beginner. Would like more on accessibility.',
      ),
    ],
    totalTime: '6hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/courses/dm.png',
    title: 'Digital Marketing 101',
    subtitle:
        'Understand how traffic, conversion and retention actually connect, '
        'and build a measurement plan you can defend to a finance team.',
    rating: '4.5',
    level: 'Beginner',
    category: 'Marketing',
    classLevel: 'Class 9',
    ratingsCount: '(7,318 ratings)',
    studentsEnrolled: '5,447 students enrolled',
    instructorName: 'Nabin Singh',
    instructorAvatar: 'assets/figma/instructors/instructor3.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Nepali, Hindi',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Map a funnel and find where you are actually losing people',
      'Choose channels based on unit economics, not vibes',
      'Set up tracking that survives a privacy-conscious browser',
      'Write copy that states a benefit rather than a feature',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 12m total length',
    modules: [
      CourseModule('Funnels, channels and where money goes', '44 mins', [
        CourseLesson('The funnel, without the jargon', '05:22'),
        CourseLesson('Which channel, and why', '07:48'),
        CourseLesson('Unit economics for marketers', '06:30', isPreview: true),
      ]),
      CourseModule('Content, SEO and paid acquisition', '1h 09m', [
        CourseLesson('Writing copy that states a benefit', '07:12'),
        CourseLesson('SEO: what still works', '09:04'),
        CourseLesson('Paid ads and when to switch them off', '08:26'),
      ]),
      CourseModule('Measurement, attribution and reporting', '47 mins', [
        CourseLesson('Tracking in a cookieless world', '06:44'),
        CourseLesson('Attribution, honestly', '07:02'),
        CourseLesson('The one-page report that gets read', '05:18'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'No marketing background required',
      'Access to any website or social account to practise on',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - May 2026',
        body:
            'Rewrote the measurement module around a cookieless world and '
            'added server-side tracking basics.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - September 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering the channel landscape and a starter '
            'measurement framework.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor3.png',
        name: 'Nabin Singh',
        title: 'Growth | Performance Marketing | Analytics',
        rating: '4.4',
        reviews: '6,105',
        students: '38,904',
        courses: '9',
        bio:
            'A growth lead who has run acquisition for marketplaces and '
            'D2C brands, and is openly sceptical of vanity metrics.',
      ),
    ],
    courseRating: '4.4',
    ratingBars: [
      RatingBar('5 ★', 56),
      RatingBar('4 ★', 30),
      RatingBar('3 ★', 9),
      RatingBar('2 ★', 3),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Anita Karki',
        when: '9 days ago',
        body:
            'Finally a marketing course that talks about unit economics '
            'instead of engagement rates.',
      ),
      CourseReview(
        name: 'Rajan Bhattarai',
        when: '3 weeks ago',
        body: 'Practical and honest. The attribution lesson was sobering.',
      ),
      CourseReview(
        name: 'Sarita Lama',
        when: '1 month ago',
        body:
            'Good foundation. I would have liked more on email and lifecycle.',
      ),
    ],
    totalTime: '5hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/courses/cc.png',
    title: 'Cloud Computing Essentials',
    subtitle:
        'What the cloud actually is beneath the console: compute, storage, '
        'networking, identity and the bill that arrives at the end of the month.',
    rating: '4.3',
    level: 'Advanced',
    category: 'Cloud & DevOps',
    classLevel: 'Class 9',
    ratingsCount: '(5,902 ratings)',
    studentsEnrolled: '4,019 students enrolled',
    instructorName: 'Kelsey Hightower',
    instructorAvatar: 'assets/figma/instructors/instructor5.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Explain regions, availability zones and why they shape your design',
      'Pick between object, block and file storage with reasons',
      'Model identity and least privilege before opening a port',
      'Read a cloud bill and find what is quietly costing you money',
    ],
    curriculumSummary: '3 sections • 9 lectures • 6h 55m total length',
    modules: [
      CourseModule('Compute, storage and the network underneath', '1h 02m', [
        CourseLesson('Regions, zones and latency', '06:35'),
        CourseLesson('Object, block and file storage', '08:48'),
        CourseLesson('The network you did not draw', '07:20', isPreview: true),
      ]),
      CourseModule('Identity, IAM and least privilege', '54 mins', [
        CourseLesson('Who is allowed to do what', '06:12'),
        CourseLesson('Roles, policies and the blast radius', '08:30'),
        CourseLesson('Auditing access you forgot about', '05:44'),
      ]),
      CourseModule('Cost, scaling and reliability', '49 mins', [
        CourseLesson('Reading a cloud bill', '06:58'),
        CourseLesson('Scaling out versus scaling up', '07:36'),
        CourseLesson('Designing for failure on purpose', '05:26'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Basic command-line comfort',
      'A cloud free-tier account is helpful but not required',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - April 2026',
        body:
            'Added a full cost-management module and updated the IAM '
            'material for current best practice.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - October 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'Initial release covering the core compute, storage and '
            'networking primitives.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor5.png',
        name: 'Kelsey Hightower',
        title: 'Distributed Systems | Kubernetes | Platform Engineering',
        rating: '4.5',
        reviews: '7,442',
        students: '49,120',
        courses: '13',
        bio:
            'A platform engineer and long-time conference speaker who '
            'explains distributed systems by drawing them on a whiteboard '
            'until they make sense.',
      ),
    ],
    courseRating: '4.3',
    ratingBars: [
      RatingBar('5 ★', 51),
      RatingBar('4 ★', 31),
      RatingBar('3 ★', 11),
      RatingBar('2 ★', 4),
      RatingBar('1 ★', 3),
    ],
    reviews: [
      CourseReview(
        name: 'Sunita Bhandari',
        when: '8 days ago',
        body:
            'The cost module changed how I review our monthly bill. Worth '
            'it for that alone.',
      ),
      CourseReview(
        name: 'Manoj Karki',
        when: '3 weeks ago',
        body:
            'Good conceptual grounding. Light on hands-on labs if that is '
            'what you are after.',
      ),
      CourseReview(
        name: 'Puja Neupane',
        when: '1 month ago',
        body:
            'Clear explanations of networking, which I had always found '
            'intimidating.',
      ),
    ],
    totalTime: '7hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/courses/js.png',
    title: 'JavaScript Masterclass',
    subtitle:
        'Go from syntax to shipping: closures, the event loop, async patterns '
        'and the browser APIs that actually appear in production code.',
    rating: '4.9',
    level: 'Intermediate',
    category: 'Programming',
    classLevel: 'Class 10',
    ratingsCount: '(21,905 ratings)',
    studentsEnrolled: '15,362 students enrolled',
    instructorName: 'Amrit Poudel',
    instructorAvatar: 'assets/figma/instructors/instructor1.png',
    lastUpdated: 'Last updated 10/2026',
    languages: 'English, Nepali',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Explain closures, hoisting and the prototype chain without hand-waving',
      'Trace exactly what the event loop does with your async code',
      'Write `fetch` and `async/await` flows that handle failure properly',
      'Structure a real project with modules instead of one giant script',
    ],
    curriculumSummary: '3 sections • 9 lectures • 9h 42m total length',
    modules: [
      CourseModule('Language fundamentals, done properly', '1h 21m', [
        CourseLesson('Scopes, hoisting and the temporal dead zone', '09:14'),
        CourseLesson('Closures, and where they show up in real code', '10:32'),
        CourseLesson(
          'The prototype chain without the folklore',
          '08:45',
          isPreview: true,
        ),
      ]),
      CourseModule('The event loop and asynchronous JavaScript', '1h 34m', [
        CourseLesson('The call stack, the queue and the loop', '10:08'),
        CourseLesson('Promises from first principles', '11:26'),
        CourseLesson('async/await and error handling that works', '09:52'),
      ]),
      CourseModule('DOM, events and browser APIs', '1h 12m', [
        CourseLesson('Querying and updating the DOM', '08:30'),
        CourseLesson('Events, bubbling and delegation', '09:18'),
        CourseLesson(
          'fetch, storage and the APIs you will actually use',
          '07:44',
        ),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with HTML and CSS',
      'Some programming experience in any language helps but is not required',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 5.0 - June 2026',
        body:
            'Added a full async/await module and rewrote the event-loop '
            'lessons around real stack traces.',
      ),
      CourseDescriptionBlock(heading: 'v 4.0 - January 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'Replaced the jQuery-era DOM lessons with modern query and '
            'event APIs, and added exercises for every section.',
      ),
      CourseDescriptionBlock(
        heading: 'v 3.0 - April 2024',
        body:
            'Expanded the closures material and introduced the project '
            'structure used throughout the back half.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor1.png',
        name: 'Amrit Poudel',
        title: 'App Security | DevSecOps | Automation',
        rating: '4.6',
        reviews: '19,326',
        students: '1,03,287',
        courses: '42',
        bio:
            'With over 10 years of experience in security, automation, '
            'development and cloud architecture, and a habit of explaining '
            'the why before the how.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 78),
      RatingBar('4 ★', 16),
      RatingBar('3 ★', 4),
      RatingBar('2 ★', 1),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Prakash Adhikari',
        when: '4 days ago',
        body:
            'The event loop lesson finally made it click. I have read three '
            'articles on this and none of them landed.',
      ),
      CourseReview(
        name: 'Nisha Thapa',
        when: '12 days ago',
        body:
            'Dense in the best way. I had to pause and take notes, which is '
            'exactly what I wanted.',
      ),
      CourseReview(
        name: 'Bikash Shrestha',
        when: '1 month ago',
        body:
            'Excellent instructor. The async module alone is worth the price.',
      ),
    ],
    totalTime: '9hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/courses/ml.png',
    title: 'Machine Learning Basics',
    subtitle:
        'Build the mental model behind modern ML: what a model actually learns, '
        'how to measure whether it works, and when it will quietly fail you.',
    rating: '4.8',
    level: 'Advanced',
    category: 'Data Science',
    classLevel: 'Class 10',
    ratingsCount: '(9,744 ratings)',
    studentsEnrolled: '6,108 students enrolled',
    instructorName: 'Dr. Ananya Patel',
    instructorAvatar: 'assets/figma/instructors/instructor2.png',
    lastUpdated: 'Last updated 10/2026',
    languages: 'English',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Distinguish training, validation and test error — and why the gap matters',
      'Diagnose overfitting and underfitting from a learning curve',
      'Build a baseline before reaching for a bigger model',
      'Explain a model\'s behaviour well enough to defend it to a stakeholder',
    ],
    curriculumSummary: '3 sections • 9 lectures • 8h 06m total length',
    modules: [
      CourseModule('What learning actually means', '58 mins', [
        CourseLesson('Fitting a line, and what it costs', '07:15'),
        CourseLesson('Loss functions, intuitively', '08:42'),
        CourseLesson(
          'Why a bigger model is not the answer',
          '06:58',
          isPreview: true,
        ),
      ]),
      CourseModule('Regression, classification and loss functions', '1h 26m', [
        CourseLesson('Regression end to end', '10:04'),
        CourseLesson('Classification and decision boundaries', '09:36'),
        CourseLesson('Choosing a loss you can explain', '08:20'),
      ]),
      CourseModule('Evaluation, leakage and honest baselines', '1h 03m', [
        CourseLesson('Train, validation, test — and the gap', '08:12'),
        CourseLesson('Data leakage: how it sneaks in', '09:48'),
        CourseLesson('Building a baseline you cannot beat', '07:06'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Basic Python — variables, loops, functions',
      'High-school algebra; no calculus required',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - July 2026',
        body:
            'Added a dedicated module on data leakage after far too many '
            'learners reported suspiciously good validation scores.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - February 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'Original release covering the core supervised-learning '
            'toolkit with worked examples in scikit-learn.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor2.png',
        name: 'Dr. Ananya Patel',
        title: 'Applied ML | Model Evaluation | Responsible AI',
        rating: '4.7',
        reviews: '8,912',
        students: '54,230',
        courses: '11',
        bio:
            'A researcher turned practitioner who cares more about whether a '
            'model holds up in production than whether it wins a leaderboard.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 71),
      RatingBar('4 ★', 21),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Suman Gurung',
        when: '6 days ago',
        body:
            'The leakage module explained a bug I had been chasing for '
            'months at work. Genuinely useful.',
      ),
      CourseReview(
        name: 'Rita Maharjan',
        when: '18 days ago',
        body: 'Pitched exactly right — rigorous without drowning you in maths.',
      ),
      CourseReview(
        name: 'Dipesh Rai',
        when: '1 month ago',
        body:
            'Wish the coding examples used PyTorch too, but the concepts '
            'transfer fine.',
      ),
    ],
    totalTime: '8hrs',
  ),
  CourseDetailData(
    image: 'assets/figma/courses/react.png',
    title: 'React Native Development',
    subtitle:
        'Ship one codebase to both stores: navigation, state, native modules '
        'and the build pipeline that gets your app onto a device.',
    rating: '4.6',
    level: 'Intermediate',
    category: 'Mobile Development',
    classLevel: 'Class 10',
    ratingsCount: '(10,266 ratings)',
    studentsEnrolled: '7,833 students enrolled',
    instructorName: 'Andrea Bizzotto',
    instructorAvatar: 'assets/figma/instructors/instructor4.png',
    lastUpdated: 'Last updated 10/2026',
    languages: 'English',
    subtitleTracks: 'CC English [Auto]',
    learningOutcomes: [
      'Build a navigation tree that survives deep links and back gestures',
      'Choose between local, lifted and server state without guessing',
      'Reach a native API when no maintained package exists',
      'Produce signed builds for both stores from one codebase',
    ],
    curriculumSummary: '3 sections • 9 lectures • 8h 30m total length',
    modules: [
      CourseModule('Project setup and the render model', '52 mins', [
        CourseLesson(
          'Creating a project that will still build in a year',
          '06:44',
        ),
        CourseLesson('Components, props and the render cycle', '08:30'),
        CourseLesson(
          'Styling and layout in React Native',
          '07:12',
          isPreview: true,
        ),
      ]),
      CourseModule('Navigation, forms and state', '1h 38m', [
        CourseLesson('A navigation tree that survives deep links', '11:05'),
        CourseLesson('Forms, validation and keyboard handling', '10:22'),
        CourseLesson('Local, lifted and server state', '09:40'),
      ]),
      CourseModule('Native modules and release builds', '1h 20m', [
        CourseLesson('Calling a native API from Dart-free JavaScript', '09:15'),
        CourseLesson('Signing and versioning for two stores', '08:48'),
        CourseLesson('Shipping, then fixing what users find', '07:30'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with JavaScript and React basics',
      'A machine able to run an Android or iOS emulator',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 4.0 - September 2026',
        body:
            'Updated for the New Architecture and replaced the old '
            'navigation examples with the current API.',
      ),
      CourseDescriptionBlock(heading: 'v 3.0 - December 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'Added a full release-build section covering signing, '
            'versioning and store submission.',
      ),
      CourseDescriptionBlock(
        heading: 'v 2.0 - May 2025',
        body:
            'Introduced the state-management module and the testing '
            'appendix.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor4.png',
        name: 'Andrea Bizzotto',
        title: 'Mobile Engineer | Flutter and React Native',
        rating: '4.6',
        reviews: '9,881',
        students: '61,447',
        courses: '23',
        bio:
            'A mobile engineer who maintains open-source packages for both '
            'major cross-platform frameworks and writes about the trade-offs '
            'honestly.',
      ),
    ],
    courseRating: '4.6',
    ratingBars: [
      RatingBar('5 ★', 66),
      RatingBar('4 ★', 24),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Kiran Tamang',
        when: '5 days ago',
        body:
            'The release-build section saved me a week of store rejection '
            'emails.',
      ),
      CourseReview(
        name: 'Melina Shrestha',
        when: '2 weeks ago',
        body:
            'Up to date, which is rare. Most React Native courses I tried '
            'were still on the old architecture.',
      ),
      CourseReview(
        name: 'Rohit Joshi',
        when: '1 month ago',
        body:
            'Solid. The state module is opinionated but the reasoning is '
            'explained well.',
      ),
    ],
    totalTime: '8hrs',
  ),
];
