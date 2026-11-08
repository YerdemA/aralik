import '../../data/question.dart';
import '../strings.dart';
import 'math_problem.dart';

/// [p] as a playable question: a magnitude of the math category whose
/// "source" is the working, shown after locking in place of a link.
Question mathQuestion(MathProblem p) => Question(
  id: p.id,
  text: p.text,
  answer: p.answer,
  unit: p.unit,
  kind: QuestionKind.magnitude,
  category: QuestionCategory.math,
  // Nothing to link to: the answer is computed. The result screen leaves
  // the source line out when it is empty.
  source: '',
  dataYear: 2026,
  funFact: AppStrings.mathWorking(p.working),
  difficulty: p.difficulty,
);
