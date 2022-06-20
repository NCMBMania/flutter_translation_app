import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deepl_dart/deepl_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ncmb/ncmb.dart';

void main() async {
  // .envファイルを読み込み
  await dotenv.load(fileName: ".env");
  // NCMBを初期化
  NCMB(dotenv.env['APPLICATION_KEY']!, dotenv.env['CLIENT_KEY']!);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Translation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: MainPage(),
    );
  }
}

// タブ表示用
class MainPage extends StatelessWidget {
  MainPage({Key? key}) : super(key: key);
  final _tabs = [
    const Tab(icon: Icon(Icons.translate)), // 翻訳画面
    const Tab(icon: Icon(Icons.list)), // 履歴画面
  ];
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: _tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('翻訳アプリ'),
            bottom: TabBar(
              tabs: _tabs.toList(),
            ),
          ),
          body: const TabBarView(
            children: [
              TranslationPage(),
              HistoryPage(),
            ],
          ),
        ),
      ),
    );
  }
}

// 翻訳画面のStatefulWidget
class TranslationPage extends StatefulWidget {
  const TranslationPage({Key? key}) : super(key: key);
  @override
  State<TranslationPage> createState() => _TranslationPageState();
}

// 翻訳画面
class _TranslationPageState extends State<TranslationPage> {
  // テキスト編集用コントローラー
  final _controller = TextEditingController();
  // 翻訳結果が入る変数
  var _translateText = "";
  // DeepL用ライブラリ
  final _translator = Translator(authKey: dotenv.env['DEEPL_AUTH_KEY']!);

  // 翻訳処理
  void _translate() async {
    // 入力されたテキスト（日本語）
    var originalText = _controller.text;
    // DeepLの翻訳処理
    final result =
        await _translator.translateTextSingular(originalText, 'en-US');
    // 結果を入れるデータストアのオブジェクト
    final translate = NCMBObject("Translate");
    // オブジェクトに必要なデータをセット
    translate
      ..set("original", originalText)
      ..set("translate", result.text);
    // 保存
    translate.save();
    // 画面に翻訳結果を反映
    setState(() {
      _translateText = result.text;
    });
  }

  // 入力、翻訳結果を消す処理
  void _clearText() {
    _controller.text = "";
    setState(() {
      _translateText = "";
    });
  }

  // 翻訳結果をクリップボードにコピー
  void _copyText() {
    Clipboard.setData(ClipboardData(text: _translateText));
  }

  // 画面構築
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '翻訳する言葉を入力してください',
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  onFieldSubmitted: (str) {
                    _translate();
                  },
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "日本語…",
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                ),
              ),
              TextButton(onPressed: _translate, child: const Text("翻訳する"))
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(color: Colors.white),
          ),
          _translateText != ""
              ? Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text("翻訳結果"),
                      TextButton(
                          onPressed: _copyText, child: const Icon(Icons.copy)),
                      TextButton(
                          onPressed: _clearText, child: const Icon(Icons.clear))
                    ]),
                    Text(_translateText),
                  ],
                )
              : const Text("翻訳結果がこの下に表示されます")
        ],
      ),
    );
  }
}

// 履歴画面のStatefulWidget
class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

// 翻訳画面
class _HistoryPageState extends State<HistoryPage> {
  // 履歴のNCMBObjectが入る配列
  var _histories = [];

  // 初期化処理
  @override
  void initState() {
    super.initState();
    // 履歴を取得する
    _getHistory();
  }

  // 履歴を取得する処理
  void _getHistory() async {
    // Translateクラスから10件取得
    final query = NCMBQuery('Translate');
    query.limit(10);
    // 検索実行
    final results = await query.fetchAll();
    // 検索結果を画面に反映
    setState(() {
      _histories = results;
    });
  }

  // タップしたデータの翻訳結果をクリップボードに入れる処理
  void _copyText(NCMBObject item) {
    Clipboard.setData(ClipboardData(text: item.getString('translate')));
  }

  // ロングタップしたデータを削除する処理
  void _deleteItem(context, NCMBObject item) async {
    // ダイアログ表示
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("削除の確認"),
          content: const Text("選択した翻訳を削除します"),
          actions: [
            TextButton(
              child: const Text("キャンセル"),
              onPressed: () =>
                  {Navigator.of(context, rootNavigator: true).pop(false)},
            ),
            TextButton(
              child: const Text("削除する"),
              onPressed: () =>
                  {Navigator.of(context, rootNavigator: true).pop(true)},
            ),
          ],
        );
      },
    );
    // 結果の判定
    if (result) {
      // OKボタンを押されたらデータ削除
      await item.delete();
      // 履歴一覧を更新
      _getHistory();
    }
  }

  // 画面を構築
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        var item = _histories[index] as NCMBObject;
        return Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black38),
              ),
            ),
            child: ListTile(
                title: Text(item.getString('original')),
                subtitle: Text(
                    item.getString('translate', defaultValue: "翻訳がありません"),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
                onLongPress: () {
                  _deleteItem(context, item);
                },
                onTap: () {
                  _copyText(item);
                }));
      },
      itemCount: _histories.length,
    );
  }
}
