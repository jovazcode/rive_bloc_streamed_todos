import 'package:local_storage_todos_api/local_storage_todos_api.dart';
import 'package:rive_bloc/rive_bloc.dart';
import 'package:todos_repository/todos_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final sharedPreferencesProvider =
    RiveBlocProvider.finalValue<SharedPreferences>(() {
  throw UnimplementedError();
});

final todoRepositoryProvider = RiveBlocProvider.finalValue<TodosRepository>(() {
  throw UnimplementedError();
});

final todoListStreamProvider =
    RiveBlocProvider.stream<StreamBloc<List<Todo>>, List<Todo>>(() =>
        StreamBloc((ref, args) => ref.read(todoRepositoryProvider).getTodos()));

/// Creates a [TodoListCubit] and initialise it with pre-defined values.
///
/// We are using [StateProvider] here, because `List<Todo>` is a complex
/// object, with advanced business logic like how to edit a todo.
final todoListProvider =
    RiveBlocProvider.state<TodoListCubit, List<Todo>>(TodoListCubit.new);

/// A [Todo] List [ValueCubit].
class TodoListCubit extends ValueCubit<List<Todo>> {
  TodoListCubit() : super([]);

  @override
  List<Todo> build(ref, args) =>
      ref.watch(todoListStreamProvider).state.value ?? [];

  void add(String description) =>
      ref.read(todoRepositoryProvider).saveTodo(Todo.fromJson(
            {
              'id': _uuid.v4(),
              'title': description,
              'description': description,
              'completed': false,
            },
          ));

  void toggle(String id) {
    for (final todo in state) {
      if (todo.id == id) {
        ref.read(todoRepositoryProvider).saveTodo(todo.copyWith(
              isCompleted: !todo.isCompleted,
            ));
      }
    }
  }

  void edit({required String id, required String description}) {
    for (final todo in state) {
      if (todo.id == id) {
        ref.read(todoRepositoryProvider).saveTodo(todo.copyWith(
              title: description,
              description: description,
            ));
      }
    }
  }

  void remove(Todo target) {
    ref.read(todoRepositoryProvider).deleteTodo(target.id);
  }
}
