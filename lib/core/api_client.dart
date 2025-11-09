import 'package:dio/dio.dart';
//importing the dio http client library

class ApiClient {
  static Dio dio = Dio( //creating a dio instance
    BaseOptions(
      baseUrl: "https://staging.chamberofsecrets.8club.co/v1/",//default server path for reusability
      connectTimeout: const Duration(seconds: 20),//prevents endless loading if API is slow
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,//since the API returns a json always we use this to always expect only json responses
    ),
  );
}