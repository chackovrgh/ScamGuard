import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: ScamGuardHome()));

class ScamGuardHome extends StatefulWidget {
  const ScamGuardHome({super.key});
  @override
  State<ScamGuardHome> createState() => _ScamGuardHomeState();
}

class _ScamGuardHomeState extends State<ScamGuardHome> with SingleTickerProviderStateMixin {
  final TextEditingController _ipController = TextEditingController(text: "10.0.2.2");
  final TextEditingController _textController = TextEditingController();

  int _selectedIndex = 0; // 0=Audio, 1=Image, 2=Text
  bool isLoading = false;
  bool isRecording = false;
  
  // Results
  String verdict = "READY";
  String reason = "System active. Waiting for input analysis.";
  double riskScore = 0.0; // 0 to 100
  Color statusColor = Colors.cyanAccent;

  late AudioRecorder audioRecorder;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Auto-detect environment for clearer defaults
    if (!Platform.isAndroid) {
      _ipController.text = "127.0.0.1";
    }
    
    audioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500)
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    audioRecorder.dispose();
    super.dispose();
  }

  // --- API LOGIC ---
  Future<void> sendData({String? audioPath, File? imageFile, String? textMessage}) async {
    setState(() { 
      isLoading = true; 
      verdict = "ANALYZING..."; 
      reason = "Processing multimodal data streams...";
      statusColor = Colors.cyan; 
    });

    try {
      final url = "http://${_ipController.text}:5000/detect";
      var request = http.MultipartRequest('POST', Uri.parse(url));

      if (audioPath != null) {
        request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
      } else if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      } else if (textMessage != null) {
        request.fields['text'] = textMessage;
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        var json = jsonDecode(respStr);
        
        setState(() {
          String finalV = json['final_verdict'];
          verdict = finalV;
          
          if (finalV == "SCAM") {
            statusColor = const Color(0xFFFF2E2E); // Bright Red
            reason = "CRITICAL THREAT: ${json['gemini_analysis']['reasoning']}";
          } else if (finalV == "SUSPICIOUS") {
            statusColor = Colors.orangeAccent;
            reason = "WARNING: ${json['gemini_analysis']['reasoning']}";
          } else {
            statusColor = const Color(0xFF00FF88); // Neon Green
            reason = "No threat detected. ${json['gemini_analysis']['reasoning']}";
          }
          
          // Parse debug score if available
          if (json['fusion_debug'] != null) {
             riskScore = (json['fusion_debug']['final_score'] as num).toDouble();
          } else {
             riskScore = finalV == "SCAM" ? 90 : 10;
          }
        });
      } else {
        setState(() { verdict = "ERROR"; reason = "Server Error: ${response.statusCode}"; statusColor = Colors.orange; });
      }
    } catch (e) {
      setState(() { verdict = "OFFLINE"; reason = "Could not connect to Edge Server via ${_ipController.text}"; statusColor = Colors.grey; });
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- HANDLERS ---
  Future<void> handleAudio() async {
    if (isRecording) {
      final path = await audioRecorder.stop();
      setState(() => isRecording = false);
      if (path != null) sendData(audioPath: path);
    } else {
      if (await Permission.microphone.request().isGranted) {
        final dir = await getApplicationDocumentsDirectory();
        String path = '${dir.path}/scan.m4a';
        await audioRecorder.start(const RecordConfig(), path: path);
        setState(() => isRecording = true);
      }
    }
  }

  Future<void> handleAudioUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'wav']);
    if (result != null && result.files.single.path != null) {
      sendData(audioPath: result.files.single.path!);
    }
  }

  Future<void> handleImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) sendData(imageFile: File(image.path));
  }

  Future<void> handleText() async {
    if (_textController.text.isNotEmpty) {
      sendData(textMessage: _textController.text);
      FocusScope.of(context).unfocus(); // Close keyboard
    }
  }

  // --- WIDGETS ---
  Widget _buildGlassCard(Widget child, {Color borderColor = Colors.white10}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: borderColor.withOpacity(0.1), blurRadius: 20, spreadRadius: 1)
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black, // Fallback
      appBar: AppBar(
        title: const Text("S C A M G U A R D", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Connectivity Settings", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Server IP", 
                      labelStyle: TextStyle(color: Colors.grey), 
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text("• Emulator: 10.0.2.2", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const Text("• Desktop: 127.0.0.1", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const Text("• Physical Device: Use PC's LAN IP", style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            )),
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]
              )
            ),
          ),
          
          // 2. Main Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            
                            // RESULT DISPLAY
                            SizedBox(
                              width: double.infinity,
                              child: _buildGlassCard(
                                Column(
                                  children: [
                                     // Status Icon with Glow
                                     Container(
                                       decoration: BoxDecoration(
                                         shape: BoxShape.circle,
                                         boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 40, spreadRadius: 5)]
                                       ),
                                       child: Icon(
                                         verdict == "SAFE" ? Icons.verified_user : (verdict == "SCAM" ? Icons.dangerous : Icons.shield), 
                                         size: 64, 
                                         color: statusColor
                                       ),
                                     ),
                                     const SizedBox(height: 16),
                                     Text(verdict, style: TextStyle(color: statusColor, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5), textAlign: TextAlign.center),
                                     const SizedBox(height: 12),
                                     Text(reason, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4)),
                                     
                                     if (verdict != "READY" && verdict != "ANALYZING")
                                       Padding(
                                         padding: const EdgeInsets.only(top: 15),
                                         child: LinearProgressIndicator(value: riskScore/100, backgroundColor: Colors.white10, color: statusColor, minHeight: 6, borderRadius: BorderRadius.circular(10)),
                                       )
                                  ],
                                ),
                                borderColor: statusColor
                              ),
                            ),
          
                            const Spacer(),
                            
                            if (isLoading) 
                               const CircularProgressIndicator(color: Colors.white54)
                            else
                               // DYNAMIC INPUT AREA 
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _buildInputSection(),
                              ),
          
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          )
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navBtn(0, Icons.mic, "Voice"),
            _navBtn(1, Icons.image, "Image"),
            _navBtn(2, Icons.chat, "Text"),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    if (_selectedIndex == 0) {
      return Column(
        children: [
          GestureDetector(
            onTap: handleAudio,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (ctx, child) {
                return Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isRecording)
                         BoxShadow(color: Colors.redAccent.withOpacity(0.5 - _pulseController.value*0.3), spreadRadius: _pulseController.value * 20, blurRadius: 20)
                    ],
                    gradient: LinearGradient(colors: isRecording ? [Colors.redAccent, Colors.red] : [Colors.cyan, Colors.blueAccent]),
                  ),
                  child: Icon(isRecording ? Icons.stop : Icons.mic, size: 40, color: Colors.white),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(isRecording ? "Listening..." : "Tap to Speak", style: const TextStyle(color: Colors.white54, letterSpacing: 1)),
          TextButton(onPressed: handleAudioUpload, child: const Text("OR UPLOAD FILE", style: TextStyle(color: Colors.white30, fontSize: 12)))
        ],
      );
    } else if (_selectedIndex == 1) {
      return Column(
        children: [
           InkWell(
             onTap: handleImage,
             child: Container(
               height: 150, width: double.infinity,
               decoration: BoxDecoration(
                 border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                 borderRadius: BorderRadius.circular(20),
                 color: Colors.white.withOpacity(0.05)
               ),
               child: const Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.add_photo_alternate, size: 40, color: Colors.white70),
                   SizedBox(height: 10),
                   Text("Analyze Screenshot", style: TextStyle(color: Colors.white38))
                 ],
               ),
             ),
           )
        ],
      );
    } else {
      return Column(
        children: [
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              hintText: "Paste suspicious message content...",
              hintStyle: const TextStyle(color: Colors.white24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: handleText, child: const Text("ANALYZE TEXT CONTENT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))
        ],
      );
    }
  }

  Widget _navBtn(int index, IconData icon, String label) {
    bool isSel = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() { _selectedIndex = index; verdict = "READY"; reason = "System active. Waiting for input analysis."; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20)
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSel ? Colors.cyanAccent : Colors.white24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSel ? Colors.cyanAccent : Colors.white24, fontSize: 10))
          ],
        ),
      ),
    );
  }
}
