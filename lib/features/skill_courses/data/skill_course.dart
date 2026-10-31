import 'package:flutter/material.dart';

import '../../../core/widgets/course_detail_view.dart';

/// The six "This course includes" rows, identical across the catalogue.
///
/// **Six, not seven.** The `Access on mobile, desktop and TV` row was removed
/// on 2026-10-30 — the app ships on mobile only, so it promised platforms that
/// do not exist.
const _standardIncludes = <CourseInclude>[
  CourseInclude(Icons.play_circle_outline, 'On-demand video, yours to keep'),
  CourseInclude(Icons.quiz_outlined, 'Quizzes after every section'),
  CourseInclude(Icons.description_outlined, 'Downloadable support files'),
  CourseInclude(Icons.article_outlined, 'Written notes for each lesson'),
  CourseInclude(Icons.all_inclusive, 'Full lifetime access'),
  CourseInclude(Icons.verified_outlined, 'Certificate of completion'),
];

/// The skill-course catalogue.
///
/// **Presentation-only**, exactly like [coursePool]. There is no
/// `skill_courses/` API and the dev database has no published courses, so this
/// is static demo content. Wiring it to a real endpoint is a separate task.
///
/// One list serves the whole Skill Courses tab: the "Top Course" carousel shows
/// the filtered pool's **first three**, and the "Course" list shows the whole
/// filtered pool — the same ordering-as-curation the home rail uses over
/// [coursePool]. That is why the strongest three of each skill lead their group.
///
/// [CourseDetailData.category] holds the **skill**, and it must match one of the
/// tab's chip labels exactly (`Coding`, `Drawing`, `Public Speaking`, `Music`) —
/// the chips filter on it. [CourseDetailData.classLevel] is left empty: a skill
/// course is not part of the class-filtered school catalogue.
///
/// Every entry's [CourseDetailData.curriculumSummary] must agree with its
/// `modules`: the section count is `modules.length` and the lecture count is the
/// sum of the lesson lists. `test/skill_course_detail_page_test.dart` asserts
/// both, and that no skill chip is ever empty.
const skillCoursePool = <CourseDetailData>[
  // ── Coding ────────────────────────────────────────────────────────────────
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse.png',
    badge: 'Python',
    title: 'Python for Beginners: Complete Bootcamp 2024',
    subtitle:
        'Start from nothing and finish with working programs — variables, '
        'loops, files, and a small project you built yourself.',
    rating: '4.9',
    level: 'Beginner',
    category: 'Coding',
    price: 'Rs. 1,299',
    ratingsCount: '(12,480 ratings)',
    studentsEnrolled: '32,450 students enrolled',
    instructorName: 'Sagar Adhikari',
    instructorAvatar: 'assets/figma/instructors/instructor1.png',
    lastUpdated: 'Last updated 09/2026',
    languages: 'English, Nepali, Hindi',
    learningOutcomes: [
      'Write and run your own Python programs with confidence',
      'Use lists, dictionaries and loops to hold real data',
      'Read and write files instead of copying values by hand',
      'Break a problem into functions you can test one at a time',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 12m total length',
    modules: [
      CourseModule('Getting started with Python', '1h 04m', [
        CourseLesson('Installing Python and your first script', '06:20'),
        CourseLesson('Variables, numbers and text', '08:45'),
        CourseLesson('Making decisions with if', '09:10', isPreview: true),
      ]),
      CourseModule('Collections and loops', '1h 48m', [
        CourseLesson('Lists: storing many values', '09:30'),
        CourseLesson('Dictionaries and looking things up', '10:15'),
        CourseLesson('for and while, and when to use which', '11:05'),
      ]),
      CourseModule('Functions, files and a small project', '2h 20m', [
        CourseLesson('Writing your own functions', '10:40'),
        CourseLesson('Reading and writing files', '09:55'),
        CourseLesson('Project: a to-do list that saves itself', '14:30'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'A computer you can install Python on — Windows, macOS or Linux',
      'No programming experience needed; we start at the very beginning',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 3.0 - August 2026',
        body:
            'Rewrote every example for Python 3.12 and added the file-handling '
            'section, which was the most requested topic.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - January 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering the basics of syntax, collections and '
            'functions.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor1.png',
        name: 'Sagar Adhikari',
        title: 'Python | Backend Engineering',
        rating: '4.8',
        reviews: '9,340',
        students: '58,120',
        courses: '7',
        bio:
            'A backend engineer who learned to program late and teaches the way '
            'he wishes someone had taught him.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 72),
      RatingBar('4 ★', 19),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Anisha Gurung',
        when: '8 days ago',
        body:
            'I had never written a line of code. The to-do project at the end '
            'made it click.',
      ),
      CourseReview(
        name: 'Rohit Bhandari',
        when: '3 weeks ago',
        body: 'Pace is right for a beginner. Nothing is skipped over.',
      ),
      CourseReview(
        name: 'Sarita Poudel',
        when: '2 months ago',
        body: 'The file section alone was worth the price.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource(
        'Setup Guide for Windows and macOS',
        CourseResourceType.pdf,
      ),
      CourseResource('Python Syntax Reference', CourseResourceType.pdf),
      CourseResource('Practice Exercise Pack', CourseResourceType.doc),
      CourseResource('Project Milestone Tracker', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Kelsey Hightower',
        'Instructor',
        '3h ago',
        'Type every example rather than copying it. The errors you make while typing are the ones that teach you the syntax.',
        isStaff: true,
        reactions: 72,
      ),
      CourseDiscussion(
        'Bishal Rai',
        'Student',
        '2h ago',
        'Should I install an IDE now or stay with the plain editor for the first module?',
        reactions: 18,
      ),
      CourseDiscussion(
        'Anjali Karki',
        'Student',
        '1h ago',
        'The syntax reference is exactly what I needed. Two pages instead of a whole book.',
        reactions: 24,
      ),
      CourseDiscussion(
        'Prabin Shrestha',
        'Student',
        '45m ago',
        'The milestone tracker kept me going. Seeing four of six ticked is oddly motivating.',
        reactions: 16,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse1.png',
    badge: 'React.js',
    title: 'React & Next.js: Full-Stack Web Development',
    subtitle:
        'Build and ship a real web app — components, state, routing, data '
        'fetching, and a deployment you can share.',
    rating: '4.8',
    level: 'Intermediate',
    category: 'Coding',
    price: 'Rs. 1,999',
    ratingsCount: '(7,915 ratings)',
    studentsEnrolled: '21,780 students enrolled',
    instructorName: 'Nisha Thapa',
    instructorAvatar: 'assets/figma/instructors/instructor2.png',
    lastUpdated: 'Last updated 09/2026',
    languages: 'English, Nepali',
    learningOutcomes: [
      'Build interfaces out of components instead of pages',
      'Manage state without losing track of where it lives',
      'Fetch data on the server and render it before the user arrives',
      'Deploy a Next.js app and share a working link',
    ],
    curriculumSummary: '3 sections • 9 lectures • 6h 30m total length',
    modules: [
      CourseModule('React fundamentals', '1h 52m', [
        CourseLesson('Components, props and JSX', '09:40'),
        CourseLesson('State and re-rendering, explained slowly', '11:15'),
        CourseLesson(
          'Lists, keys and conditional UI',
          '08:50',
          isPreview: true,
        ),
      ]),
      CourseModule('Routing, data and forms', '2h 26m', [
        CourseLesson('File-based routing in Next.js', '10:30'),
        CourseLesson('Server components and data fetching', '12:45'),
        CourseLesson('Forms, validation and errors', '11:20'),
      ]),
      CourseModule('Ship it', '2h 12m', [
        CourseLesson('Styling and responsive layout', '10:05'),
        CourseLesson('Environment variables and secrets', '07:40'),
        CourseLesson('Deploying and sharing your app', '09:25'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with HTML, CSS and modern JavaScript',
      'Node.js installed — the setup lecture walks you through it',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - July 2026',
        body:
            'Moved the whole course to the Next.js App Router and added the '
            'server-components section.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - March 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering React fundamentals and client-side data.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor2.png',
        name: 'Nisha Thapa',
        title: 'React | Frontend Architecture',
        rating: '4.7',
        reviews: '6,120',
        students: '34,900',
        courses: '5',
        bio:
            'A frontend engineer who has rebuilt the same dashboard three times '
            'and wants you to do it once, properly.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 66),
      RatingBar('4 ★', 24),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Nabin Shakya',
        when: '12 days ago',
        body: 'The server-components section is the clearest I have found.',
      ),
      CourseReview(
        name: 'Pooja Rana',
        when: '1 month ago',
        body: 'Deployed my first real app at the end. Great feeling.',
      ),
      CourseReview(
        name: 'Kiran Adhikari',
        when: '2 months ago',
        body: 'Assumes you know JavaScript, which it says up front.',
      ),
    ],
    totalTime: '6hrs',
    resources: <CourseResource>[
      CourseResource('App Router Project Template', CourseResourceType.pdf),
      CourseResource('Server Component Patterns', CourseResourceType.pdf),
      CourseResource('API Route Starter', CourseResourceType.doc),
      CourseResource('Deployment Checklist', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Lee Robinson',
        'Instructor',
        '4h ago',
        'Decide where your data is fetched before you write a component. Most of the confusion in this module is really a placement question.',
        isStaff: true,
        reactions: 88,
      ),
      CourseDiscussion(
        'Nishan Gurung',
        'Student',
        '3h ago',
        'When does a client component actually earn its cost? I am marking everything as one.',
        reactions: 31,
      ),
      CourseDiscussion(
        'Rita Maharjan',
        'Student',
        '1h ago',
        'The server component patterns doc is dense but worth reading twice.',
        reactions: 19,
      ),
      CourseDiscussion(
        'Suman Lama',
        'Developer',
        '30m ago',
        'Deployment checklist caught a missing environment variable before our release.',
        reactions: 27,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse2.png',
    badge: 'DSA',
    title: 'Data Structures & Algorithms Masterclass',
    subtitle:
        'The structures and the patterns behind them, with every idea drawn out '
        'before a single line of code.',
    rating: '4.9',
    level: 'Advanced',
    category: 'Coding',
    price: 'Rs. 2,499',
    ratingsCount: '(15,204 ratings)',
    studentsEnrolled: '45,600 students enrolled',
    instructorName: 'Prakash Bhattarai',
    instructorAvatar: 'assets/figma/instructors/instructor3.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Nepali, Hindi',
    learningOutcomes: [
      'Pick the right structure for a problem instead of guessing',
      'Reason about how long an approach will take before coding it',
      'Recognise the handful of patterns behind most interview questions',
      'Implement a hash map, a heap and a graph traversal from scratch',
    ],
    curriculumSummary: '3 sections • 9 lectures • 8h 05m total length',
    modules: [
      CourseModule('Foundations and complexity', '2h 10m', [
        CourseLesson('How to measure an algorithm', '10:20'),
        CourseLesson('Arrays, strings and the cost of moving things', '12:35'),
        CourseLesson('Recursion, drawn step by step', '11:50', isPreview: true),
      ]),
      CourseModule('The core structures', '3h 05m', [
        CourseLesson('Stacks, queues and where they show up', '13:10'),
        CourseLesson('Hash maps, collisions and hashing well', '14:25'),
        CourseLesson('Trees, heaps and priority', '15:40'),
      ]),
      CourseModule('Graphs and problem patterns', '2h 50m', [
        CourseLesson('Traversal: breadth first and depth first', '14:05'),
        CourseLesson('Sorting, and when not to sort', '12:30'),
        CourseLesson(
          'Patterns that repeat across interview questions',
          '16:15',
        ),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable in at least one programming language',
      'Willing to draw problems on paper before writing code',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.1 - June 2026',
        body:
            'Added a pattern-recognition section built from 40 real interview '
            'questions, with the walkthrough for each.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - February 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering complexity, arrays and the core structures.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor3.png',
        name: 'Prakash Bhattarai',
        title: 'Algorithms | Competitive Programming',
        rating: '4.9',
        reviews: '11,880',
        students: '72,340',
        courses: '4',
        bio:
            'A competitive programmer who insists that a picture beats a proof '
            'when you are still learning.',
      ),
    ],
    courseRating: '4.9',
    ratingBars: [
      RatingBar('5 ★', 78),
      RatingBar('4 ★', 16),
      RatingBar('3 ★', 4),
      RatingBar('2 ★', 1),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Sujan Maharjan',
        when: '5 days ago',
        body: 'The drawings are the whole course. I finally see the recursion.',
      ),
      CourseReview(
        name: 'Bibek Neupane',
        when: '3 weeks ago',
        body: 'Dense, but every lecture earns its place.',
      ),
      CourseReview(
        name: 'Rekha Thapa',
        when: '1 month ago',
        body: 'Not for absolute beginners, and it does not pretend to be.',
      ),
    ],
    totalTime: '8hrs',
    resources: <CourseResource>[
      CourseResource('Complexity Cheatsheet', CourseResourceType.pdf),
      CourseResource('Problem Set by Pattern', CourseResourceType.pdf),
      CourseResource('Solution Walkthroughs', CourseResourceType.doc),
      CourseResource('Practice Progress Tracker', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Abdul Bari',
        'Instructor',
        '6h ago',
        'Learn the pattern, not the problem. There are a few hundred problems here and about fifteen patterns.',
        isStaff: true,
        reactions: 104,
      ),
      CourseDiscussion(
        'Kiran Shrestha',
        'Student',
        '4h ago',
        'Is it better to solve a problem again a week later, or move to the next one immediately?',
        reactions: 42,
      ),
      CourseDiscussion(
        'Bipana Thapa',
        'Student',
        '2h ago',
        'The complexity cheatsheet is on my second monitor permanently.',
        reactions: 29,
      ),
      CourseDiscussion(
        'Nabin Rai',
        'Student',
        '1h ago',
        'The pattern grouping is what made this click. Other courses just list problems.',
        reactions: 38,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse3.png',
    badge: 'JavaScript',
    title: 'JavaScript: The Complete Guide',
    subtitle:
        'The language itself — closures, prototypes, async — taught from the '
        'mechanics up, not from a framework.',
    rating: '4.9',
    level: 'Intermediate',
    category: 'Coding',
    price: 'Rs.24.99',
    ratingsCount: '(2,340 ratings)',
    studentsEnrolled: '18,300 students enrolled',
    instructorName: 'Kyle Simpson',
    instructorAvatar: 'assets/figma/instructors/instructor4.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English',
    learningOutcomes: [
      'Explain scope and closures without hand-waving',
      'Understand what `this` actually binds to, and why',
      'Write async code you can reason about instead of guessing',
      'Read someone else\'s JavaScript without fear',
    ],
    curriculumSummary: '3 sections • 9 lectures • 7h 20m total length',
    modules: [
      CourseModule('Scope and closures', '2h 24m', [
        CourseLesson('Lexical scope, from the ground up', '12:10'),
        CourseLesson('Closures, with examples you will actually meet', '13:45'),
        CourseLesson(
          'The module pattern and why it still matters',
          '11:30',
          isPreview: true,
        ),
      ]),
      CourseModule('Objects, prototypes and this', '2h 38m', [
        CourseLesson('Objects and property lookup', '11:55'),
        CourseLesson('Prototypes and inheritance for real', '14:20'),
        CourseLesson('`this` in four rules', '12:05'),
      ]),
      CourseModule('Async JavaScript', '2h 18m', [
        CourseLesson('The event loop, drawn out', '13:15'),
        CourseLesson('Promises and error handling', '12:40'),
        CourseLesson('async/await and the mistakes it hides', '11:50'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Some prior exposure to any programming language',
      'A browser and a text editor — no build tooling required',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.4 - May 2026',
        body: 'Re-recorded the async section and added the event-loop diagram.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - April 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering scope, closures and prototypes.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor4.png',
        name: 'Kyle Simpson',
        title: 'JavaScript | Language Mechanics',
        rating: '4.9',
        reviews: '2,110',
        students: '26,780',
        courses: '6',
        bio:
            'A long-time JavaScript teacher who would rather explain one idea '
            'properly than name ten.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 70),
      RatingBar('4 ★', 21),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Asmita Rana',
        when: '9 days ago',
        body:
            'Closures finally stopped being magic. That was the point for me.',
      ),
      CourseReview(
        name: 'Dipesh Gurung',
        when: '1 month ago',
        body: 'Deep but never slow. Worth rewatching the async section.',
      ),
      CourseReview(
        name: 'Nirmala Rai',
        when: '2 months ago',
        body: 'Not a framework course, and better for it.',
      ),
    ],
    totalTime: '7hrs',
    resources: <CourseResource>[
      CourseResource('Language Reference Card', CourseResourceType.pdf),
      CourseResource('Closure and Scope Workbook', CourseResourceType.pdf),
      CourseResource('DOM Exercise Pack', CourseResourceType.doc),
      CourseResource('Project Tracker', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Maximilian Weber',
        'Instructor',
        '5h ago',
        'Closures are not a trick, they are what happens when a function remembers where it was written. Read the workbook in that light.',
        isStaff: true,
        reactions: 76,
      ),
      CourseDiscussion(
        'Puja Adhikari',
        'Student',
        '3h ago',
        'Why does var behave differently inside a loop? The scope workbook touches it but I want more.',
        reactions: 33,
      ),
      CourseDiscussion(
        'Anil Basnet',
        'Student',
        '2h ago',
        'The reference card is the one file I print. Everything else I read on screen.',
        reactions: 21,
      ),
      CourseDiscussion(
        'Sneha Rai',
        'Student',
        '40m ago',
        'DOM exercises were more fun than I expected.',
        reactions: 12,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse4.png',
    badge: 'Node.js',
    title: 'Node.js Backend Development',
    subtitle:
        'Build an API you would be happy to run in production — routing, '
        'validation, auth and a real database.',
    rating: '4.7',
    level: 'Intermediate',
    category: 'Coding',
    price: 'Rs.19.99',
    ratingsCount: '(1,456 ratings)',
    studentsEnrolled: '12,940 students enrolled',
    instructorName: 'Sarah Chen',
    instructorAvatar: 'assets/figma/instructors/instructor5.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English',
    learningOutcomes: [
      'Structure an Express app so it can grow past one file',
      'Validate input at the edge instead of trusting the client',
      'Add authentication without rolling your own crypto',
      'Talk to a database and handle the failures properly',
    ],
    curriculumSummary: '3 sections • 9 lectures • 6h 05m total length',
    modules: [
      CourseModule('The Node runtime and Express', '1h 58m', [
        CourseLesson('What Node actually is, and is not', '10:15'),
        CourseLesson('Routing and middleware', '12:30'),
        CourseLesson('Splitting an app into layers', '11:05', isPreview: true),
      ]),
      CourseModule('Validation, auth and errors', '2h 12m', [
        CourseLesson('Validating request bodies', '11:40'),
        CourseLesson('Sessions, tokens and what to store', '13:25'),
        CourseLesson('One error handler, everywhere', '09:50'),
      ]),
      CourseModule('Persistence and shipping', '1h 55m', [
        CourseLesson('Querying a database from Node', '12:20'),
        CourseLesson('Migrations and seed data', '10:35'),
        CourseLesson('Logging and graceful shutdown', '09:15'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with JavaScript, including async/await',
      'A terminal you are not afraid of',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.2 - April 2026',
        body: 'Added the database migrations section and updated all examples.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - June 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering Express, routing and middleware.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor5.png',
        name: 'Sarah Chen',
        title: 'Node.js | API Design',
        rating: '4.7',
        reviews: '1,320',
        students: '19,450',
        courses: '3',
        bio:
            'A backend engineer who reviews APIs for a living and is allergic to '
            'endpoints that lie about their status codes.',
      ),
    ],
    courseRating: '4.6',
    ratingBars: [
      RatingBar('5 ★', 60),
      RatingBar('4 ★', 28),
      RatingBar('3 ★', 8),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Sandesh Karki',
        when: '2 weeks ago',
        body: 'The layered structure section changed how I organise projects.',
      ),
      CourseReview(
        name: 'Rita Shrestha',
        when: '1 month ago',
        body: 'Good pace. The error-handling lecture is excellent.',
      ),
      CourseReview(
        name: 'Manoj Lama',
        when: '3 months ago',
        body: 'Would like more on testing, but everything else is solid.',
      ),
    ],
    totalTime: '6hrs',
    resources: <CourseResource>[
      CourseResource('Project Structure Guide', CourseResourceType.pdf),
      CourseResource('Middleware Patterns Reference', CourseResourceType.pdf),
      CourseResource('API Testing Collection', CourseResourceType.doc),
      CourseResource('Environment Setup Sheet', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Brad Traversy',
        'Instructor',
        '4h ago',
        'Keep your error handling in one place from the start. Retrofitting it into a grown project is miserable.',
        isStaff: true,
        reactions: 61,
      ),
      CourseDiscussion(
        'Rajan Shrestha',
        'Student',
        '2h ago',
        'How much validation belongs in middleware versus the route handler?',
        reactions: 24,
      ),
      CourseDiscussion(
        'Muna Gurung',
        'Student',
        '1h ago',
        'The API testing collection meant I stopped writing throwaway curl commands.',
        reactions: 18,
      ),
      CourseDiscussion(
        'Dipesh Rai',
        'Backend Developer',
        '35m ago',
        'The structure guide matches what we settled on after two years. Good starting point.',
        reactions: 31,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse5.png',
    badge: 'TypeScript',
    title: 'TypeScript Advanced Patterns',
    subtitle:
        'Beyond annotations: generics, inference and types that make illegal '
        'states impossible to represent.',
    rating: '4.8',
    level: 'Advanced',
    category: 'Coding',
    price: 'Rs.29.99',
    ratingsCount: '(987 ratings)',
    studentsEnrolled: '8,420 students enrolled',
    instructorName: 'Matt Pocock',
    instructorAvatar: 'assets/figma/instructors/instructor6.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English',
    learningOutcomes: [
      'Write generic functions instead of copy-pasting signatures',
      'Let inference do the work instead of annotating everything',
      'Model a state machine as a union so bad states cannot compile',
      'Debug a type error instead of reaching for `any`',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 48m total length',
    modules: [
      CourseModule('Types that do work', '1h 52m', [
        CourseLesson('Unions, literals and narrowing', '10:40'),
        CourseLesson('Generics from first principles', '12:25'),
        CourseLesson(
          'Inference: when to write it, when to leave it',
          '10:15',
          isPreview: true,
        ),
      ]),
      CourseModule('Advanced modelling', '2h 04m', [
        CourseLesson('Conditional and mapped types', '13:10'),
        CourseLesson('Template literal types', '11:35'),
        CourseLesson('Discriminated unions as state machines', '12:50'),
      ]),
      CourseModule('Working at scale', '1h 52m', [
        CourseLesson('Type-safe API boundaries', '11:20'),
        CourseLesson('Reading a gnarly type error', '10:45'),
        CourseLesson('When `any` is the honest answer', '09:30'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Solid JavaScript, including destructuring and async',
      'Some prior TypeScript — this is not an introduction',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - June 2026',
        body:
            'Rebuilt around TypeScript 5.5 and added the type-error reading '
            'section.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - September 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering generics and narrowing.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor6.png',
        name: 'Matt Pocock',
        title: 'TypeScript | Developer Experience',
        rating: '4.8',
        reviews: '890',
        students: '14,200',
        courses: '4',
        bio:
            'A TypeScript educator who treats the compiler as a collaborator '
            'rather than an obstacle.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 68),
      RatingBar('4 ★', 22),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Prabin Joshi',
        when: '1 week ago',
        body: 'The discriminated-union lecture is worth the whole course.',
      ),
      CourseReview(
        name: 'Sunita Magar',
        when: '1 month ago',
        body: 'Finally stopped sprinkling `any` everywhere.',
      ),
      CourseReview(
        name: 'Aakash Tamang',
        when: '2 months ago',
        body: 'Advanced is accurate. Brush up on basics first.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource('Type Utility Reference', CourseResourceType.pdf),
      CourseResource('Generics Workbook', CourseResourceType.pdf),
      CourseResource('Refactor Exercises', CourseResourceType.doc),
      CourseResource('Migration Checklist', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Matt Pocock',
        'Instructor',
        '5h ago',
        'If a type needs a comment to explain it, it is probably doing too much. That is most of this module in one sentence.',
        isStaff: true,
        reactions: 92,
      ),
      CourseDiscussion(
        'Sagar Karki',
        'Student',
        '3h ago',
        'When should I reach for a conditional type instead of an overload?',
        reactions: 36,
      ),
      CourseDiscussion(
        'Rita Shrestha',
        'Student',
        '2h ago',
        'The type utility reference is the best organised one I have found.',
        reactions: 25,
      ),
      CourseDiscussion(
        'Bikash Lama',
        'Developer',
        '1h ago',
        'The migration checklist is what we actually used to move our codebase over.',
        reactions: 29,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse6.png',
    badge: 'Django',
    title: 'Django & REST API Masterclass',
    subtitle:
        'Models, views, serializers and permissions — the whole path from an '
        'idea to an API other people can use.',
    rating: '4.9',
    level: 'Intermediate',
    category: 'Coding',
    price: 'Rs.34.99',
    ratingsCount: '(1,890 ratings)',
    studentsEnrolled: '15,670 students enrolled',
    instructorName: 'Prof. Amir Khan',
    instructorAvatar: 'assets/figma/instructors/instructor7.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Hindi',
    learningOutcomes: [
      'Model a domain in Django and migrate it safely',
      'Expose it through a REST API with clean serializers',
      'Get permissions right instead of hiding endpoints',
      'Write tests that catch the bugs you actually ship',
    ],
    curriculumSummary: '3 sections • 9 lectures • 7h 02m total length',
    modules: [
      CourseModule('Models and the admin', '2h 15m', [
        CourseLesson('Setting up a project and an app', '10:50'),
        CourseLesson('Models, fields and relationships', '13:30'),
        CourseLesson('Migrations without fear', '11:20', isPreview: true),
      ]),
      CourseModule('Views, serializers and the API', '2h 35m', [
        CourseLesson('Class-based views and what they hide', '12:40'),
        CourseLesson('Serializers and nested data', '14:10'),
        CourseLesson('Filtering, pagination and search', '13:05'),
      ]),
      CourseModule('Auth, permissions and tests', '2h 12m', [
        CourseLesson('Authentication schemes', '12:15'),
        CourseLesson('Object-level permissions', '11:50'),
        CourseLesson('Testing endpoints properly', '13:35'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with Python, including classes',
      'Basic familiarity with HTTP and JSON',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.3 - July 2026',
        body: 'Updated to Django 5 and expanded the permissions section.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - May 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering models, views and serializers.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor7.png',
        name: 'Prof. Amir Khan',
        title: 'Django | Web Frameworks',
        rating: '4.8',
        reviews: '1,650',
        students: '23,110',
        courses: '5',
        bio:
            'A professor who has taught Django for a decade and still starts '
            'every course with the data model.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 71),
      RatingBar('4 ★', 20),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Bimala Koirala',
        when: '6 days ago',
        body: 'Permissions are usually skipped. Here they get a whole section.',
      ),
      CourseReview(
        name: 'Gaurav Singh',
        when: '3 weeks ago',
        body: 'Clear, methodical, no hand-waving.',
      ),
      CourseReview(
        name: 'Nisha Bista',
        when: '2 months ago',
        body: 'The testing lecture paid for itself in a week.',
      ),
    ],
    totalTime: '7hrs',
    resources: <CourseResource>[
      CourseResource('Project Boilerplate Guide', CourseResourceType.pdf),
      CourseResource('Serializer Patterns Reference', CourseResourceType.pdf),
      CourseResource('Postman Collection', CourseResourceType.doc),
      CourseResource('Deployment Checklist', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'William Vincent',
        'Instructor',
        '6h ago',
        'Read the OpenAPI schema your own API generates. It is the fastest way to find a field you named inconsistently.',
        isStaff: true,
        reactions: 54,
      ),
      CourseDiscussion(
        'Anish Thapa',
        'Student',
        '3h ago',
        'Should serializers do validation, or is that the model layer?',
        reactions: 27,
      ),
      CourseDiscussion(
        'Priya Maharjan',
        'Student',
        '2h ago',
        'The boilerplate guide saved me a day of setup.',
        reactions: 16,
      ),
      CourseDiscussion(
        'Suraj Basnet',
        'Backend Developer',
        '1h ago',
        'The serializer reference is more useful than the official docs for everyday work.',
        reactions: 33,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse7.png',
    badge: 'Flutter',
    title: 'Flutter Mobile App Development',
    subtitle:
        'One codebase, two stores. Widgets, layout, state and the platform '
        'channels you will eventually need.',
    rating: '4.8',
    level: 'Intermediate',
    category: 'Coding',
    price: 'Rs.22.99',
    ratingsCount: '(2,103 ratings)',
    studentsEnrolled: '14,560 students enrolled',
    instructorName: 'Andrea Bizzotto',
    instructorAvatar: 'assets/figma/instructors/instructor1.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English',
    learningOutcomes: [
      'Compose a screen out of widgets instead of nesting blindly',
      'Choose a state-management approach and stick with it',
      'Handle navigation, forms and lists the idiomatic way',
      'Reach platform APIs through a channel when no package exists',
    ],
    curriculumSummary: '3 sections • 9 lectures • 6h 18m total length',
    modules: [
      CourseModule('Widgets and layout', '2h 05m', [
        CourseLesson('Stateless, stateful and when it matters', '10:55'),
        CourseLesson('Rows, columns and the overflow you will hit', '12:30'),
        CourseLesson(
          'Themes, text styles and design tokens',
          '11:15',
          isPreview: true,
        ),
      ]),
      CourseModule('State, navigation and data', '2h 22m', [
        CourseLesson('Lifting state without losing it', '12:05'),
        CourseLesson('Routing and passing arguments', '11:40'),
        CourseLesson('Fetching data and showing errors', '13:20'),
      ]),
      CourseModule('Platforms and shipping', '1h 51m', [
        CourseLesson('Platform channels, explained simply', '11:35'),
        CourseLesson('Build flavours and environment config', '10:20'),
        CourseLesson('Signing and releasing to a store', '10:05'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with Dart or a similar object-oriented language',
      'The Flutter SDK installed — the setup lecture covers it',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - May 2026',
        body:
            'Updated for the latest stable Flutter and rebuilt the state section.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - August 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering widgets, layout and navigation.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor1.png',
        name: 'Andrea Bizzotto',
        title: 'Flutter | Mobile Engineering',
        rating: '4.8',
        reviews: '1,940',
        students: '31,200',
        courses: '5',
        bio:
            'A mobile engineer who writes Flutter for a living and teaches the '
            'patterns that survived contact with production.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 67),
      RatingBar('4 ★', 23),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Sabina Ale',
        when: '10 days ago',
        body: 'The overflow lecture saved me a whole afternoon.',
      ),
      CourseReview(
        name: 'Ujjwal Pradhan',
        when: '1 month ago',
        body: 'Platform channels finally make sense.',
      ),
      CourseReview(
        name: 'Melina Shakya',
        when: '2 months ago',
        body: 'Good, though the store release section is brief.',
      ),
    ],
    totalTime: '6hrs',
    resources: <CourseResource>[
      CourseResource('Widget Tree Reference', CourseResourceType.pdf),
      CourseResource('State Management Guide', CourseResourceType.pdf),
      CourseResource('Platform Setup Sheet', CourseResourceType.doc),
      CourseResource('Release Checklist', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Filip Hracek',
        'Instructor',
        '4h ago',
        'Look at a layout with the debug paint on before you start moving numbers around. Half the bugs are a missing Expanded.',
        isStaff: true,
        reactions: 68,
      ),
      CourseDiscussion(
        'Niraj Shrestha',
        'Student',
        '2h ago',
        'How do I choose between Provider and Riverpod for a small app?',
        reactions: 31,
      ),
      CourseDiscussion(
        'Sushmita Rai',
        'Student',
        '1h ago',
        'The widget tree reference finally made the build method make sense.',
        reactions: 22,
      ),
      CourseDiscussion(
        'Ashish Gurung',
        'Mobile Developer',
        '40m ago',
        'The release checklist is short and it is the right five things.',
        reactions: 26,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse8.png',
    badge: 'Git',
    title: 'Git & GitHub for Teams',
    subtitle:
        'Branches, merges and the recovery commands — so a bad afternoon stops '
        'being a bad week.',
    rating: '4.7',
    level: 'Beginner',
    category: 'Coding',
    price: 'Rs.14.99',
    ratingsCount: '(3,210 ratings)',
    studentsEnrolled: '21,080 students enrolled',
    instructorName: 'Scott Chacon',
    instructorAvatar: 'assets/figma/instructors/instructor2.png',
    lastUpdated: 'Last updated 06/2026',
    languages: 'English',
    learningOutcomes: [
      'Explain what a commit actually is',
      'Branch, merge and resolve conflicts without panic',
      'Undo almost anything — including a pushed mistake',
      'Run a review workflow on GitHub that a team can follow',
    ],
    curriculumSummary: '3 sections • 9 lectures • 4h 22m total length',
    modules: [
      CourseModule('The mental model', '1h 18m', [
        CourseLesson('Snapshots, not diffs', '09:10'),
        CourseLesson('The three trees: working, index, HEAD', '10:45'),
        CourseLesson('Your first commits', '07:30', isPreview: true),
      ]),
      CourseModule('Branching and merging', '1h 40m', [
        CourseLesson('Branches are just pointers', '10:05'),
        CourseLesson('Merging and reading a conflict', '12:20'),
        CourseLesson('Rebasing, and when not to', '11:15'),
      ]),
      CourseModule('Recovery and collaboration', '1h 24m', [
        CourseLesson('Undoing: reset, revert and restore', '12:40'),
        CourseLesson('Pull requests and review etiquette', '09:55'),
        CourseLesson('Fixing the mistake you already pushed', '10:30'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'No prior Git experience assumed',
      'A GitHub account for the collaboration section',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.2 - March 2026',
        body: 'Added the recovery section and modernised the command set.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - July 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering commits, branches and merging.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor2.png',
        name: 'Scott Chacon',
        title: 'Git | Developer Tooling',
        rating: '4.7',
        reviews: '2,980',
        students: '40,110',
        courses: '3',
        bio:
            'A developer-tools author who has watched a thousand people fear '
            '`reset --hard` and would like to end that.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 64),
      RatingBar('4 ★', 25),
      RatingBar('3 ★', 7),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Hari Bahadur Thapa',
        when: '2 weeks ago',
        body: 'I no longer copy-paste Git commands from the internet.',
      ),
      CourseReview(
        name: 'Sneha Karki',
        when: '1 month ago',
        body: 'The three-trees explanation is the clearest I have seen.',
      ),
      CourseReview(
        name: 'Roshan Maharjan',
        when: '3 months ago',
        body: 'Short and dense. Perfect length for Git.',
      ),
    ],
    totalTime: '4hrs',
    resources: <CourseResource>[
      CourseResource('Branching Model Guide', CourseResourceType.pdf),
      CourseResource('Conflict Resolution Walkthrough', CourseResourceType.pdf),
      CourseResource('Pull Request Template', CourseResourceType.doc),
      CourseResource('Repository Setup Checklist', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Scott Chacon',
        'Instructor',
        '3h ago',
        'Never stash as a habit. Commit to a branch instead — a stash is the one place work goes to be forgotten.',
        isStaff: true,
        reactions: 81,
      ),
      CourseDiscussion(
        'Kritika Bhandari',
        'Student',
        '2h ago',
        'What is the difference between rebase and merge for a shared branch?',
        reactions: 34,
      ),
      CourseDiscussion(
        'Nabin Thapa',
        'Student',
        '1h ago',
        'The PR template stopped our reviews turning into style arguments.',
        reactions: 19,
      ),
      CourseDiscussion(
        'Sunita Karki',
        'Team Lead',
        '30m ago',
        'The branching guide is what we handed to two new hires this month.',
        reactions: 28,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse9.png',
    badge: 'SQL',
    title: 'SQL & Database Design',
    subtitle:
        'Query what you have, then design what you should have — from a single '
        'table to a schema that stays fast.',
    rating: '4.9',
    level: 'Beginner',
    category: 'Coding',
    price: 'Rs.27.99',
    ratingsCount: '(1,678 ratings)',
    studentsEnrolled: '13,250 students enrolled',
    instructorName: 'Dr. Lisa Nguyen',
    instructorAvatar: 'assets/figma/instructors/instructor3.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English',
    learningOutcomes: [
      'Write joins you can explain, not just ones that run',
      'Group and filter to answer a real business question',
      'Design a schema that does not fight you later',
      'Read a query plan well enough to spot the problem',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 40m total length',
    modules: [
      CourseModule('Querying one table', '1h 45m', [
        CourseLesson('SELECT, WHERE and the order they run in', '10:20'),
        CourseLesson('Sorting, limiting and paging', '08:55'),
        CourseLesson('Aggregates and GROUP BY', '11:30', isPreview: true),
      ]),
      CourseModule('Joins and real questions', '1h 58m', [
        CourseLesson('Inner, left and the rows you lose', '12:15'),
        CourseLesson('Subqueries and common table expressions', '12:50'),
        CourseLesson('Answering a question in one query', '11:25'),
      ]),
      CourseModule('Design and performance', '1h 57m', [
        CourseLesson('Normalisation, up to the point it helps', '12:05'),
        CourseLesson('Indexes and what they cost', '11:40'),
        CourseLesson('Reading a query plan', '10:35'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'No SQL experience needed',
      'A machine that can run a local database, or any online sandbox',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.5 - June 2026',
        body: 'Added the query-plan section and rewrote every example dataset.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - October 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering queries, joins and basic design.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor3.png',
        name: 'Dr. Lisa Nguyen',
        title: 'Databases | Data Modelling',
        rating: '4.9',
        reviews: '1,540',
        students: '22,900',
        courses: '4',
        bio:
            'A database specialist who would rather you understood one join '
            'than memorised ten functions.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 73),
      RatingBar('4 ★', 18),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Anita Bhattarai',
        when: '7 days ago',
        body: 'Indexes finally make sense as a trade-off, not a rule.',
      ),
      CourseReview(
        name: 'Sanjay Rai',
        when: '2 months ago',
        body: 'The join section alone is worth it.',
      ),
      CourseReview(
        name: 'Laxmi Poudel',
        when: '3 months ago',
        body: 'Very clear. Would like a second course on administration.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource('Schema Design Workbook', CourseResourceType.pdf),
      CourseResource('Query Reference Card', CourseResourceType.pdf),
      CourseResource('Sample Database Dump', CourseResourceType.doc),
      CourseResource('Index Planning Sheet', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Markus Winand',
        'Instructor',
        '5h ago',
        'Write the query, then read the execution plan. Guessing at performance is how slow queries survive review.',
        isStaff: true,
        reactions: 59,
      ),
      CourseDiscussion(
        'Sabina Maharjan',
        'Student',
        '3h ago',
        'How far should normalisation go before it starts hurting read performance?',
        reactions: 28,
      ),
      CourseDiscussion(
        'Rohit Shrestha',
        'Student',
        '2h ago',
        'The schema workbook is the first design exercise that felt like real work.',
        reactions: 17,
      ),
      CourseDiscussion(
        'Anita Rai',
        'Data Engineer',
        '1h ago',
        'The index planning sheet is the one I keep coming back to.',
        reactions: 30,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse10.png',
    badge: 'Docker',
    title: 'Docker & Kubernetes Essentials',
    subtitle:
        'Package an app so it runs anywhere, then run many of them without '
        'doing it by hand.',
    rating: '4.8',
    level: 'Intermediate',
    category: 'Coding',
    price: 'Rs.32.99',
    ratingsCount: '(945 ratings)',
    studentsEnrolled: '9,870 students enrolled',
    instructorName: 'Kelsey Hightower',
    instructorAvatar: 'assets/figma/instructors/instructor4.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English',
    learningOutcomes: [
      'Write a Dockerfile that produces a small, safe image',
      'Run several services together and have them find each other',
      'Deploy to Kubernetes and understand what a pod really is',
      'Debug a container that starts and then dies',
    ],
    curriculumSummary: '3 sections • 9 lectures • 6h 45m total length',
    modules: [
      CourseModule('Images and containers', '2h 10m', [
        CourseLesson('What a container is, precisely', '11:15'),
        CourseLesson('Writing a Dockerfile properly', '13:40'),
        CourseLesson('Volumes and networks', '12:20', isPreview: true),
      ]),
      CourseModule('Composing services', '2h 15m', [
        CourseLesson('Multi-service apps with Compose', '12:50'),
        CourseLesson('Configuration and secrets', '11:05'),
        CourseLesson('Build pipelines that are reproducible', '12:35'),
      ]),
      CourseModule('Kubernetes essentials', '2h 20m', [
        CourseLesson('Pods, deployments and services', '13:20'),
        CourseLesson('Scaling and rolling updates', '12:10'),
        CourseLesson('Debugging a failing pod', '11:45'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable on the command line',
      'Some experience deploying an application, however simply',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.1 - July 2026',
        body: 'Added the pod-debugging section and updated all manifests.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - November 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering images, containers and Compose.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor4.png',
        name: 'Kelsey Hightower',
        title: 'Containers | Platform Engineering',
        rating: '4.8',
        reviews: '910',
        students: '17,640',
        courses: '3',
        bio:
            'A platform engineer who believes containers are boring on purpose '
            'and prefers to keep them that way.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 68),
      RatingBar('4 ★', 22),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Prakash Rimal',
        when: '9 days ago',
        body: 'The failing-pod lecture is exactly what work needed.',
      ),
      CourseReview(
        name: 'Shreya Basnet',
        when: '6 weeks ago',
        body: 'Compose section is very practical.',
      ),
      CourseReview(
        name: 'Nischal Adhikari',
        when: '2 months ago',
        body: 'Kubernetes is a big topic; this is a good honest slice of it.',
      ),
    ],
    totalTime: '6hrs',
    resources: <CourseResource>[
      CourseResource('Dockerfile Best Practices', CourseResourceType.pdf),
      CourseResource('Compose Reference', CourseResourceType.pdf),
      CourseResource('Cluster Setup Walkthrough', CourseResourceType.doc),
      CourseResource('Resource Planning Sheet', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Liz Rice',
        'Instructor',
        '6h ago',
        'Start with the smallest base image you can run. Most bloated images were bloated on the first day, not over time.',
        isStaff: true,
        reactions: 71,
      ),
      CourseDiscussion(
        'Prakash Thapa',
        'Student',
        '3h ago',
        'When does a cluster become worth it over a single container?',
        reactions: 26,
      ),
      CourseDiscussion(
        'Bina Shrestha',
        'Student',
        '2h ago',
        'The Compose reference is what I actually use day to day.',
        reactions: 15,
      ),
      CourseDiscussion(
        'Sagar Rai',
        'DevOps Engineer',
        '1h ago',
        'The resource planning sheet is a good reminder that requests and limits are not the same thing.',
        reactions: 34,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/skillcourse/skillcourse11.png',
    badge: 'Machine Learning',
    title: 'Machine Learning with Python',
    subtitle:
        'Fit, evaluate and explain a model — the honest workflow, with the '
        'statistics you need and no more.',
    rating: '4.9',
    level: 'Advanced',
    category: 'Coding',
    price: 'Rs.39.99',
    ratingsCount: '(4,512 ratings)',
    studentsEnrolled: '27,340 students enrolled',
    instructorName: 'Dr. Ananya Patel',
    instructorAvatar: 'assets/figma/instructors/instructor5.png',
    lastUpdated: 'Last updated 09/2026',
    languages: 'English, Hindi',
    learningOutcomes: [
      'Prepare messy data without leaking the test set',
      'Pick a model for a problem rather than the trendiest one',
      'Evaluate honestly, including when your metric lies',
      'Explain a prediction to someone who does not code',
    ],
    curriculumSummary: '3 sections • 9 lectures • 8h 20m total length',
    modules: [
      CourseModule('Data and the workflow', '2h 30m', [
        CourseLesson('The honest machine-learning workflow', '12:40'),
        CourseLesson('Cleaning and feature preparation', '14:05'),
        CourseLesson(
          'Splitting data without fooling yourself',
          '12:35',
          isPreview: true,
        ),
      ]),
      CourseModule('Models that matter', '3h 05m', [
        CourseLesson('Regression, and what it assumes', '14:20'),
        CourseLesson('Classification and decision boundaries', '15:10'),
        CourseLesson('Trees and ensembles', '13:55'),
      ]),
      CourseModule('Evaluation and explanation', '2h 45m', [
        CourseLesson('Metrics, and which one to trust', '13:30'),
        CourseLesson('Overfitting and regularisation', '12:45'),
        CourseLesson('Explaining a model to a human', '14:15'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Comfortable with Python and basic algebra',
      'No prior machine learning — but this is not a first programming course',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 2.0 - August 2026',
        body:
            'Rebuilt around scikit-learn 1.5 and added the model-explanation section.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - December 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering the workflow and the core model families.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor5.png',
        name: 'Dr. Ananya Patel',
        title: 'Machine Learning | Applied Statistics',
        rating: '4.9',
        reviews: '4,180',
        students: '49,600',
        courses: '5',
        bio:
            'An applied scientist who spends more time on evaluation than on '
            'modelling, and thinks you should too.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 74),
      RatingBar('4 ★', 18),
      RatingBar('3 ★', 5),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Rajesh Khadka',
        when: '4 days ago',
        body: 'The data-leakage lecture is something every tutorial skips.',
      ),
      CourseReview(
        name: 'Pratiksha Subedi',
        when: '5 weeks ago',
        body: 'Honest about what ML cannot do. Refreshing.',
      ),
      CourseReview(
        name: 'Sameer Lama',
        when: '3 months ago',
        body: 'Dense and worth it. Bring your notebook.',
      ),
    ],
    totalTime: '8hrs',
    resources: <CourseResource>[
      CourseResource('Notebook Starter Pack', CourseResourceType.pdf),
      CourseResource('Feature Engineering Guide', CourseResourceType.pdf),
      CourseResource('Model Comparison Sheet', CourseResourceType.xls),
      CourseResource('Experiment Log Template', CourseResourceType.doc),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Andreas Mueller',
        'Instructor',
        '5h ago',
        'Fit your preprocessing on the training fold only. Leaking the test set through a scaler is the most common silent mistake here.',
        isStaff: true,
        reactions: 87,
      ),
      CourseDiscussion(
        'Nisha Basnet',
        'Student',
        '3h ago',
        'How do I know when to stop tuning and accept the model I have?',
        reactions: 39,
      ),
      CourseDiscussion(
        'Rajesh Karki',
        'Student',
        '2h ago',
        'The model comparison sheet made it obvious which of mine was actually better.',
        reactions: 21,
      ),
      CourseDiscussion(
        'Sujata Rai',
        'Data Scientist',
        '1h ago',
        'The experiment log template is now part of our team process.',
        reactions: 32,
      ),
    ],
  ),
  // ── Drawing ───────────────────────────────────────────────────────────────
  CourseDetailData(
    image: 'assets/figma/courses/ui-ux.png',
    badge: 'Sketching',
    title: 'Sketching Foundations: Line, Light & Form',
    subtitle:
        'Learn to see before you learn to draw — proportion, perspective and '
        'light, with a pencil and no eraser.',
    rating: '4.7',
    level: 'Beginner',
    category: 'Drawing',
    price: 'Rs. 999',
    ratingsCount: '(2,145 ratings)',
    studentsEnrolled: '11,320 students enrolled',
    instructorName: 'Anjali Rai',
    instructorAvatar: 'assets/figma/instructors/instructor6.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English, Nepali',
    learningOutcomes: [
      'Measure a subject by eye instead of guessing at it',
      'Build a form from simple shapes before adding detail',
      'Shade so a shape reads as solid, not as a grey patch',
      'Keep a sketchbook habit that survives a busy week',
    ],
    curriculumSummary: '3 sections • 9 lectures • 4h 35m total length',
    modules: [
      CourseModule('Learning to see', '1h 30m', [
        CourseLesson('Why copying holds you back', '09:40'),
        CourseLesson('Measuring: thumb, pencil and grid', '11:15'),
        CourseLesson(
          'Gesture drawing in ninety seconds',
          '10:05',
          isPreview: true,
        ),
      ]),
      CourseModule('Form and perspective', '1h 45m', [
        CourseLesson('Boxes first, always', '11:30'),
        CourseLesson('One and two point perspective', '12:40'),
        CourseLesson('Ellipses and rounded forms', '10:50'),
      ]),
      CourseModule('Light and finish', '1h 20m', [
        CourseLesson('Where light lands, and why', '10:20'),
        CourseLesson('Shading with three values only', '09:45'),
        CourseLesson('Finishing a study from start to end', '11:35'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'A pencil, paper and a willingness to make bad drawings first',
      'No prior art experience — the course starts with holding a pencil',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.2 - May 2026',
        body:
            'Added the gesture-drawing section and re-filmed the perspective lectures.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - September 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering measuring, form and basic shading.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor6.png',
        name: 'Anjali Rai',
        title: 'Drawing | Observational Studies',
        rating: '4.7',
        reviews: '1,980',
        students: '24,310',
        courses: '4',
        bio:
            'A studio artist who teaches drawing as a way of looking, and keeps '
            'her own sketchbooks from the years she could not.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 64),
      RatingBar('4 ★', 25),
      RatingBar('3 ★', 7),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Kritika Shrestha',
        when: '11 days ago',
        body: 'The measuring lecture changed how I look at everything.',
      ),
      CourseReview(
        name: 'Binod Thapa',
        when: '6 weeks ago',
        body: 'Gentle and encouraging without being vague.',
      ),
      CourseReview(
        name: 'Sushma Gurung',
        when: '2 months ago',
        body: 'I can finally draw a box that looks like a box.',
      ),
    ],
    totalTime: '4hrs',
    resources: <CourseResource>[
      CourseResource('Line Exercise Sheets', CourseResourceType.pdf),
      CourseResource('Value Scale Reference', CourseResourceType.pdf),
      CourseResource('Form Study Guide', CourseResourceType.doc),
      CourseResource('Practice Log', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Maya Shrestha',
        'Instructor',
        '4h ago',
        'Draw the same object three times rather than three objects once. Progress in sketching is almost entirely repetition.',
        isStaff: true,
        reactions: 46,
      ),
      CourseDiscussion(
        'Aarati Gurung',
        'Student',
        '2h ago',
        'How long should a single practice sketch take at this stage?',
        reactions: 14,
      ),
      CourseDiscussion(
        'Bimal Thapa',
        'Student',
        '1h ago',
        'The value scale reference is pinned above my desk now.',
        reactions: 11,
      ),
      CourseDiscussion(
        'Srijana Rai',
        'Student',
        '40m ago',
        'The practice log is what kept me drawing daily. Twenty minutes is easier to commit to than an hour.',
        reactions: 18,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/course-thumbnail.png',
    badge: 'Watercolour',
    title: 'Watercolour Landscapes from Scratch',
    subtitle:
        'Washes, wet-on-wet and the discipline of stopping early — paint a '
        'landscape you would hang up.',
    rating: '4.8',
    level: 'Beginner',
    category: 'Drawing',
    price: 'Rs. 1,199',
    ratingsCount: '(1,780 ratings)',
    studentsEnrolled: '8,940 students enrolled',
    instructorName: 'Bikash Gurung',
    instructorAvatar: 'assets/figma/instructors/instructor7.png',
    lastUpdated: 'Last updated 06/2026',
    languages: 'English, Nepali',
    learningOutcomes: [
      'Control water instead of fighting it',
      'Lay a flat wash and a graded wash cleanly',
      'Build depth with three planes and three values',
      'Know when a painting is finished and put the brush down',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 10m total length',
    modules: [
      CourseModule('Paper, paint and water', '1h 40m', [
        CourseLesson('Choosing paper and paints that behave', '10:30'),
        CourseLesson('Flat, graded and variegated washes', '12:15'),
        CourseLesson('Wet-on-wet and wet-on-dry', '11:20', isPreview: true),
      ]),
      CourseModule('Composing a landscape', '1h 50m', [
        CourseLesson('Sketching the big shapes first', '11:05'),
        CourseLesson('Sky, distance and atmosphere', '12:50'),
        CourseLesson('Foreground texture without mud', '12:25'),
      ]),
      CourseModule('Three complete paintings', '1h 40m', [
        CourseLesson('A misty valley, start to finish', '13:40'),
        CourseLesson('A lakeside at dusk', '12:35'),
        CourseLesson('A hillside in morning light', '11:50'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'A basic watercolour set, two brushes and watercolour paper',
      'No drawing experience needed — the sketch stage is taught too',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.1 - April 2026',
        body: 'Added the dusk painting and a short section on colour mixing.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - August 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering washes and the first complete painting.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor7.png',
        name: 'Bikash Gurung',
        title: 'Watercolour | Landscape Painting',
        rating: '4.8',
        reviews: '1,640',
        students: '18,720',
        courses: '3',
        bio:
            'A landscape painter who paints outside in all weathers and thinks '
            'you should learn to do the same.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 69),
      RatingBar('4 ★', 22),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Manisha Adhikari',
        when: '8 days ago',
        body: 'The wash exercises alone are worth the price.',
      ),
      CourseReview(
        name: 'Deepak Bista',
        when: '5 weeks ago',
        body: 'Learned more from three paintings than a year of videos.',
      ),
      CourseReview(
        name: 'Niraja Karki',
        when: '3 months ago',
        body: 'Slow, calm and clear. My mud problem is solved.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource('Wash Technique Guide', CourseResourceType.pdf),
      CourseResource('Colour Mixing Chart', CourseResourceType.pdf),
      CourseResource('Paper and Brush Guide', CourseResourceType.doc),
      CourseResource('Practice Log', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Ramesh Khanal',
        'Instructor',
        '5h ago',
        'Wet the paper before you mix the colour. Most muddy skies come from arriving late with the paint already drying.',
        isStaff: true,
        reactions: 52,
      ),
      CourseDiscussion(
        'Kamala Shrestha',
        'Student',
        '3h ago',
        'Which paper weight should I start with? The guide lists three.',
        reactions: 16,
      ),
      CourseDiscussion(
        'Nirmala Rai',
        'Student',
        '2h ago',
        'The colour mixing chart is the most useful page here.',
        reactions: 13,
      ),
      CourseDiscussion(
        'Sushila Thapa',
        'Student',
        '1h ago',
        'My first wash looked nothing like the demo, and then the third one did. Worth persisting.',
        reactions: 21,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/Rectangle 3350.png',
    badge: 'Illustration',
    title: 'Digital Illustration in Procreate',
    subtitle:
        'Brushes, layers and light — a repeatable workflow for illustrations '
        'you can actually finish.',
    rating: '4.6',
    level: 'Intermediate',
    category: 'Drawing',
    price: 'Rs. 1,499',
    ratingsCount: '(1,205 ratings)',
    studentsEnrolled: '7,480 students enrolled',
    instructorName: 'Sneha Maharjan',
    instructorAvatar: 'assets/figma/instructors/instructor1.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English',
    learningOutcomes: [
      'Set up a brush and a canvas that suit the work',
      'Use layers and clipping to keep edits reversible',
      'Light a scene instead of colouring a drawing',
      'Finish an illustration without losing the first hour',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 25m total length',
    modules: [
      CourseModule('Setting up to work fast', '1h 45m', [
        CourseLesson('Canvas, resolution and export', '10:15'),
        CourseLesson('Brushes worth keeping', '12:30'),
        CourseLesson(
          'Layers, groups and clipping masks',
          '11:40',
          isPreview: true,
        ),
      ]),
      CourseModule('Building an illustration', '1h 55m', [
        CourseLesson('Thumbnails and composition', '11:20'),
        CourseLesson('Blocking in values', '12:45'),
        CourseLesson('Colour over value, not instead of it', '13:05'),
      ]),
      CourseModule('Light, texture and finish', '1h 45m', [
        CourseLesson('One light source, done well', '12:15'),
        CourseLesson('Texture and edge control', '11:30'),
        CourseLesson('Finishing pass and export', '10:50'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'An iPad with Procreate, or another layered painting app',
      'Some drawing experience — this is not a first drawing course',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.1 - June 2026',
        body: 'Added the lighting section and a new finishing pass lecture.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - January 2025'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering setup, blocking in and colour.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor1.png',
        name: 'Sneha Maharjan',
        title: 'Illustration | Digital Painting',
        rating: '4.6',
        reviews: '1,120',
        students: '15,640',
        courses: '3',
        bio:
            'A commercial illustrator who finishes work on a deadline and '
            'teaches the habits that make that possible.',
      ),
    ],
    courseRating: '4.6',
    ratingBars: [
      RatingBar('5 ★', 60),
      RatingBar('4 ★', 28),
      RatingBar('3 ★', 8),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Aayush Rana',
        when: '2 weeks ago',
        body: 'The lighting lecture made my work look intentional.',
      ),
      CourseReview(
        name: 'Sristi Pradhan',
        when: '2 months ago',
        body: 'Good workflow advice. Would like more on character design.',
      ),
      CourseReview(
        name: 'Nabin Karki',
        when: '3 months ago',
        body: 'Assumes you can already draw. It says so, and it means it.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource('Brush Set Guide', CourseResourceType.pdf),
      CourseResource('Layer Workflow Reference', CourseResourceType.pdf),
      CourseResource('Canvas Setup Sheet', CourseResourceType.doc),
      CourseResource('Project Tracker', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Anjali Manandhar',
        'Instructor',
        '3h ago',
        'Name your layers as you go. Future you will open a file with forty layers called Layer 12 and regret it.',
        isStaff: true,
        reactions: 44,
      ),
      CourseDiscussion(
        'Priyanka Gurung',
        'Student',
        '2h ago',
        'Is it worth learning the gestures before the brushes?',
        reactions: 12,
      ),
      CourseDiscussion(
        'Bishal Rai',
        'Student',
        '1h ago',
        'The layer workflow reference changed how I structure files.',
        reactions: 19,
      ),
      CourseDiscussion(
        'Roshani Karki',
        'Illustrator',
        '35m ago',
        'The brush guide covers the ones that are actually worth installing. Most lists do not.',
        reactions: 25,
      ),
    ],
  ),
  // ── Public Speaking ───────────────────────────────────────────────────────
  CourseDetailData(
    image: 'assets/figma/homescreen/ict1.png',
    badge: 'Confidence',
    title: 'Speak with Confidence: Stage & Camera',
    subtitle:
        'Nerves, voice and presence — practical work for speaking to a room, a '
        'class or a webcam.',
    rating: '4.8',
    level: 'Beginner',
    category: 'Public Speaking',
    price: 'Rs. 899',
    ratingsCount: '(3,410 ratings)',
    studentsEnrolled: '16,780 students enrolled',
    instructorName: 'Rajan Shrestha',
    instructorAvatar: 'assets/figma/instructors/instructor2.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Nepali, Hindi',
    learningOutcomes: [
      'Steady your breathing and your voice before you start',
      'Open with something that earns the next thirty seconds',
      'Handle a blank mind without apologising to the room',
      'Look composed on camera as well as on stage',
    ],
    curriculumSummary: '3 sections • 9 lectures • 4h 48m total length',
    modules: [
      CourseModule('Before you speak', '1h 35m', [
        CourseLesson('What nerves actually are', '10:05'),
        CourseLesson('Breath, posture and a voice that carries', '11:50'),
        CourseLesson('Preparing without memorising', '10:40', isPreview: true),
      ]),
      CourseModule('While you speak', '1h 45m', [
        CourseLesson('Openings that earn attention', '11:15'),
        CourseLesson('Pace, pauses and the power of stopping', '12:05'),
        CourseLesson('Recovering when your mind goes blank', '11:30'),
      ]),
      CourseModule('Stage, camera and audience', '1h 28m', [
        CourseLesson('Reading a room and adjusting', '10:55'),
        CourseLesson('Speaking to a camera instead of a lens', '11:20'),
        CourseLesson('Handling questions you did not expect', '10:15'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'A phone or laptop that can record you — you will watch yourself back',
      'Willingness to practise out loud, not just watch',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.3 - July 2026',
        body:
            'Added the camera-specific section and rebuilt the breathing exercises.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - June 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body:
            'First release, covering nerves, openings and handling questions.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor2.png',
        name: 'Rajan Shrestha',
        title: 'Public Speaking | Communication',
        rating: '4.8',
        reviews: '3,050',
        students: '38,900',
        courses: '4',
        bio:
            'A communication coach who was once too nervous to introduce '
            'himself, and remembers exactly what that felt like.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 70),
      RatingBar('4 ★', 21),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Rekha Adhikari',
        when: '6 days ago',
        body: 'Watching myself back was uncomfortable and exactly the point.',
      ),
      CourseReview(
        name: 'Suman Thapa',
        when: '4 weeks ago',
        body: 'The blank-mind lecture is worth the whole course.',
      ),
      CourseReview(
        name: 'Anju Maharjan',
        when: '2 months ago',
        body: 'Practical, not motivational. I preferred that.',
      ),
    ],
    totalTime: '4hrs',
    resources: <CourseResource>[
      CourseResource('Breathing Exercise Guide', CourseResourceType.pdf),
      CourseResource('Talk Structure Template', CourseResourceType.doc),
      CourseResource('Delivery Self-Assessment', CourseResourceType.xls),
      CourseResource('Recording Setup Sheet', CourseResourceType.pdf),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Sujata Karki',
        'Instructor',
        '4h ago',
        'Record yourself once a week, not once a day. Daily recording makes you fixate on details instead of progress.',
        isStaff: true,
        reactions: 57,
      ),
      CourseDiscussion(
        'Deepak Shrestha',
        'Student',
        '2h ago',
        'How do I stop my voice rising at the end of statements?',
        reactions: 23,
      ),
      CourseDiscussion(
        'Anjana Rai',
        'Student',
        '1h ago',
        'The talk structure template is what I now use for every presentation.',
        reactions: 17,
      ),
      CourseDiscussion(
        'Manoj Thapa',
        'Student',
        '40m ago',
        'Watching my own recording was uncomfortable and it was the most useful thing in the course.',
        reactions: 29,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/course-thumbnail2.png',
    badge: 'Storytelling',
    title: 'Storytelling for Presenters',
    subtitle:
        'Turn a list of facts into something people remember — structure, '
        'tension and a point worth reaching.',
    rating: '4.7',
    level: 'Intermediate',
    category: 'Public Speaking',
    price: 'Rs. 1,099',
    ratingsCount: '(1,562 ratings)',
    studentsEnrolled: '9,310 students enrolled',
    instructorName: 'Priya Joshi',
    instructorAvatar: 'assets/figma/instructors/instructor3.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English, Nepali',
    learningOutcomes: [
      'Find the story hiding inside a technical talk',
      'Structure a presentation around tension, not a table of contents',
      'Use slides as support rather than a script',
      'Land an ending that says something',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 05m total length',
    modules: [
      CourseModule('Finding the story', '1h 40m', [
        CourseLesson('Why facts alone do not persuade', '10:45'),
        CourseLesson('The shape of a story worth telling', '12:20'),
        CourseLesson(
          'Turning your work into a narrative',
          '11:35',
          isPreview: true,
        ),
      ]),
      CourseModule('Building the talk', '1h 45m', [
        CourseLesson('Opening with tension', '11:10'),
        CourseLesson('Slides that support, not repeat', '12:40'),
        CourseLesson('Transitions and the middle slump', '11:25'),
      ]),
      CourseModule('Delivery and endings', '1h 40m', [
        CourseLesson('Voice, silence and emphasis', '11:50'),
        CourseLesson('Endings that land', '10:30'),
        CourseLesson('Rewriting your own talk on camera', '12:15'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'A talk, a lesson or a presentation you actually have to give',
      'Comfortable speaking aloud already — this is the next step',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.1 - May 2026',
        body: 'Added the slide-design section and a new ending workshop.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - October 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering story structure and delivery.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor3.png',
        name: 'Priya Joshi',
        title: 'Storytelling | Presentation Design',
        rating: '4.7',
        reviews: '1,430',
        students: '21,540',
        courses: '3',
        bio:
            'A presentation designer who has rewritten hundreds of decks and '
            'can usually tell what the story is before slide two.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 65),
      RatingBar('4 ★', 24),
      RatingBar('3 ★', 7),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Bishal Neupane',
        when: '9 days ago',
        body: 'My conference talk went from a list to a story.',
      ),
      CourseReview(
        name: 'Sarita Lama',
        when: '7 weeks ago',
        body: 'The middle-slump lecture was oddly specific and very useful.',
      ),
      CourseReview(
        name: 'Ramesh Bhandari',
        when: '3 months ago',
        body: 'Good structure. Wanted more on slide visuals.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource('Story Arc Template', CourseResourceType.pdf),
      CourseResource('Opening Hooks Collection', CourseResourceType.pdf),
      CourseResource('Slide Outline Sheet', CourseResourceType.doc),
      CourseResource('Rehearsal Tracker', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Bikash Adhikari',
        'Instructor',
        '5h ago',
        'Open with the problem, not the agenda. Nobody has ever been moved by a table of contents.',
        isStaff: true,
        reactions: 63,
      ),
      CourseDiscussion(
        'Sarita Karki',
        'Student',
        '3h ago',
        'Is there a length where a story stops helping and starts costing you time?',
        reactions: 19,
      ),
      CourseDiscussion(
        'Niraj Rai',
        'Student',
        '2h ago',
        'The hooks collection is genuinely useful. I used two of them this week.',
        reactions: 22,
      ),
      CourseDiscussion(
        'Pramila Thapa',
        'Student',
        '1h ago',
        'The rehearsal tracker made me practise four times instead of once.',
        reactions: 15,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/Rectangle 3353.png',
    badge: 'Debate',
    title: 'Debate & Persuasion Essentials',
    subtitle:
        'Argue well, on purpose — building a case, spotting a weak one, and '
        'changing a mind without raising your voice.',
    rating: '4.6',
    level: 'Intermediate',
    category: 'Public Speaking',
    price: 'Rs. 999',
    ratingsCount: '(1,140 ratings)',
    studentsEnrolled: '6,850 students enrolled',
    instructorName: 'Dipesh Karki',
    instructorAvatar: 'assets/figma/instructors/instructor4.png',
    lastUpdated: 'Last updated 06/2026',
    languages: 'English, Hindi',
    learningOutcomes: [
      'Build an argument with premises you can defend',
      'Spot the common fallacies in real time',
      'Rebut a point without attacking the person making it',
      'Persuade someone who is not yet on your side',
    ],
    curriculumSummary: '3 sections • 9 lectures • 4h 55m total length',
    modules: [
      CourseModule('Building a case', '1h 35m', [
        CourseLesson('Claims, evidence and warrants', '10:40'),
        CourseLesson('Structuring an argument for a listener', '11:55'),
        CourseLesson('Anticipating the other side', '10:20', isPreview: true),
      ]),
      CourseModule('Reading the other argument', '1h 40m', [
        CourseLesson('The fallacies you will actually meet', '12:15'),
        CourseLesson('Distinguishing a weak point from a lost cause', '11:05'),
        CourseLesson('Rebutting without heat', '10:50'),
      ]),
      CourseModule('Persuasion in practice', '1h 40m', [
        CourseLesson('Speaking to the undecided', '11:30'),
        CourseLesson('Conceding a point on purpose', '10:45'),
        CourseLesson('Closing an argument cleanly', '11:15'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'An open mind and one issue you genuinely disagree about',
      'No debate experience needed',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.1 - March 2026',
        body: 'Added the concession lecture and refreshed all the examples.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - August 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering argument structure and fallacies.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor4.png',
        name: 'Dipesh Karki',
        title: 'Debate | Rhetoric',
        rating: '4.6',
        reviews: '1,050',
        students: '14,320',
        courses: '3',
        bio:
            'A debate coach who would rather you lost politely than won by '
            'shouting, and says so on the first lecture.',
      ),
    ],
    courseRating: '4.6',
    ratingBars: [
      RatingBar('5 ★', 59),
      RatingBar('4 ★', 29),
      RatingBar('3 ★', 8),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Sagar Rijal',
        when: '3 weeks ago',
        body: 'The rebuttal-without-heat lecture should be taught at school.',
      ),
      CourseReview(
        name: 'Pramila Thapa',
        when: '2 months ago',
        body: 'Practical and even-handed, which is rare here.',
      ),
      CourseReview(
        name: 'Nikesh Shrestha',
        when: '3 months ago',
        body: 'Short and sharp. Good for a first debate course.',
      ),
    ],
    totalTime: '4hrs',
    resources: <CourseResource>[
      CourseResource('Argument Mapping Template', CourseResourceType.pdf),
      CourseResource('Fallacy Reference Card', CourseResourceType.pdf),
      CourseResource('Rebuttal Practice Set', CourseResourceType.doc),
      CourseResource('Case Building Sheet', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Anil Koirala',
        'Instructor',
        '6h ago',
        'Steel-man the other side before you attack it. A weak opponent makes a weak case for your own position.',
        isStaff: true,
        reactions: 58,
      ),
      CourseDiscussion(
        'Rekha Shrestha',
        'Student',
        '3h ago',
        'How much time should go into the rebuttal versus the opening case?',
        reactions: 21,
      ),
      CourseDiscussion(
        'Bishnu Rai',
        'Student',
        '2h ago',
        'The fallacy card is short enough that I actually remember it.',
        reactions: 18,
      ),
      CourseDiscussion(
        'Sabina Thapa',
        'Student',
        '1h ago',
        'The argument mapping template made my cases much easier to defend.',
        reactions: 24,
      ),
    ],
  ),
  // ── Music ─────────────────────────────────────────────────────────────────
  CourseDetailData(
    image: 'assets/figma/homescreen/ict2.png',
    badge: 'Guitar',
    title: 'Guitar for Absolute Beginners',
    subtitle:
        'From holding the instrument to playing songs people recognise — '
        'chords, rhythm and a practice routine that works.',
    rating: '4.9',
    level: 'Beginner',
    category: 'Music',
    price: 'Rs. 1,199',
    ratingsCount: '(4,120 ratings)',
    studentsEnrolled: '19,540 students enrolled',
    instructorName: 'Sujan Tamang',
    instructorAvatar: 'assets/figma/instructors/instructor5.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Nepali',
    learningOutcomes: [
      'Hold and tune the guitar so it stops fighting you',
      'Play the eight chords most songs are built from',
      'Keep time with a strumming pattern instead of stopping',
      'Practise fifteen minutes a day and actually improve',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 30m total length',
    modules: [
      CourseModule('Getting started properly', '1h 50m', [
        CourseLesson('Holding, tuning and the first sounds', '11:20'),
        CourseLesson('Reading chord diagrams and tabs', '10:35'),
        CourseLesson(
          'Your first two chords, cleanly',
          '12:10',
          isPreview: true,
        ),
      ]),
      CourseModule('Chords and changes', '1h 55m', [
        CourseLesson('The open chords that unlock songs', '13:05'),
        CourseLesson('Changing chords without pausing', '11:45'),
        CourseLesson('Barre chords, slowly and without pain', '12:30'),
      ]),
      CourseModule('Rhythm and songs', '1h 45m', [
        CourseLesson('Strumming patterns that fit anything', '11:50'),
        CourseLesson('Playing and singing at the same time', '12:20'),
        CourseLesson('Your first complete song', '10:55'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'Any acoustic or electric guitar, in working order',
      'No music-reading ability needed — everything is shown on screen',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.4 - June 2026',
        body:
            'Added the singing-while-playing section and re-filmed every close-up.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - May 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering the open chords and basic strumming.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor5.png',
        name: 'Sujan Tamang',
        title: 'Guitar | Music Performance',
        rating: '4.9',
        reviews: '3,860',
        students: '42,100',
        courses: '4',
        bio:
            'A session guitarist who has taught a thousand beginners and still '
            'remembers how much the first chord hurt.',
      ),
    ],
    courseRating: '4.9',
    ratingBars: [
      RatingBar('5 ★', 76),
      RatingBar('4 ★', 17),
      RatingBar('3 ★', 4),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Aashish Gurung',
        when: '5 days ago',
        body:
            'Played my first full song last night. Fifteen minutes a day works.',
      ),
      CourseReview(
        name: 'Srijana Rai',
        when: '1 month ago',
        body: 'The chord-change drills are boring and they work.',
      ),
      CourseReview(
        name: 'Kiran Bista',
        when: '2 months ago',
        body: 'Barre chords finally stopped hurting.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource('Chord Chart Pack', CourseResourceType.pdf),
      CourseResource('Practice Routine Sheet', CourseResourceType.xls),
      CourseResource('Finger Position Guide', CourseResourceType.pdf),
      CourseResource('Song List by Difficulty', CourseResourceType.doc),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Prakash Lama',
        'Instructor',
        '4h ago',
        'Ten minutes daily beats an hour on Sunday. Your fingers need frequency more than duration at this stage.',
        isStaff: true,
        reactions: 69,
      ),
      CourseDiscussion(
        'Anisha Karki',
        'Student',
        '2h ago',
        'How long before the F chord stops hurting?',
        reactions: 27,
      ),
      CourseDiscussion(
        'Suman Shrestha',
        'Student',
        '1h ago',
        'The chord chart pack is the only reference I have needed.',
        reactions: 14,
      ),
      CourseDiscussion(
        'Nirajan Thapa',
        'Student',
        '45m ago',
        'The song list by difficulty is what kept me motivated. I could play something real in week two.',
        reactions: 22,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/courses/dm.png',
    badge: 'Theory',
    title: 'Music Theory You Can Actually Use',
    subtitle:
        'Scales, keys and chords explained through the songs you already know, '
        'with nothing taught for its own sake.',
    rating: '4.7',
    level: 'Beginner',
    category: 'Music',
    price: 'Rs. 899',
    ratingsCount: '(1,890 ratings)',
    studentsEnrolled: '10,270 students enrolled',
    instructorName: 'Nirajan Poudel',
    instructorAvatar: 'assets/figma/instructors/instructor6.png',
    lastUpdated: 'Last updated 07/2026',
    languages: 'English',
    learningOutcomes: [
      'Read a key signature and know what it means',
      'Build any major or minor scale from one pattern',
      'Understand why a chord progression feels the way it does',
      'Work out a song by ear with the theory to back it up',
    ],
    curriculumSummary: '3 sections • 9 lectures • 4h 40m total length',
    modules: [
      CourseModule('The building blocks', '1h 30m', [
        CourseLesson('Notes, intervals and the keyboard', '10:25'),
        CourseLesson('Major and minor scales', '11:40'),
        CourseLesson(
          'Key signatures without memorising',
          '09:55',
          isPreview: true,
        ),
      ]),
      CourseModule('Chords and keys', '1h 35m', [
        CourseLesson('Building chords from a scale', '12:10'),
        CourseLesson('The progressions behind most songs', '11:35'),
        CourseLesson('Transposing to fit a voice', '10:45'),
      ]),
      CourseModule('Using it', '1h 35m', [
        CourseLesson('Working a song out by ear', '11:50'),
        CourseLesson('Rhythm and time signatures', '10:30'),
        CourseLesson('Where theory stops and taste starts', '11:15'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'No instrument required — a keyboard app is enough',
      'No prior theory at all; this starts at the very beginning',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.2 - April 2026',
        body:
            'Added the ear-training section and rebuilt every exercise around real songs.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - July 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering intervals, scales and chord building.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor6.png',
        name: 'Nirajan Poudel',
        title: 'Music Theory | Composition',
        rating: '4.7',
        reviews: '1,760',
        students: '19,880',
        courses: '3',
        bio:
            'A composer who teaches theory only when it answers a question you '
            'already had.',
      ),
    ],
    courseRating: '4.7',
    ratingBars: [
      RatingBar('5 ★', 63),
      RatingBar('4 ★', 26),
      RatingBar('3 ★', 7),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 2),
    ],
    reviews: [
      CourseReview(
        name: 'Milan Shrestha',
        when: '2 weeks ago',
        body: 'First theory course that did not feel like homework.',
      ),
      CourseReview(
        name: 'Pooja Basnet',
        when: '6 weeks ago',
        body: 'I can finally work songs out by ear.',
      ),
      CourseReview(
        name: 'Sujata Adhikari',
        when: '3 months ago',
        body: 'Good for beginners. Guitarists will get a lot from it.',
      ),
    ],
    totalTime: '4hrs',
    resources: <CourseResource>[
      CourseResource('Scale and Mode Reference', CourseResourceType.pdf),
      CourseResource('Chord Progression Workbook', CourseResourceType.pdf),
      CourseResource('Ear Training Exercises', CourseResourceType.doc),
      CourseResource('Practice Log', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Rojina Maharjan',
        'Instructor',
        '5h ago',
        'Learn theory on an instrument you already play. Theory in the abstract is a vocabulary list you will not remember.',
        isStaff: true,
        reactions: 55,
      ),
      CourseDiscussion(
        'Bikram Rai',
        'Student',
        '3h ago',
        'Is it worth memorising all the modes, or just the ones I use?',
        reactions: 23,
      ),
      CourseDiscussion(
        'Sanjita Karki',
        'Student',
        '2h ago',
        'The progression workbook made the theory usable immediately.',
        reactions: 16,
      ),
      CourseDiscussion(
        'Dipendra Thapa',
        'Student',
        '1h ago',
        'The ear training exercises are short and I actually do them.',
        reactions: 19,
      ),
    ],
  ),
  CourseDetailData(
    image: 'assets/figma/homescreen/Rectangle 3354.png',
    badge: 'Vocals',
    title: 'Singing: Pitch, Breath & Tone',
    subtitle:
        'Find your range, sing in tune and stop running out of air in the '
        'middle of a phrase.',
    rating: '4.8',
    level: 'Intermediate',
    category: 'Music',
    price: 'Rs. 1,299',
    ratingsCount: '(2,340 ratings)',
    studentsEnrolled: '12,610 students enrolled',
    instructorName: 'Asmita Basnet',
    instructorAvatar: 'assets/figma/instructors/instructor7.png',
    lastUpdated: 'Last updated 08/2026',
    languages: 'English, Nepali, Hindi',
    learningOutcomes: [
      'Warm up without straining your voice',
      'Sing in tune against a reference you trust',
      'Support a phrase so you do not run out of breath',
      'Build a tone you like instead of imitating someone else',
    ],
    curriculumSummary: '3 sections • 9 lectures • 5h 15m total length',
    modules: [
      CourseModule('Finding your voice', '1h 45m', [
        CourseLesson('Breath support, from the diaphragm', '11:10'),
        CourseLesson('Finding your comfortable range', '10:50'),
        CourseLesson(
          'A warm-up you will actually do',
          '11:25',
          isPreview: true,
        ),
      ]),
      CourseModule('Pitch and control', '1h 50m', [
        CourseLesson('Singing in tune, and hearing when you are not', '12:30'),
        CourseLesson('Leaps, runs and the awkward intervals', '11:55'),
        CourseLesson('Dynamics without going flat', '10:40'),
      ]),
      CourseModule('Tone and performance', '1h 40m', [
        CourseLesson('Resonance and where it lives', '11:35'),
        CourseLesson('Recording yourself honestly', '10:25'),
        CourseLesson('Singing a full song, start to end', '12:05'),
      ]),
    ],
    includes: _standardIncludes,
    requirements: [
      'A way to record yourself — a phone is fine',
      'You can already sing a little; this is not a first-sounds course',
    ],
    descriptionIntro: 'Course Updates:',
    descriptionBlocks: [
      CourseDescriptionBlock(
        heading: 'v 1.2 - June 2026',
        body:
            'Added the honest-recording section and expanded the warm-up library.',
      ),
      CourseDescriptionBlock(heading: 'v 1.0 - September 2024'),
    ],
    descriptionMoreBlocks: [
      CourseDescriptionBlock(
        body: 'First release, covering breath, pitch and tone basics.',
      ),
    ],
    instructors: [
      CourseInstructor(
        avatar: 'assets/figma/instructors/instructor7.png',
        name: 'Asmita Basnet',
        title: 'Vocals | Performance',
        rating: '4.8',
        reviews: '2,180',
        students: '26,450',
        courses: '3',
        bio:
            'A vocal coach who protects voices first and performs second, in '
            'that order, every time.',
      ),
    ],
    courseRating: '4.8',
    ratingBars: [
      RatingBar('5 ★', 68),
      RatingBar('4 ★', 23),
      RatingBar('3 ★', 6),
      RatingBar('2 ★', 2),
      RatingBar('1 ★', 1),
    ],
    reviews: [
      CourseReview(
        name: 'Bina Thapa',
        when: '7 days ago',
        body: 'The breath support lecture fixed a problem I had for years.',
      ),
      CourseReview(
        name: 'Narayan Karki',
        when: '5 weeks ago',
        body: 'Kind about the voice and honest about the work.',
      ),
      CourseReview(
        name: 'Sabina Maharjan',
        when: '2 months ago',
        body: 'Recording myself was hard to hear and the best part.',
      ),
    ],
    totalTime: '5hrs',
    resources: <CourseResource>[
      CourseResource('Warm Up Routine', CourseResourceType.pdf),
      CourseResource('Breath Support Guide', CourseResourceType.pdf),
      CourseResource('Pitch Exercise Tracks', CourseResourceType.doc),
      CourseResource('Practice Log', CourseResourceType.xls),
    ],
    discussions: <CourseDiscussion>[
      CourseDiscussion(
        'Sarita Maharjan',
        'Instructor',
        '4h ago',
        'Never practise a song at the edge of your range. Warm up first, every time, or you will lose a week to strain.',
        isStaff: true,
        reactions: 61,
      ),
      CourseDiscussion(
        'Prakriti Rai',
        'Student',
        '2h ago',
        'How do I know if I am singing from my diaphragm or just pushing harder?',
        reactions: 25,
      ),
      CourseDiscussion(
        'Anup Thapa',
        'Student',
        '1h ago',
        'The breath support guide explained something three teachers had not.',
        reactions: 21,
      ),
      CourseDiscussion(
        'Mina Shrestha',
        'Student',
        '40m ago',
        'The practice log made me realise I was skipping warm ups constantly.',
        reactions: 17,
      ),
    ],
  ),
];
