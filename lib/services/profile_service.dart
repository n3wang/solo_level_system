import 'api_client.dart';

class ProfileHandleResult {
  ProfileHandleResult({this.handle, this.error});

  final String? handle;
  final String? error;

  bool get success => error == null;
}

/// Thin wrapper over `/api/profile/handle` for claiming/renaming the public
/// solo-leveling profile handle (see [SoloSyncService] for the sharing
/// settings that gate what that public page shows).
class ProfileService {
  ProfileService({ApiClient? client}) : _client = client ?? ApiClient();

  static final ProfileService instance = ProfileService();

  final ApiClient _client;

  Future<String?> fetchHandle() async {
    try {
      final response = await _client.get('/api/profile/handle');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = decodeJsonMap(response.body);
      final handle = body['handle'];
      return handle is String && handle.isNotEmpty ? handle : null;
    } catch (_) {
      return null;
    }
  }

  Future<ProfileHandleResult> claimHandle(
    String handle, {
    String? displayName,
  }) async {
    try {
      final response = await _client.put('/api/profile/handle', {
        'handle': handle,
        if (displayName != null) 'displayName': displayName,
      });
      final body = decodeJsonMap(response.body);
      if (response.statusCode == 409) {
        return ProfileHandleResult(error: 'That handle is already taken.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ProfileHandleResult(
          error: body['error']?.toString() ?? 'Could not claim handle.',
        );
      }
      final claimed = body['handle']?.toString();
      if (claimed == null || claimed.isEmpty) {
        return ProfileHandleResult(error: 'Could not claim handle.');
      }
      return ProfileHandleResult(handle: claimed);
    } on ApiException catch (e) {
      return ProfileHandleResult(error: e.message);
    } catch (_) {
      return ProfileHandleResult(error: 'No connection to server.');
    }
  }
}
