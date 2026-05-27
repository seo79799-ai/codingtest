import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '위치 정보 확인 서비스',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LocationHomePage(),
    );
  }
}

class LocationHomePage extends StatefulWidget {
  const LocationHomePage({super.key});

  @override
  State<LocationHomePage> createState() => _LocationHomePageState();
}

class _LocationHomePageState extends State<LocationHomePage> {
  // 기기 선택 상태: 'Computer' 또는 'Mobile'
  String _deviceType = 'Computer';
  String _roadAddress = '';
  String _zipcode = '';
  bool _isLoading = false;

  // Google Maps API 키 (실제 사용 시 유효한 키로 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// 1단계: 위치 권한 확인 및 요청
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.')));
      }
      return false;
    }

    // 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 보안: 사용자에게 위치 정보 접근 권한 동의 요청 (위치정보법 준수)
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('위치 정보 접근 권한이 거부되었습니다.')));
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')));
      }
      return false;
    }

    return true;
  }

  /// 2단계: 좌표 수집 및 주소 변환
  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
      _roadAddress = '';
      _zipcode = '';
    });

    try {
      // 현재 위치 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ));

      // Google Maps Reverse Geocoding API 호출
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_apiKey&language=ko');

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final firstResult = results[0];
          String formattedAddress = firstResult['formatted_address'];

          // 우편번호 추출
          String postCode = '정보 없음';
          final components = firstResult['address_components'] as List;
          for (var component in components) {
            final types = component['types'] as List;
            if (types.contains('postal_code')) {
              postCode = component['long_name'];
              break;
            }
          }

          setState(() {
            _roadAddress = '[$_deviceType] $formattedAddress';
            _zipcode = postCode;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('주소 변환 실패: ${data['status']}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1단계: 기기 선택
              RadioGroup<String>(
                value: _deviceType,
                onChanged: (value) {
                  setState(() {
                    _deviceType = value!;
                  });
                },
                items: const [
                  RadioGroupItem(value: 'Computer', label: Text('컴퓨터 위치')),
                  RadioGroupItem(value: 'Mobile', label: Text('휴대폰 위치')),
                ],
              ),
              const SizedBox(height: 40),

              // 2단계: 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 20),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 20),
                      ),
              ),
              const SizedBox(height: 40),

              // 3단계: 결과 표시
              if (_roadAddress.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '도로명 주소: $_roadAddress',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '우편번호: $_zipcode',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Memory guideline: Use a RadioGroup pattern in Flutter 3.32+
class RadioGroupItem<T> {
  final T value;
  final Widget label;
  const RadioGroupItem({required this.value, required this.label});
}

class RadioGroup<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T?> onChanged;
  final List<RadioGroupItem<T>> items;

  const RadioGroup({
    super.key,
    required this.value,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((item) {
        return Row(
          children: [
            Radio<T>(
              value: item.value,
              groupValue: value,
              onChanged: onChanged,
            ),
            item.label,
            if (item != items.last) const SizedBox(width: 20),
          ],
        );
      }).toList(),
    );
  }
}
