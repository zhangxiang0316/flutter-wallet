import '../models/wallet_chain.dart';
import 'chain_adapter.dart';
import 'chain_adapter_registry.dart';

/// Typed operation implementations keyed by [ChainAdapter.id].
///
/// Feature services own one registry per operation contract. This removes
/// `WalletChainType -> handler` switches from their request paths and allows a
/// newly registered adapter to inject an implementation without editing the
/// service itself.
class ChainOperationRegistry<T> {
  ChainOperationRegistry([Map<String, T> operations = const {}])
    : _operations = Map<String, T>.of(operations);

  final Map<String, T> _operations;

  void register(String adapterId, T operation, {bool replace = false}) {
    final id = adapterId.trim();
    if (id.isEmpty) throw ArgumentError.value(adapterId, 'adapterId');
    if (!replace && _operations.containsKey(id)) {
      throw StateError('Operation already registered for $id');
    }
    _operations[id] = operation;
  }

  T require(
    WalletChainRef chain,
    ChainAdapterRegistry adapters, {
    required ChainCapability capability,
  }) {
    final adapter = adapters.require(chain, capability: capability);
    final operation = _operations[adapter.id];
    if (operation == null) {
      throw StateError(
        'Missing ${capability.name} operation for adapter ${adapter.id}',
      );
    }
    return operation;
  }
}
