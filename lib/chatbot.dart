import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:amanak/services/database_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:amanak/l10n/app_localizations.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatBot extends StatefulWidget {
  static const routeName = "chatbot";

  const ChatBot({super.key});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final TextEditingController _controller = TextEditingController();
  final List<Content> _messages = [];
  final gemini = Gemini.instance;
  bool _isLoading = false;

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        // Use app's current language for speech recognition
        String localeId = Localizations.localeOf(context).languageCode == 'ar'
            ? 'ar_EG' // Arabic (Egypt)
            : 'en_US'; // English (US)
        _speech.listen(
          localeId: localeId,
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
              _lastWords = val.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final isLandscape = media.orientation == Orientation.landscape;
    final bubbleMaxWidth = screenWidth * 0.7;
    final baseFontSize = screenWidth * 0.045;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.chatbot,
          style: GoogleFonts.albertSans(
            fontSize: screenWidth * 0.06,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: screenHeight * 0.22,
                      child: Lottie.asset('assets/animations/chatbot.json',
                          fit: BoxFit.contain),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    Text(
                      AppLocalizations.of(context)!.chatbotGreeting,
                      style: GoogleFonts.albertSans(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (_messages.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.02,
                  horizontal: screenWidth * 0.03,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message.role == 'user';
                  final part = message.parts?.first;
                  final content =
                      part is TextPart ? part.text : part?.toString() ?? '';

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: screenHeight * 0.015,
                      left: isUser ? screenWidth * 0.15 : 0,
                      right: isUser ? 0 : screenWidth * 0.15,
                    ),
                    child: Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.015,
                            horizontal: screenWidth * 0.04,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: screenHeight * 0.001,
                              horizontal: screenWidth * 0.01,
                            ),
                            child: Text(
                              content,
                              style: GoogleFonts.albertSans(
                                fontSize: baseFontSize,
                                color: isUser ? Colors.white : Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(bottom: screenHeight * 0.02),
              child: const CircularProgressIndicator(),
            ),

          // Input area
          Container(
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.01,
              horizontal: screenWidth * 0.03,
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    cursorColor: Theme.of(context).primaryColor,
                    controller: _controller,
                    style: TextStyle(fontSize: baseFontSize),
                    decoration: InputDecoration(
                        enabled: true,
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.015,
                          horizontal: screenWidth * 0.04,
                        ),
                        hintText: "Type a message",
                        hintStyle: GoogleFonts.albertSans(
                          fontSize: 18,
                          color: Color(0xFFA1A8B0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        )),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Container(
                  height: screenHeight * 0.06,
                  width: screenHeight * 0.06,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send,
                        size: baseFontSize * 1.2, color: Colors.white),
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) sendMessage(text);
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.01),
                Container(
                  height: screenHeight * 0.06,
                  width: screenHeight * 0.06,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.redAccent
                        : Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: InkWell(
                    child: IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                          size: baseFontSize * 1.2, color: Colors.white),
                      onPressed: _listen,
                    ),
                    onTap: _listen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sendMessage(String text) async {
    setState(() {
      _isLoading = true;
      _messages.add(Content(parts: [Part.text(text)], role: 'user'));
    });

    try {
      final response = await gemini.chat(_messages);
      if (response != null && response.output != null) {
        _messages
            .add(Content(parts: [Part.text(response.output!)], role: 'model'));
      }
    } catch (e) {
      _messages.add(Content(parts: [Part.text("Error: $e")], role: 'model'));
    }

    setState(() {
      _isLoading = false;
      _controller.clear();
    });
  }
}
