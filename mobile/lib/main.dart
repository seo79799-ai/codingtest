// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/**
 * 단계별 설명:
 * 1. 위치 정보 수집 전 사용자 동의 구하는 팝업 (위치정보법 준수)
 * 2. geolocator 패키지를 사용하여 기기의 현재 좌표(위도, 경도) 획득
 * 3. Google Maps Reverse Geocoding API를 호출하여 좌표를 주소로 변환
 * 4. 선택된 기기 정보와 함께 화면에 결과(도로명 주소, 우편번호) 출력
 */

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단순 위치 확인',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _address = "[결과 기다림]";
  String _zipcode = "[결과 기다림]";
  String _deviceType = "computer"; // 기본값
  bool _isLoading = false;

  // 1단계: 위치 정보 수집 동의 팝업 및 권한 요청
  Future<void> _checkLocation() async {
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("위치 정보 이용 동의"),
        content: const Text("현재 위치 정보를 수집하여 주소를 확인하는 데 동의하십니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("거부")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("동의")),
        ],
      ),
    );

    if (consent != true) return;

    setState(() => _isLoading = true);

    try {
      if (!mounted) return;
      // 2단계: geolocator로 위치 수집
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      // 3단계: Google Maps Reverse Geocoding API 연동
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    const apiKey = "YOUR_GOOGLE_MAPS_API_KEY"; // 실제 API 키로 대체 필요
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko"
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == "OK" && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final prefix = _deviceType == "computer" ? "[컴퓨터 위치] " : "[휴대폰 위치] ";

        String postalCode = "정보 없음";
        for (var component in result['address_components']) {
          if ((component['types'] as List).contains("postal_code")) {
            postalCode = component['long_name'];
            break;
          }
        }

        setState(() {
          _address = "$prefix${result['formatted_address']}";
          _zipcode = postalCode;
        });
      } else {
        throw '주소를 찾을 수 없습니다.';
      }
    } else {
      throw 'API 요청 실패';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("단순 위치 정보 확인")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 기기 선택: 라디오 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: "computer",
                    groupValue: _deviceType,
                    onChanged: (value) => setState(() => _deviceType = value!),
                  ),
                  const Text("컴퓨터 위치"),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: "mobile",
                    groupValue: _deviceType,
                    onChanged: (value) => setState(() => _deviceType = value!),
                  ),
                  const Text("휴대폰 위치"),
                ],
              ),
              const SizedBox(height: 40),

              // 확인 버튼: 큰 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _checkLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("현재 위치 확인할까요?"),
              ),
              const SizedBox(height: 40),

              // 결과 표시
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("도로명 주소: $_address", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("우편번호: $_zipcode", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
