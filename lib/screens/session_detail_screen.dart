import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/command.dart';
import '../models/session.dart';
import '../services/ble_service.dart';
import '../theme/catppuccin.dart';
import '../widgets/state_indicator.dart';

/// Detail screen for a single session.
class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _responseController = TextEditingController();
  bool _sending = false;

  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _voiceMode = false;
  bool _isListening = false;
  String _voiceText = '';
  bool _ttsEnabled = false;
  int _lastSpokenLineCount = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  @override
  void dispose() {
    _responseController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final session = ble.sessionById(widget.sessionId);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(
          child: Text(
            'Session not found',
            style: TextStyle(color: CatppuccinMocha.subtext0),
          ),
        ),
      );
    }

    // Auto-read new terminal output if TTS is enabled
    if (_ttsEnabled && ble.terminalLines.length > _lastSpokenLineCount) {
      final newLines = ble.terminalLines.sublist(_lastSpokenLineCount);
      _lastSpokenLineCount = ble.terminalLines.length;
      final text = newLines.join(' ').trim();
      if (text.isNotEmpty) {
        _tts.speak(text);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(session.projectName),
        actions: [
          // Voice mode toggle
          IconButton(
            icon: Icon(
              _voiceMode ? Icons.keyboard : Icons.mic,
              color: _voiceMode ? CatppuccinMocha.green : null,
            ),
            tooltip: _voiceMode ? 'Text mode' : 'Voice mode',
            onPressed: () => setState(() {
              _voiceMode = !_voiceMode;
              if (!_voiceMode) {
                _speech.stop();
                _isListening = false;
              }
            }),
          ),
          // TTS toggle
          IconButton(
            icon: Icon(
              _ttsEnabled ? Icons.volume_up : Icons.volume_off,
              color: _ttsEnabled ? CatppuccinMocha.blue : null,
            ),
            tooltip: _ttsEnabled ? 'Mute output' : 'Read output aloud',
            onPressed: () => setState(() {
              _ttsEnabled = !_ttsEnabled;
              _lastSpokenLineCount = ble.terminalLines.length;
              if (!_ttsEnabled) _tts.stop();
            }),
          ),
          // Switch session
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch to this session',
            onPressed: () {
              ble.sendCommand(
                BleCommand.switchSession(sessionId: session.id),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info
            _buildInfoCard(session),

            const SizedBox(height: 12),

            // Terminal output
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CatppuccinMocha.base,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    ble.terminalLines.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: CatppuccinMocha.text,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Input area — text or voice
            if (_voiceMode)
              _buildVoiceInput(ble, session)
            else
              _buildTextInput(ble, session),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput(BleService ble, SessionStatus session) {
    return Column(
      children: [
        TextField(
          controller: _responseController,
          style: const TextStyle(color: CatppuccinMocha.text),
          decoration: const InputDecoration(
            hintText: 'Send to terminal...',
          ),
          onSubmitted: (_) => _sendResponse(ble, session),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sending ? null : () => _sendResponse(ble, session),
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CatppuccinMocha.crust,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Sending...' : 'Send'),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceInput(BleService ble, SessionStatus session) {
    return Column(
      children: [
        // Voice text preview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CatppuccinMocha.surface0,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _voiceText.isEmpty ? 'Tap mic to speak...' : _voiceText,
            style: TextStyle(
              color: _voiceText.isEmpty
                  ? CatppuccinMocha.subtext0
                  : CatppuccinMocha.text,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Mic button
            Expanded(
              child: FilledButton.icon(
                onPressed: _isListening ? _stopListening : _startListening,
                icon: Icon(_isListening ? Icons.stop : Icons.mic),
                label: Text(_isListening ? 'Stop' : 'Listen'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _isListening ? CatppuccinMocha.red : CatppuccinMocha.blue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Expanded(
              child: FilledButton.icon(
                onPressed: _voiceText.isEmpty || _sending
                    ? null
                    : () => _sendVoice(ble, session),
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech error: $error');
        setState(() => _isListening = false);
      },
    );

    if (!available) {
      debugPrint('Speech recognition not available');
      return;
    }

    setState(() {
      _isListening = true;
      _voiceText = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _voiceText = result.recognizedWords;
        });
      },
      localeId: 'en_US',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _sendVoice(BleService ble, SessionStatus session) async {
    if (_voiceText.isEmpty) return;

    setState(() => _sending = true);

    await ble.sendCommand(
      BleCommand.respond(sessionId: session.id, payload: _voiceText),
    );

    setState(() {
      _voiceText = '';
      _sending = false;
    });
  }

  Widget _buildInfoCard(SessionStatus session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              session.projectName,
              style: const TextStyle(
                color: CatppuccinMocha.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            StateIndicator(state: session.state),
          ],
        ),
      ),
    );
  }

  Future<void> _sendResponse(BleService ble, SessionStatus session) async {
    final text = _responseController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    await ble.sendCommand(
      BleCommand.respond(sessionId: session.id, payload: text),
    );

    _responseController.clear();

    if (mounted) {
      setState(() => _sending = false);
    }
  }
}
