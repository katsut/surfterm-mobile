import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/command.dart';
import '../providers/connection_provider.dart';
import '../theme/catppuccin.dart';
import '../widgets/state_indicator.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  final _inputController = TextEditingController();
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
    _inputController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connectionProvider);
    final session = conn.sessionById(widget.sessionId);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(
          child: Text('Session not found', style: TextStyle(color: CatppuccinMocha.subtext0)),
        ),
      );
    }

    final lines = conn.terminalLinesFor(widget.sessionId);

    // Auto-read new terminal output if TTS is enabled
    if (_ttsEnabled && lines.length > _lastSpokenLineCount) {
      final newLines = lines.sublist(_lastSpokenLineCount);
      _lastSpokenLineCount = lines.length;
      final text = newLines.join(' ').trim();
      if (text.isNotEmpty) _tts.speak(text);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(session.projectName),
        actions: [
          IconButton(
            icon: Icon(_voiceMode ? Icons.keyboard : Icons.mic,
                color: _voiceMode ? CatppuccinMocha.green : null),
            tooltip: _voiceMode ? 'Text mode' : 'Voice mode',
            onPressed: () => setState(() {
              _voiceMode = !_voiceMode;
              if (!_voiceMode) {
                _speech.stop();
                _isListening = false;
              }
            }),
          ),
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off,
                color: _ttsEnabled ? CatppuccinMocha.blue : null),
            tooltip: _ttsEnabled ? 'Mute output' : 'Read output aloud',
            onPressed: () => setState(() {
              _ttsEnabled = !_ttsEnabled;
              _lastSpokenLineCount = conn.terminalLinesFor(widget.sessionId).length;
              if (!_ttsEnabled) _tts.stop();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch to this session',
            onPressed: () {
              conn.sendCommand(Command.switchSession(sessionId: session.id));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(session: session),
            const SizedBox(height: 12),
            Expanded(child: _TerminalView(lines: lines)),
            const SizedBox(height: 8),
            if (_voiceMode)
              _VoiceInput(
                voiceText: _voiceText,
                isListening: _isListening,
                sending: _sending,
                onStartListening: _startListening,
                onStopListening: _stopListening,
                onSend: () => _sendVoice(conn),
              )
            else
              _TextInput(
                controller: _inputController,
                sending: _sending,
                onSend: () => _sendText(conn),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendText(dynamic conn) async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await conn.sendCommand(
      Command.respond(sessionId: widget.sessionId, payload: text),
    );
    _inputController.clear();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendVoice(dynamic conn) async {
    if (_voiceText.isEmpty) return;
    setState(() => _sending = true);
    await conn.sendCommand(
      Command.respond(sessionId: widget.sessionId, payload: _voiceText),
    );
    setState(() {
      _voiceText = '';
      _sending = false;
    });
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech error: $error');
        setState(() => _isListening = false);
      },
    );
    if (!available) return;
    setState(() {
      _isListening = true;
      _voiceText = '';
    });
    await _speech.listen(
      onResult: (result) => setState(() => _voiceText = result.recognizedWords),
      localeId: 'en_US',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }
}

class _InfoCard extends StatelessWidget {
  final dynamic session;
  const _InfoCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(session.projectName,
                style: const TextStyle(
                    color: CatppuccinMocha.text, fontSize: 16, fontWeight: FontWeight.w600)),
            StateIndicator(state: session.state),
          ],
        ),
      ),
    );
  }
}

class _TerminalView extends StatelessWidget {
  final List<String> lines;
  const _TerminalView({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: CatppuccinMocha.base,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          lines.join('\n'),
          style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: CatppuccinMocha.text),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _TextInput({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: CatppuccinMocha.text),
          decoration: const InputDecoration(hintText: 'Send to terminal...'),
          onSubmitted: (_) => onSend(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.crust))
                : const Icon(Icons.send),
            label: Text(sending ? 'Sending...' : 'Send'),
          ),
        ),
      ],
    );
  }
}

class _VoiceInput extends StatelessWidget {
  final String voiceText;
  final bool isListening;
  final bool sending;
  final VoidCallback onStartListening;
  final VoidCallback onStopListening;
  final VoidCallback onSend;

  const _VoiceInput({
    required this.voiceText,
    required this.isListening,
    required this.sending,
    required this.onStartListening,
    required this.onStopListening,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CatppuccinMocha.surface0,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            voiceText.isEmpty ? 'Tap mic to speak...' : voiceText,
            style: TextStyle(
              color: voiceText.isEmpty ? CatppuccinMocha.subtext0 : CatppuccinMocha.text,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isListening ? onStopListening : onStartListening,
                icon: Icon(isListening ? Icons.stop : Icons.mic),
                label: Text(isListening ? 'Stop' : 'Listen'),
                style: FilledButton.styleFrom(
                  backgroundColor: isListening ? CatppuccinMocha.red : CatppuccinMocha.blue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: voiceText.isEmpty || sending ? null : onSend,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
