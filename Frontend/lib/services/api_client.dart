import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Indica se o frontend deve usar mocks de API em vez do backend real.
///
/// Este valor é lido de `--dart-define=USE_MOCK=true` no comando `flutter run`.
/// O próprio [ApiClient] **não** implementa mocks – outros serviços podem
/// consultar esta flag para decidir o que fazer.
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

/// Valor de `BASE_URL` injectado via `--dart-define` (override do config gerado).
///
/// Se estiver vazio, usa o valor do [AppConfig] gerado pelo spin-up script.
const String _envBase = String.fromEnvironment('BASE_URL', defaultValue: '');

/// URL base efectivamente usada pelo [ApiClient].
///
/// Ordem de prioridade:
/// 1. `BASE_URL` vindo de `--dart-define` (override manual)
/// 2. Valor do [AppConfig] gerado automaticamente pelo spin-up script
final String kBaseUrl = _envBase.isNotEmpty ? _envBase : AppConfig.apiBaseUrl;

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
