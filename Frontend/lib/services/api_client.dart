import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Indica se o frontend deve usar mocks de API em vez do backend real.
///
/// Este valor é lido de `--dart-define=USE_MOCK=true` no comando `flutter run`.
/// O próprio [ApiClient] **não** implementa mocks – outros serviços podem
/// consultar esta flag para decidir o que fazer.
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

/// Valor de `BASE_URL` injectado via `--dart-define`.
///
/// Se estiver vazio, é calculado um valor por omissão em [_computeDefaultBase].
const String _envBase = String.fromEnvironment('BASE_URL', defaultValue: '');

/// Calcula a `baseUrl` por omissão de acordo com a plataforma.
///
/// - Web / Desktop / iOS simulador → `http://localhost:3000`  
/// - Android (emulador) → IP da máquina de desenvolvimento (por omissão,
///   `http://192.168.1.114:3000`, que cada dev pode ajustar)
///
/// Usa `kIsWeb` e um `try/catch` ao redor de [Platform] para evitar erros
/// quando `dart:io` não está disponível (ex.: Web).
String _computeDefaultBase() {
  // Web/desktop/iOS simulador => localhost
  if (kIsWeb) return 'http://localhost:3000';

  try {
    if (Platform.isAndroid) {
      // Para Android emulator, usar 10.0.2.2 (ou IP custom) via BASE_URL.
      // Para device físico, cada dev deve passar o IP da máquina:
      // flutter run --dart-define=BASE_URL=http://SEU_IP:3000
      const String customUrl = String.fromEnvironment('BASE_URL');
      if (customUrl.isNotEmpty) return customUrl;

      // Valor por defeito quando não há BASE_URL definida.
      // Ajusta este IP para o da tua rede local, se necessário.
      return 'http://192.168.1.114:3000';
    }
  } catch (_) {
    // Platform não existe no web; ignorar e cair no fallback.
  }

  // Fallback genérico para todas as outras plataformas.
  return 'http://localhost:3000';
}

/// URL base efectivamente usada pelo [ApiClient].
///
/// Ordem de prioridade:
/// 1. `BASE_URL` vindo de `--dart-define`
/// 2. Valor calculado em [_computeDefaultBase]
final String kBaseUrl = _envBase.isNotEmpty ? _envBase : _computeDefaultBase();

/// Cliente HTTP simples para comunicar com o backend NestJS.
///
/// Esconde a lógica de:
/// - Construção da URL absoluta (base + path)
/// - Cabeçalhos comuns (`Accept`, `Content-Type`, etc.)
///
/// Uso típico:
/// ```dart
/// final res = await ApiClient.instance.get('/routes/plan');
/// ```
///
/// Este cliente **não** faz parsing de JSON – devolve directamente
/// [http.Response] para que cada serviço trate da lógica de decode.
class ApiClient {
  ApiClient._();

  /// Instância singleton do cliente.
  static final ApiClient instance = ApiClient._();

  /// Executa um pedido HTTP GET para `[kBaseUrl][path]`.
  ///
  /// - [path] deve começar com `/`, por exemplo: `/auth/me`.
  /// - [headers] permite adicionar/override de cabeçalhos específicos
  ///   (ex.: `Authorization`).
  ///
  /// Devolve o [http.Response] bruto. Cabe ao chamador tratar de:
  /// - Verificar `statusCode`
  /// - Fazer `jsonDecode` do `body`, se necessário.
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    return http.get(
      uri,
      headers: <String, String>{
        'Accept': 'application/json',
        if (headers != null) ...headers,
      },
    );
  }

  /// Executa um pedido HTTP POST para `[kBaseUrl][path]`.
  ///
  /// - [path] deve começar com `/`, por exemplo: `/auth/login`.
  /// - [headers] permite adicionar/override de cabeçalhos específicos.
  /// - [body] é enviado tal como recebido (normalmente um `jsonEncode`).
  ///
  /// Define sempre:
  /// - `Content-Type: application/json`
  /// - `Accept: application/json`
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');
    return http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (headers != null) ...headers,
      },
      body: body,
    );
  }
}
