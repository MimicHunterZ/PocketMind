import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/util/logger_service.dart';

const String _tag = 'A2uiStreamApiService';
const String _demoA2uiStreamApi = '/api/demo/a2ui/stream';

final a2uiStreamApiServiceProvider = Provider<A2uiStreamApiService>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return A2uiStreamApiService(httpClient);
});

sealed class A2uiSseEvent {
  const A2uiSseEvent();
}

final class A2uiDeltaEvent extends A2uiSseEvent {
  const A2uiDeltaEvent(this.data);

  final String data;
}

final class A2uiDoneEvent extends A2uiSseEvent {
  const A2uiDoneEvent({this.messageUuid, this.requestId});

  final String? messageUuid;
  final String? requestId;
}

final class A2uiErrorEvent extends A2uiSseEvent {
  const A2uiErrorEvent(this.message);

  final String message;
}

class A2uiStreamApiService {
  A2uiStreamApiService(this._http);

  final HttpClient _http;

  Stream<A2uiSseEvent> stream({
    required String query,
    String? requestId,
    CancelToken? cancelToken,
  }) async* {
    late final Response<ResponseBody> response;
    try {
      response = await _http.dio.post<ResponseBody>(
        _demoA2uiStreamApi,
        data: jsonEncode({'query': query}),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 5),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            if (requestId != null && requestId.isNotEmpty)
              'X-Request-Id': requestId,
          },
        ),
      );
    } on DioException catch (e) {
      PMlog.e(_tag, 'A2UI SSE 请求失败: $e');
      yield A2uiErrorEvent(e.message ?? '网络请求失败');
      return;
    }

    yield* _parseSseStream(response.data!.stream, cancelToken);
  }

  Stream<A2uiSseEvent> _parseSseStream(
    Stream<List<int>> rawStream,
    CancelToken? cancelToken,
  ) async* {
    final lineBuffer = StringBuffer();
    String? currentEvent;
    final dataLines = <String>[];

    A2uiSseEvent? buildEvent(String? event, List<String> lines) {
      if (event == null || lines.isEmpty) {
        return null;
      }
      final data = lines.join('\n');
      switch (event) {
        case 'delta':
          return A2uiDeltaEvent(data);
        case 'done':
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            return A2uiDoneEvent(
              messageUuid: json['messageUuid'] as String?,
              requestId: json['requestId'] as String?,
            );
          } catch (_) {
            return const A2uiDoneEvent();
          }
        case 'error':
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            return A2uiErrorEvent(json['message'] as String? ?? 'A2UI 服务异常');
          } catch (_) {
            return A2uiErrorEvent(data);
          }
        default:
          return null;
      }
    }

    Stream<A2uiSseEvent> parseLine(String rawLine) async* {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        final event = buildEvent(currentEvent, dataLines);
        currentEvent = null;
        dataLines.clear();
        if (event != null) {
          yield event;
        }
        return;
      }
      if (line.startsWith(':')) {
        return;
      }
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        return;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    try {
      await for (final textChunk in utf8.decoder.bind(rawStream)) {
        if (cancelToken != null && cancelToken.isCancelled) {
          break;
        }

        lineBuffer.write(textChunk);
        final merged = lineBuffer.toString();
        final lines = merged.split(RegExp(r'\r?\n'));
        lineBuffer
          ..clear()
          ..write(lines.removeLast());

        for (final line in lines) {
          await for (final event in parseLine(line)) {
            yield event;
          }
        }
      }

      if (lineBuffer.isNotEmpty) {
        await for (final event in parseLine(lineBuffer.toString())) {
          yield event;
        }
      }
      final trailing = buildEvent(currentEvent, dataLines);
      if (trailing != null) {
        yield trailing;
      }
    } catch (e) {
      if (cancelToken != null && cancelToken.isCancelled) {
        return;
      }
      PMlog.e(_tag, 'A2UI SSE 流读取异常: $e');
      yield A2uiErrorEvent(e.toString());
    }
  }

  Stream<A2uiSseEvent> parseForTest(
    Stream<List<int>> rawStream,
    CancelToken? cancelToken,
  ) => _parseSseStream(rawStream, cancelToken);
}
