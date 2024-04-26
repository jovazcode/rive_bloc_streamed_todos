import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:local_storage_todos_api/local_storage_todos_api.dart';
import 'package:rive_bloc/rive_bloc.dart';
import 'package:todos/repository.dart';
import 'package:todos_repository/todos_repository.dart';

/// Some keys used for testing
final addTodoKey = UniqueKey();
final activeFilterKey = UniqueKey();
final completedFilterKey = UniqueKey();
final allFilterKey = UniqueKey();

/// The different ways to filter the list of todos
enum TodoListFilter {
  all,
  active,
  completed,
}

/// The currently active filter.
///
/// We use [StateProvider] here because we need to be able to update the
/// cubit's state from the UI.
final todoListFilter =
    RiveBlocProvider.state(() => ValueCubit(TodoListFilter.all));

/// The number of uncompleted todos
///
/// By using [ValueProvider], this value is cached, making it performant.
/// Even multiple widgets try to read the number of uncompleted todos,
/// the value will be computed only once (until the todo-list changes).
///
/// This will also optimise unneeded rebuilds if the todo-list changes, but the
/// number of uncompleted todos doesn't (such as when editing a todo).
final uncompletedTodosCount = RiveBlocProvider.value(
  () => ValueCubit<int>(
    0,
    build: (ref, args) {
      return ref
          .watch(todoListProvider)
          .state
          .where((todo) => !todo.isCompleted)
          .length;
    },
  ),
);

/// The list of todos after applying of [todoListFilter].
///
/// This too uses [ValueProvider], to avoid recomputing the filtered
/// list unless either the filter of or the todo-list updates.
final filteredTodos =
    RiveBlocProvider.value<ValueCubit<List<Todo>>, List<Todo>>(
  () => ValueCubit([], build: (ref, args) {
    final filter = ref.watch(todoListFilter).state;
    final todos = ref.watch(todoListProvider).state;
    print('<BUILD> filteredTodos: todos.length=${todos.length}');

    switch (filter) {
      case TodoListFilter.completed:
        return todos.where((todo) => todo.isCompleted).toList();
      case TodoListFilter.active:
        return todos.where((todo) => !todo.isCompleted).toList();
      case TodoListFilter.all:
        return todos;
    }
  }),
);

class SimpleBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    print('<CHANGE> [${bloc.runtimeType}] $change');
    super.onChange(bloc, change);
  }

  @override
  void onCreate(BlocBase bloc) {
    print('<CREATE> $bloc');
    super.onCreate(bloc);
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    print('<ERROR> [${bloc.runtimeType}] $error, $stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = SimpleBlocObserver();
  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(RiveBlocScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        sharedPreferences,
      ),
      todoRepositoryProvider.overrideWithValue(TodosRepository(
        todosApi: LocalStorageTodosApi(
          plugin: sharedPreferences,
        ),
      )),
    ],
    providers: [
      sharedPreferencesProvider,
      todoRepositoryProvider,
      todoListStreamProvider,
      todoListProvider,
      todoListFilter,
      uncompletedTodosCount,
      filteredTodos,
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Home(),
    );
  }
}

class Home extends HookWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final newTodoController = useTextEditingController();
    return RiveBlocBuilder(builder: (context, ref, _) {
      final todos = ref.watch(filteredTodos);
      print('DEBUG <RiverBlocBuilder> builder: BUILDING, '
          'todos.length=${todos.length}');
      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            children: [
              const Title(),
              TextField(
                key: addTodoKey,
                controller: newTodoController,
                decoration: const InputDecoration(
                  labelText: 'What needs to be done?',
                ),
                onSubmitted: (value) {
                  ref.read(todoListProvider).add(value);
                  newTodoController.clear();
                },
              ),
              const SizedBox(height: 42),
              const Toolbar(),
              if (todos.isNotEmpty) const Divider(height: 0),
              for (var i = 0; i < todos.length; i++) ...[
                if (i > 0) const Divider(height: 0),
                Dismissible(
                  key: ValueKey(todos[i].id),
                  onDismissed: (_) {
                    ref.read(todoListProvider).remove(todos[i]);
                  },
                  child: TodoItem(todos[i]),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class Toolbar extends HookWidget {
  const Toolbar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return RiveBlocBuilder(builder: (context, ref, _) {
      final filter = ref.watch(todoListFilter).state;
      Color? textColorFor(TodoListFilter value) {
        return filter == value ? Colors.blue : Colors.black;
      }

      return Material(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${ref.watch(uncompletedTodosCount)} items left',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tooltip(
              key: allFilterKey,
              message: 'All todos',
              child: TextButton(
                onPressed: () =>
                    ref.read(todoListFilter).state = TodoListFilter.all,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: MaterialStateProperty.all(
                      textColorFor(TodoListFilter.all)),
                ),
                child: const Text('All'),
              ),
            ),
            Tooltip(
              key: activeFilterKey,
              message: 'Only uncompleted todos',
              child: TextButton(
                onPressed: () =>
                    ref.read(todoListFilter).state = TodoListFilter.active,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: MaterialStateProperty.all(
                    textColorFor(TodoListFilter.active),
                  ),
                ),
                child: const Text('Active'),
              ),
            ),
            Tooltip(
              key: completedFilterKey,
              message: 'Only completed todos',
              child: TextButton(
                onPressed: () =>
                    ref.read(todoListFilter).state = TodoListFilter.completed,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: MaterialStateProperty.all(
                    textColorFor(TodoListFilter.completed),
                  ),
                ),
                child: const Text('Completed'),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class Title extends StatelessWidget {
  const Title({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'todos',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color.fromARGB(38, 47, 47, 247),
        fontSize: 100,
        fontWeight: FontWeight.w100,
        fontFamily: 'Helvetica Neue',
      ),
    );
  }
}

/// The widget that that displays the components of an individual Todo Item
class TodoItem extends HookWidget {
  const TodoItem(this._todo, {super.key});

  // ignore: prefer_typing_uninitialized_variables
  final _todo;

  @override
  Widget build(BuildContext context) {
    final itemFocusNode = useFocusNode();
    final itemIsFocused = useIsFocused(itemFocusNode);

    final textEditingController = useTextEditingController();
    final textFieldFocusNode = useFocusNode();
    return RiveBlocBuilder(builder: (context, ref, _) {
      // final todo = ref.watch(_currentTodo).state;
      return Material(
        color: Colors.white,
        elevation: 6,
        child: Focus(
          focusNode: itemFocusNode,
          onFocusChange: (focused) {
            if (focused) {
              textEditingController.text = _todo.description;
            } else {
              // Commit changes only when the textfield is unfocused, for performance
              ref
                  .read(todoListProvider)
                  .edit(id: _todo.id, description: textEditingController.text);
            }
          },
          child: ListTile(
            onTap: () {
              itemFocusNode.requestFocus();
              textFieldFocusNode.requestFocus();
            },
            leading: Checkbox(
              value: _todo.isCompleted,
              onChanged: (value) => ref.read(todoListProvider).toggle(_todo.id),
            ),
            title: itemIsFocused
                ? TextField(
                    autofocus: true,
                    focusNode: textFieldFocusNode,
                    controller: textEditingController,
                  )
                : Text(_todo.description),
          ),
        ),
      );
    });
  }
}

bool useIsFocused(FocusNode node) {
  final isFocused = useState(node.hasFocus);

  useEffect(
    () {
      void listener() {
        isFocused.value = node.hasFocus;
      }

      node.addListener(listener);
      return () => node.removeListener(listener);
    },
    [node],
  );

  return isFocused.value;
}
