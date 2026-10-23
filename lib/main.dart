
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskFlowApp());
}

class Tarefa {
  String titulo;
  bool concluida;

  Tarefa({
    required this.titulo,
    this.concluida = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'concluida': concluida,
    };
  }

  factory Tarefa.fromJson(Map<String, dynamic> json) {
    return Tarefa(
      titulo: json['titulo'] as String,
      concluida: json['concluida'] as bool? ?? false,
    );
  }
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskFlow',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6478FF),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF20283B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const TelaTarefas(),
    );
  }
}

class TelaTarefas extends StatefulWidget {
  const TelaTarefas({super.key});

  @override
  State<TelaTarefas> createState() => _TelaTarefasState();
}

class _TelaTarefasState extends State<TelaTarefas> {
  final TextEditingController _controller = TextEditingController();
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  final List<Tarefa> _tarefas = [];
  final String _chave = 'taskflow_tarefas';

  String _filtro = 'Todas';
  bool _carregando = true;
  Future<void> _filaSalvamento = Future.value();

  int get _total => _tarefas.length;

  int get _concluidas =>
      _tarefas.where((tarefa) => tarefa.concluida).length;

  int get _pendentes => _total - _concluidas;

  double get _progresso =>
      _total == 0 ? 0 : _concluidas / _total;

  List<Tarefa> get _tarefasFiltradas {
    if (_filtro == 'Pendentes') {
      return _tarefas.where((t) => !t.concluida).toList();
    }

    if (_filtro == 'Concluídas') {
      return _tarefas.where((t) => t.concluida).toList();
    }

    return List.of(_tarefas);
  }

  @override
  void initState() {
    super.initState();
    _carregarTarefas();
  }

  Future<void> _carregarTarefas() async {
    try {
      final dados = await _prefs.getString(_chave);

      if (dados != null) {
        final lista = jsonDecode(dados) as List<dynamic>;

        if (!mounted) return;

        setState(() {
          _tarefas.clear();
          _tarefas.addAll(
            lista.map(
              (item) => Tarefa.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            ),
          );
        });
      }
    } catch (erro) {
      _mostrarMensagem('Erro ao carregar tarefas.');
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _salvarTarefas() {
    final dados = jsonEncode(
      _tarefas.map((tarefa) => tarefa.toJson()).toList(),
    );

    _filaSalvamento = _filaSalvamento
        .catchError((Object erro) {})
        .then((_) async {
      try {
        await _prefs.setString(_chave, dados);
      } catch (erro) {
        _mostrarMensagem('Erro ao salvar tarefas.');
      }
    });

    return _filaSalvamento;
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void _adicionarTarefa() {
    final titulo = _controller.text.trim();

    if (titulo.isEmpty) {
      _mostrarMensagem('Digite o nome da tarefa.');
      return;
    }

    setState(() {
      _tarefas.add(Tarefa(titulo: titulo));
    });

    _controller.clear();
    FocusScope.of(context).unfocus();
    _salvarTarefas();
  }

  void _alternarConclusao(Tarefa tarefa, bool? valor) {
    setState(() {
      tarefa.concluida = valor ?? false;
    });

    _salvarTarefas();
  }

  Future<void> _editarTarefa(Tarefa tarefa) async {
    final editor = TextEditingController(text: tarefa.titulo);

    final novoTitulo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar tarefa'),
        content: TextField(
          controller: editor,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'Novo título',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, editor.text.trim());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    editor.dispose();

    if (!mounted || novoTitulo == null) return;

    if (novoTitulo.isEmpty) {
      _mostrarMensagem('O título não pode ficar vazio.');
      return;
    }

    setState(() {
      tarefa.titulo = novoTitulo;
    });

    await _salvarTarefas();
  }

  Future<void> _excluirTarefa(Tarefa tarefa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir tarefa?'),
        content: Text(
          'Deseja remover "${tarefa.titulo}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _tarefas.remove(tarefa);
    });

    await _salvarTarefas();
  }

  Future<void> _limparConcluidas() async {
    if (_concluidas == 0) {
      _mostrarMensagem('Nenhuma tarefa concluída.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar concluídas?'),
        content: const Text(
          'Todas as tarefas concluídas serão removidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _tarefas.removeWhere((tarefa) => tarefa.concluida);
    });

    await _salvarTarefas();
  }

  Widget _cartaoResumo(
    String titulo,
    int quantidade,
    IconData icone,
    Color cor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF171E30),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor),
            const SizedBox(height: 12),
            Text(
              '$quantidade',
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtros() {
    return Wrap(
      spacing: 8,
      children: ['Todas', 'Pendentes', 'Concluídas'].map((filtro) {
        return ChoiceChip(
          label: Text(filtro),
          selected: _filtro == filtro,
          onSelected: (_) {
            setState(() {
              _filtro = filtro;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _cartaoTarefa(Tarefa tarefa) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tarefa.concluida
              ? const Color(0xFF3B806C)
              : Colors.white10,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 7,
          horizontal: 8,
        ),
        child: Row(
          children: [
            Checkbox(
              value: tarefa.concluida,
              activeColor: const Color(0xFF26B88A),
              onChanged: (valor) {
                _alternarConclusao(tarefa, valor);
              },
            ),
            Expanded(
              child: Text(
                tarefa.titulo,
                style: TextStyle(
                  fontSize: 15,
                  color: tarefa.concluida
                      ? Colors.white38
                      : Colors.white,
                  decoration: tarefa.concluida
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: Colors.white38,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF9CA9D6),
              ),
              onPressed: () => _editarTarefa(tarefa),
            ),
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFFF7474),
              ),
              onPressed: () => _excluirTarefa(tarefa),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tarefas = _tarefasFiltradas;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Row(
          children: [
            Icon(
              Icons.task_alt,
              color: Color(0xFF8294FF),
            ),
            SizedBox(width: 10),
            Text(
              'TaskFlow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Limpar tarefas concluídas',
            onPressed: _carregando ? null : _limparConcluidas,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Organize seu dia.',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Suas tarefas, suas conquistas.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        _cartaoResumo(
                          'Total',
                          _total,
                          Icons.list_alt,
                          const Color(0xFF8294FF),
                        ),
                        const SizedBox(width: 10),
                        _cartaoResumo(
                          'Pendentes',
                          _pendentes,
                          Icons.schedule,
                          Colors.orangeAccent,
                        ),
                        const SizedBox(width: 10),
                        _cartaoResumo(
                          'Concluídas',
                          _concluidas,
                          Icons.check_circle_outline,
                          Colors.greenAccent,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Seu progresso'),
                        Text(
                          '${(_progresso * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF8294FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progresso,
                        minHeight: 9,
                        backgroundColor: const Color(0xFF20283B),
                        color: const Color(0xFF8294FF),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLength: 100,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _adicionarTarefa(),
                            decoration: const InputDecoration(
                              hintText: 'Digite uma nova tarefa...',
                              prefixIcon: Icon(Icons.edit_note),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 55,
                          child: FilledButton(
                            onPressed: _adicionarTarefa,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF6478FF),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                            child: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                    _filtros(),
                    const SizedBox(height: 18),

                    Expanded(
                      child: tarefas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.inbox_outlined,
                                    size: 75,
                                    color: Colors.white30,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _total == 0
                                        ? 'Nenhuma tarefa cadastrada'
                                        : 'Nenhuma tarefa neste filtro',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: tarefas.length,
                              itemBuilder: (context, index) {
                                return _cartaoTarefa(
                                  tarefas[index],
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
