
import 'package:http/http.dart' as http;
import 'dart:convert';
class TikTokservice {

  TikTokservice();
  Future<String> fetchTikTokAccessToken() async {
    try {
      const url = 'https://open.tiktokapis.com/v2/oauth/token/';
      const headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cache-Control': 'no-cache',
      };
      const body = {
        'client_key': 'aw95aeb86u1rqdhj',
        'client_secret': 'B86bPuUVfkUtfXhXK1tuylmXi7m0aRZ3',
        'grant_type': 'client_credentials',
      };

      final response = await http.post(Uri.parse(url), headers: headers, body: body);
      print('reponse: $jsonDecode(response.body)');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        return accessToken;
      } else {
        print('Request failed with status: ${response.statusCode}');
        throw Exception('Failed to fetch access token');
      }
    } catch (error) {
      print('An error occurred: $error');
      rethrow; // Re-throw the error to allow for further handling
    }
  }


  Future<void> fetchTikTokAccessToken2() async {
    try {
      const url = 'https://open.tiktokapis.com/v2/oauth/token/';
      const headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cache-Control': 'no-cache',
      };
      const body = {
        'client_key': 'CLIENT_KEY',
        'client_secret': 'CLIENT_SECRET',
        'code': 'CODE',
        'grant_type': 'authorization_code',
        'redirect_uri': 'REDIRECT_URI',
      };

      final response = await http.post(
          Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract the access token from the response
        final accessToken = data['access_token'];
        print('Access token: $accessToken');
      }
    }catch (error) {
      print('An error occurred: $error');
// Handle network errors or other unexpected issues
    }
  }


        Future<void> fetchTikTokVideos() async {
    try {
      print('Request loading');
      const url = 'https://open.tiktokapis.com/v2/video/list/?fields=cover_image_url,id,title';
      const headers = {
        'Authorization': 'Bearer aw95aeb86u1rqdhj',
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'max_count': 20,
      });

      final response = await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Process the fetched TikTok video data here
        print(data);
      } else {
        print('Request failed with status: ${response.statusCode}');
        // Handle other error cases as needed
      }
    } catch (error) {
      print('An error occurred: $error');
// Handle network errors or other unexpected issues
    }
  }
}