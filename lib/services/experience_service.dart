import 'package:assignment/core/api_client.dart';
import 'package:assignment/models/experience.dart';
import 'package:dio/dio.dart';
class ExperienceService {
  static Future<List<Experience>> getExperiences() async {
    try {
      final response = await ApiClient.dio.get(
        "experiences",
        queryParameters: {"active": true},
      );

      final data = response.data["data"]["experiences"] as List<dynamic>;
      return Experience.listFromJson(data);

    } on DioException catch (e) {
      print("API Error: ${e.message}");
      return [];
    } catch (e) {
      print("General Error: $e");
      return [];
    }
  }
}