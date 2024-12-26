import 'package:flutter/material.dart';
import 'package:gemini_ai/gemini_ai.dart';
import 'package:gemini_ai/enum/block_threshold.dart';
import 'package:gemini_ai/enum/harm_category.dart';
import 'package:gemini_ai/model/generation_config.dart';
import 'package:gemini_ai/model/generative_model.dart';
import 'package:gemini_ai/model/safety_setting.dart';

class GeminiConfig {
  static final GenerativeModel generativeModel = GenerativeModel(
    modelName: "gemini-pro",
    apiKey: "AIzaSyCZ1h1h3zdZw0ePPdz-XVyAgkY_izAD-yQ",

    generationConfig: _generationConfig,
    safetySettings: _safetySettings,

  );

  static final GenerationConfig _generationConfig = GenerationConfig(
    temperature: 0.9,
    topK: 1,
    topP: 1,
    // maxOutputTokens: 2048,
    maxOutputTokens: 200,

  );

  static final List<SafetySetting> _safetySettings = [
    SafetySetting(
      HarmCategory.harassment,
      BlockThreshold.mediumAndAbove,
    ),
    SafetySetting(
      HarmCategory.hateSpeech,
      BlockThreshold.mediumAndAbove,
    ),
    SafetySetting(
      HarmCategory.sexuallyExplicit,
      BlockThreshold.mediumAndAbove,
    ),
    SafetySetting(
      HarmCategory.dangerousContent,
      BlockThreshold.mediumAndAbove,

    ),
  ];
}


enum _State { idle, loading }

class GeminiChat extends StatefulWidget {
  const GeminiChat({super.key});

  @override
  State<GeminiChat> createState() => _GeminiChatState();
}

class _GeminiChatState extends State<GeminiChat> {
  final TextEditingController _inputController = TextEditingController();

  final GeminiAi _gemini = GeminiAi();

  String _content = "";
  _State _state = _State.idle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gemini Demo"),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: _state == _State.loading
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_content),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    labelText: "Ask to Gemini...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _generateContent,
            ),
          ],
        ),
      ],
    );
  }

  void _generateContent() async {
    setState(() {
      _state = _State.loading;
    });
    String? content = await _gemini.generateContent(
      GeminiConfig.generativeModel,
      _inputController.text.trim(),
    );
    if (content != null) {
      setState(() {
        _content = content;
        _state = _State.idle;
        _inputController.clear();
      });
    }
  }
}