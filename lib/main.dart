import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iyywxdlfbqjbcgwrydvb.supabase.co',
    publishableKey: 'sb_publishable_AMApiKCwlCYu4zA5HiKwJw_qNQ5ld5p',
  );

  runApp(const WordWorldApp());
}

final supabase = Supabase.instance.client;

class WordWorldApp extends StatelessWidget {
  const WordWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordWorld',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BookListScreen(),
    );
  }
}

// ---------------------------------------------------------
// 1. 단어장 목록 화면 (단어장 이름만 입력받아 생성)
// ---------------------------------------------------------
class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  void _showAddBookDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 단어장 만들기'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '단어장 이름 (예: 토익 공부)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _createBook(titleController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => _createBook(titleController.text),
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBook(String rawTitle) async {
    final title = rawTitle.trim();
    if (title.isEmpty) return;

    await supabase.from('vocab_books').insert({'title': title});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WordWorld 📚',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('vocab_books')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final books = snapshot.data ?? [];

              if (books.isEmpty) {
                return const Center(
                  child: Text(
                    '아직 생성된 단어장이 없습니다.\n우측 하단 버튼을 눌러 단어장을 만들어보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.folder_outlined),
                      ),
                      title: Text(
                        book['title'] ?? '이름 없음',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: const Text('Day별 맞춤 학습 진행'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DayListScreen(book: book),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookDialog,
        icon: const Icon(Icons.add),
        label: const Text('단어장 만들기'),
      ),
    );
  }
}

// ---------------------------------------------------------
// 2. 단어장 내부: Day 목록 화면 (Day 추가 및 Day별 카드)
// ---------------------------------------------------------
class DayListScreen extends StatelessWidget {
  final Map<String, dynamic> book;
  const DayListScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final bookId = book['id'] as int;

    return Scaffold(
      appBar: AppBar(title: Text(book['title'] ?? '단어장')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            // 해당 단어장의 전체 단어 실시간 구독
            stream: supabase
                .from('words')
                .stream(primaryKey: ['id'])
                .eq('book_id', bookId)
                .order('created_at', ascending: true),
            builder: (context, wordSnapshot) {
              if (wordSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final words = wordSnapshot.data ?? [];

              // 등록된 단어들에서 존재하는 Day 번호 추출
              final Set<int> daySet = words
                  .map((w) => (w['day'] as int? ?? 1))
                  .toSet();
              if (daySet.isEmpty) {
                daySet.add(1); // 기본 Day 1 유지
              }
              final List<int> sortedDays = daySet.toList()..sort();

              // 완료된 Day 목록 실시간 조회
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase
                    .from('day_completions')
                    .stream(primaryKey: ['id'])
                    .eq('book_id', bookId),
                builder: (context, compSnapshot) {
                  final completedDays = (compSnapshot.data ?? [])
                      .map((c) => c['day'] as int)
                      .toSet();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedDays.length,
                    itemBuilder: (context, index) {
                      final dayNum = sortedDays[index];
                      final dayWords = words
                          .where((w) => (w['day'] as int? ?? 1) == dayNum)
                          .toList();
                      final isPassed = completedDays.contains(dayNum);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Day $dayNum',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      '${dayWords.length}단어',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const Spacer(),
                                  if (isPassed)
                                    const Chip(
                                      avatar: Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                      label: Text(
                                        '완료 ✅',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: Color(0xFFE8F5E9),
                                      side: BorderSide.none,
                                    ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 단어 관리 버튼
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.list_alt, size: 16),
                                    label: const Text('단어 관리'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              DayWordManageScreen(
                                                bookId: bookId,
                                                day: dayNum,
                                                dayWords: dayWords,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  // 랜덤 퀴즈 시작 버튼
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPassed
                                          ? Colors.green
                                          : Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 16,
                                    ),
                                    label: const Text('랜덤 퀴즈'),
                                    onPressed: dayWords.isEmpty
                                        ? () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      '단어를 먼저 1개 이상 등록해주세요!',
                                                    ),
                                                  ),
                                                );
                                          }
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    QuizScreen(
                                                      bookId: bookId,
                                                      day: dayNum,
                                                      allWords: words,
                                                      dayWords: dayWords,
                                                    ),
                                              ),
                                            );
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      // Day 추가 플로팅 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddNewDayDialog(context, bookId);
        },
        icon: const Icon(Icons.add),
        label: const Text('Day 추가'),
      ),
    );
  }

  void _showAddNewDayDialog(BuildContext context, int bookId) {
    final dayNumController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 Day 추가'),
        content: TextField(
          controller: dayNumController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '추가할 Day 번호 (예: 2)',
            hintText: '숫자 입력',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final day = int.tryParse(dayNumController.text.trim());
              if (day != null && day > 0) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BulkInputScreen(bookId: bookId, day: day),
                  ),
                );
              }
            },
            child: const Text('단어 입력으로 이동'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. Day별 단어 관리 화면 (단어 리스트 확인 및 추가/삭제)
// ---------------------------------------------------------
class DayWordManageScreen extends StatelessWidget {
  final int bookId;
  final int day;
  final List<Map<String, dynamic>> dayWords;

  const DayWordManageScreen({
    super.key,
    required this.bookId,
    required this.day,
    required this.dayWords,
  });

  Future<void> _deleteWord(int id) async {
    await supabase.from('words').delete().eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Day $day 단어 관리')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: dayWords.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 단어가 없습니다.\n우측 하단 버튼을 눌러 단어를 추가해보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayWords.length,
                  itemBuilder: (context, index) {
                    final item = dayWords[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          item['word'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(item['meaning'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.grey,
                          ),
                          onPressed: () => _deleteWord(item['id'] as int),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BulkInputScreen(bookId: bookId, day: day),
            ),
          );
        },
        icon: const Icon(Icons.edit_note),
        label: const Text('단어 연속 추가'),
      ),
    );
  }
}

// ---------------------------------------------------------
// 4. 엔터/확인 키보드 연속 단어 입력 화면
// ---------------------------------------------------------
class BulkInputScreen extends StatefulWidget {
  final int bookId;
  final int day;
  const BulkInputScreen({super.key, required this.bookId, required this.day});

  @override
  State<BulkInputScreen> createState() => _BulkInputScreenState();
}

class WordRowItem {
  final TextEditingController wordController = TextEditingController();
  final TextEditingController meaningController = TextEditingController();
  final FocusNode wordFocus = FocusNode();
  final FocusNode meaningFocus = FocusNode();
}

class _BulkInputScreenState extends State<BulkInputScreen> {
  final List<WordRowItem> _rows = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addNewRow(autoFocus: true);
  }

  void _addNewRow({bool autoFocus = false}) {
    final newRow = WordRowItem();
    setState(() {
      _rows.add(newRow);
    });

    if (autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        newRow.wordFocus.requestFocus();
      });
    }
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows.removeAt(index);
    });
  }

  Future<void> _saveAllWords() async {
    final List<Map<String, dynamic>> wordsToInsert = [];

    for (var row in _rows) {
      final w = row.wordController.text.trim();
      final m = row.meaningController.text.trim();
      if (w.isNotEmpty && m.isNotEmpty) {
        wordsToInsert.add({
          'book_id': widget.bookId,
          'day': widget.day,
          'word': w,
          'meaning': m,
        });
      }
    }

    if (wordsToInsert.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 단어가 없습니다. 단어와 뜻을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await supabase.from('words').insert(wordsToInsert);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${widget.day} 단어 연속 입력'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAllWords,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('저장 완료'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Container(
                color: Colors.amber.shade50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                width: double.infinity,
                child: const Row(
                  children: [
                    Icon(Icons.keyboard, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💡 단어 치고 [엔터/확인] ➡️ 뜻 치고 [엔터/확인] 치면 다음 칸 자동 생성!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final item = _rows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: item.wordController,
                              focusNode: item.wordFocus,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: '단어 (apple)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) {
                                item.meaningFocus.requestFocus();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: item.meaningController,
                              focusNode: item.meaningFocus,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: '뜻 (사과)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) {
                                if (index == _rows.length - 1) {
                                  _addNewRow(autoFocus: true);
                                } else {
                                  _rows[index + 1].wordFocus.requestFocus();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => _removeRow(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 5. 4지선다 랜덤 퀴즈 & 오답 리스트 확인 & 재시험 화면
// ---------------------------------------------------------
class QuizScreen extends StatefulWidget {
  final int bookId;
  final int day;
  final List<Map<String, dynamic>> allWords;
  final List<Map<String, dynamic>> dayWords;

  const QuizScreen({
    super.key,
    required this.bookId,
    required this.day,
    required this.allWords,
    required this.dayWords,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<Map<String, dynamic>> _currentTestWords;
  final List<Map<String, dynamic>> _wrongWords = [];
  int _currentIndex = 0;
  List<String> _currentOptions = [];
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    // 출제 순서를 완전 무작위(셔플)로 구성
    _currentTestWords = List.from(widget.dayWords)..shuffle();
    _loadQuestion();
  }

  void _loadQuestion() {
    if (_currentIndex >= _currentTestWords.length) {
      _finishQuiz();
      return;
    }

    final correctMeaning =
        _currentTestWords[_currentIndex]['meaning'] as String;

    // 전체 단어장에서 오답 후보들 가져오기
    final otherMeanings =
        widget.allWords
            .map((e) => e['meaning'] as String)
            .where((m) => m != correctMeaning)
            .toSet()
            .toList()
          ..shuffle();

    final List<String> options = [correctMeaning];

    // 오답 3개 채우기
    for (int i = 0; i < 3; i++) {
      if (i < otherMeanings.length) {
        options.add(otherMeanings[i]);
      } else {
        options.add('보기 ${i + 1}');
      }
    }

    options.shuffle();

    setState(() {
      _currentOptions = options;
    });
  }

  Future<void> _finishQuiz() async {
    setState(() => _isFinished = true);

    // 오답 없이 모두 통과한 경우 day_completions에 완료 기록 저장
    if (_wrongWords.isEmpty) {
      final existing = await supabase
          .from('day_completions')
          .select('id')
          .eq('book_id', widget.bookId)
          .eq('day', widget.day);

      if (existing.isEmpty) {
        await supabase.from('day_completions').insert({
          'book_id': widget.bookId,
          'day': widget.day,
        });
      }
    }
  }

  void _checkAnswer(String selectedOption) {
    final currentWord = _currentTestWords[_currentIndex];
    final isCorrect = selectedOption == currentWord['meaning'];

    if (!isCorrect) {
      if (!_wrongWords.contains(currentWord)) {
        _wrongWords.add(currentWord);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect ? '⭕ 정답입니다!' : '❌ 틀렸습니다! 정답: ${currentWord['meaning']}',
        ),
        duration: const Duration(milliseconds: 700),
        backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
      ),
    );

    setState(() {
      _currentIndex++;
    });
    _loadQuestion();
  }

  void _startRetry() {
    setState(() {
      _currentTestWords = List.from(_wrongWords)..shuffle();
      _wrongWords.clear();
      _currentIndex = 0;
      _isFinished = false;
    });
    _loadQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Day ${widget.day} 랜덤 퀴즈 🎯')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _isFinished ? _buildResultView() : _buildQuizView(),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizView() {
    final currentWord = _currentTestWords[_currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _currentTestWords.length,
          backgroundColor: Colors.grey.shade200,
          color: Colors.deepPurple,
        ),
        const SizedBox(height: 12),
        Text(
          '문제 ${_currentIndex + 1} / ${_currentTestWords.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.deepPurple.shade50,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Center(
              child: Text(
                currentWord['word'] ?? '',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        ..._currentOptions.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              onPressed: () => _checkAnswer(option),
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
        const Spacer(),
      ],
    );
  }

  Widget _buildResultView() {
    final bool isAllPassed = _wrongWords.isEmpty;

    if (isAllPassed) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 20),
          Text(
            '🎉 Day ${widget.day} 완벽 통과!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            '모든 단어를 마스터하셨습니다!\n학습 완료가 등록되었습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check),
            label: const Text('목록으로 돌아가기'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Icon(Icons.error_outline, size: 60, color: Colors.orange),
        const SizedBox(height: 10),
        Text(
          '${_wrongWords.length}개 단어를 틀렸습니다!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          '아래 정답을 확인하고 복습 후 재시험을 치러보세요:',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _wrongWords.length,
            itemBuilder: (context, index) {
              final w = _wrongWords[index];
              return Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade200,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    w['word'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '정답: ${w['meaning']}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: Text('틀린 단어 (${_wrongWords.length}개) 재시험 치기'),
            onPressed: _startRetry,
          ),
        ),
      ],
    );
  }
}
