import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// --- UUIDs definidos en el código del ESP32 ---
final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid cmdCharacteristicUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
final Guid dataCharacteristicUuid =
    Guid("cba1d466-344c-4be3-ab3f-189f80dd7518");

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const PresionArterialApp());
}

class AppColors {
  static const Color tealPrimary = Color(0xFF009688);
  static const Color tealDark = Color(0xFF004D40);
  static const Color tealLight = Color(0xFFE0F2F1);
  static const Color tealAccent = Color(0xFF26A69A);
}

class PresionArterialApp extends StatelessWidget {
  const PresionArterialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Cardio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.tealPrimary),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              flex: 2,
              child: Center(
                child: Icon(Icons.favorite, size: 120, color: Colors.white),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Mi Cardio',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tealDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¡No olvides tomar tu presion arterial!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tealPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ));
                        },
                        child: const Text('Iniciar Sesión'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.tealPrimary,
                          side: const BorderSide(color: AppColors.tealPrimary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const DeviceScanScreen(),
                          ));
                        },
                        child: const Text('Chequeo Rápido'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                const AuthScreen(initialTab: 1),
                          ));
                        },
                        child: const Text(
                          '¿No tienes una cuenta? ¡Regístrate!',
                          style: TextStyle(color: AppColors.tealPrimary),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      final uniqueResults = <String, ScanResult>{};
      for (var r in results) {
        if (r.device.platformName.isNotEmpty) {
          uniqueResults[r.device.remoteId.toString()] = r;
        }
      }
      if (mounted) {
        setState(() {
          _scanResults = uniqueResults.values.toList();
        });
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {
          _isScanning = state;
        });
      }
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 1. Pedir permisos
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    var locationStatus = await Permission.location.request();

    if (!mounted) return;

    // 2. Verificar si los permisos fueron otorgados
    if (!bluetoothConnectStatus.isGranted ||
        !bluetoothScanStatus.isGranted ||
        !locationStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Se necesitan todos los permisos para buscar dispositivos.')),
      );
      return;
    }

    // 3. Verificar si el Bluetooth está encendido
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, activa el Bluetooth de tu teléfono.')),
      );
      return;
    }

    setState(() {
      _scanResults = [];
    });

    // 4. Si todo está bien, iniciar escaneo
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  void _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => MonitorScreen(device: device),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar: $e')),
        );
      }
    }
  }

  Widget _buildDeviceTile(ScanResult result) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(result.device.platformName.isNotEmpty
            ? result.device.platformName
            : "Dispositivo Desconocido"),
        subtitle: Text(result.device.remoteId.toString()),
        leading: const Icon(Icons.monitor_heart_outlined,
            color: AppColors.tealPrimary),
        trailing: ElevatedButton(
          onPressed: () => _connectToDevice(result.device),
          child: const Text('Conectar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar Dispositivo')),
      body: Center(
        child: Column(
          children: [
            if (_isScanning) const LinearProgressIndicator(),
            Expanded(
              child: _scanResults.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          _isScanning
                              ? 'Buscando tu tensiómetro...'
                              : 'Presiona el botón de búsqueda para encontrar tu dispositivo.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        return _buildDeviceTile(_scanResults[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  final BluetoothDevice device;
  const MonitorScreen({super.key, required this.device});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with SingleTickerProviderStateMixin {
  String _statusText = 'Conectado';
  int _sistolica = 0;
  int _diastolica = 0;
  bool _isMeasuring = false;
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  BluetoothCharacteristic? _cmdCharacteristic;
  BluetoothCharacteristic? _dataCharacteristic;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          setState(() {
            _statusText = 'Desconectado';
          });
          Navigator.of(context).pop();
        }
      }
    });
    _discoverServicesAndListen();
  }

  void _discoverServicesAndListen() async {
    try {
      setState(() {
        _statusText = 'Descubriendo servicios...';
      });
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == cmdCharacteristicUuid) {
              _cmdCharacteristic = characteristic;
            }
            if (characteristic.uuid == dataCharacteristicUuid) {
              _dataCharacteristic = characteristic;
            }
          }
        }
      }

      if (_dataCharacteristic != null && _cmdCharacteristic != null) {
        setState(() {
          _statusText = 'Listo para medir';
        });
        await _dataCharacteristic!.setNotifyValue(true);
        _dataSubscription =
            _dataCharacteristic!.lastValueStream.listen((value) {
          if (value.isEmpty) return;
          String data = utf8.decode(value, allowMalformed: true);
          try {
            Map<String, dynamic> jsonData = jsonDecode(data);
            if (mounted) {
              setState(() {
                _sistolica = jsonData['sistolica'];
                _diastolica = jsonData['diastolica'];
                _isMeasuring = false;
                _animationController.stop();
                _statusText = "Medición Recibida";
              });
            }
          } catch (e) {
            print("Error al parsear JSON: $e");
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Error: $e';
        });
      }
    }
  }

  void _sendStartCommand() async {
    if (_cmdCharacteristic != null) {
      setState(() {
        _statusText = 'Preparando nueva medición...';
        _sistolica = 0;
        _diastolica = 0;
        _isMeasuring = true;
        _animationController.repeat(reverse: true);
      });

      await Future.delayed(const Duration(seconds: 2));

      List<int> bytes = utf8.encode("START");
      await _cmdCharacteristic!.write(bytes);
      if (mounted) {
        setState(() {
          _statusText = 'Midiendo...';
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dataSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    widget.device.disconnect();
    super.dispose();
  }

  Widget _buildMeasuringUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _animationController,
          child: const Icon(Icons.favorite, color: Colors.redAccent, size: 120),
        ),
        const SizedBox(height: 20),
        Text(
          'Midiendo...',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppColors.tealDark),
        ),
      ],
    );
  }

  Widget _buildResultsUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Sistólica',
            style: TextStyle(color: Colors.grey, fontSize: 20)),
        Text('$_sistolica',
            style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: AppColors.tealDark)),
        const SizedBox(height: 10),
        const Text('Diastólica',
            style: TextStyle(color: Colors.grey, fontSize: 20)),
        Text('$_diastolica',
            style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.tealDark)),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthScreen()),
              (Route<dynamic> route) => false,
            );
          },
          child: const Text(
            "¿Desea guardar la medida?",
            style: TextStyle(
                color: AppColors.tealPrimary,
                decoration: TextDecoration.underline),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealLight,
      appBar: AppBar(
        title: Text(widget.device.platformName,
            style: const TextStyle(color: AppColors.tealDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.tealDark),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_statusText,
                  style:
                      const TextStyle(color: AppColors.tealDark, fontSize: 16)),
              const Spacer(),
              Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5))
                  ],
                ),
                child: Center(
                  child: _isMeasuring ? _buildMeasuringUI() : _buildResultsUI(),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(_sistolica > 0
                    ? 'Realizar Nueva Medición'
                    : 'Iniciar Medición'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: _sendStartCommand,
              ),
              const SizedBox(height: 20),
              TextButton(
                child: const Text('Desconectar'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- PANTALLA DE AUTENTICACIÓN ---
class AuthScreen extends StatefulWidget {
  final int initialTab;
  const AuthScreen({super.key, this.initialTab = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso de Usuario'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'INICIAR SESIÓN'),
            Tab(text: 'REGISTRARSE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LoginTab(),
          const RegisterTab(),
        ],
      ),
    );
  }
}

class LoginTab extends StatelessWidget {
  LoginTab({super.key});

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
                labelText: 'Email', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
                labelText: 'Contraseña', border: OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 24.0),
          ElevatedButton(
            onPressed: () {
              // TODO: Lógica de inicio de sesión con Firebase
            },
            child: const Text('Iniciar Sesión'),
          ),
        ],
      ),
    );
  }
}

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

enum UserRole { medico, paciente }

class _RegisterTabState extends State<RegisterTab> {
  UserRole? _role = UserRole.paciente;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder())),
            const SizedBox(height: 16.0),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16.0),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Contraseña', border: OutlineInputBorder()),
                obscureText: true),
            const SizedBox(height: 16.0),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Cédula de Identidad',
                    border: OutlineInputBorder())),
            const SizedBox(height: 24.0),
            Text('Soy:', style: Theme.of(context).textTheme.titleMedium),
            RadioListTile<UserRole>(
              title: const Text('Médico'),
              value: UserRole.medico,
              groupValue: _role,
              onChanged: (UserRole? value) {
                setState(() {
                  _role = value;
                });
              },
            ),
            RadioListTile<UserRole>(
              title: const Text('Paciente'),
              value: UserRole.paciente,
              groupValue: _role,
              onChanged: (UserRole? value) {
                setState(() {
                  _role = value;
                });
              },
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: () {
                // TODO: Lógica de registro con Firebase
              },
              child: const Text('Registrarse'),
            ),
          ],
        ),
      ),
    );
  }
}
