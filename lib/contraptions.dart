import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:openai_dart/openai_dart.dart' as OAI;
import 'env.dart';

class Contraptions extends StatefulWidget {
  const Contraptions({super.key});
  @override
  State<StatefulWidget> createState() => _ContraptionsState();
}
class _ContraptionsState extends State<Contraptions> {
  _ContraptionsState();
  late final TextEditingController _description;
  Image? _image;
  Uint8List? _imagebytes;
  late final OAI.OpenAIClient client;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController();
    _image = null;
    _imagebytes = null;
    client = OAI.OpenAIClient(apiKey: Env.apiKey);
  }

  void _getImageFromFile() async {
    FilePickerResult? picture = await FilePicker.platform.pickFiles(
      type: FileType.image
    );
    if (picture?.files.single.bytes != null) {
      var tempbytes = picture!.files.single.bytes!;
      setState(() {
        _imagebytes = tempbytes;
        _image = Image.memory(picture!.files.single.bytes!);
      });
    }
  }

  void _getImageFromAPI() async {
    final imageModel = await client.createImage(
        request: OAI.CreateImageRequest(prompt: _description.text,
            model: OAI.CreateImageRequestModel.model(OAI.ImageModels.dallE3),
        quality: OAI.ImageQuality.hd, size: OAI.ImageSize.v1024x1024));
    if (imageModel.data.first.url != null) {
      setState(() {
        _image = Image.network(imageModel.data.first.url!);
        _imagebytes = null;
      });
    }
  }

  void _getTextFromImage() async {
    if (_image != null && _imagebytes != null) {
      base64Encode(_imagebytes!);
      final model = await client.createChatCompletion(request:
      OAI.CreateChatCompletionRequest(
        model: OAI.ChatCompletionModel.modelId('gpt-4-turbo'),
        messages: [
          OAI.ChatCompletionMessage.system(content: '''
          You are the number one mad scientist in the Philadelphia 
          metropolitan area. Your one great joy in life is to 
          whimsically describe contraptions presented to you in photos. 
          You are currently doing that right now.
          '''),
          OAI.ChatCompletionMessage.user(content: OAI.ChatCompletionMessageContentParts(
            [
              OAI.ChatCompletionMessageContentPart.text(text: 
              'Describe this contraption for me please'), 
              OAI.ChatCompletionMessageContentPart.image(imageUrl: 
              OAI.ChatCompletionMessageImageUrl(url:
              'data:image/jpeg;base64,${base64UrlEncode(_imagebytes!)}'))
            ]
          ))
        ], maxTokens: 500000
      )
      );
      setState(() {
        if (model.choices.first.message.content != null) {
          print(model.choices.first.message.content!);
          _description.text = model.choices.first.message.content!;
        }
      });
    }
  }

  void _getTextFromPrompt() async {
    if (_description.text != "") {
      final model = await client.createChatCompletion(request:
      OAI.CreateChatCompletionRequest(model:
      OAI.ChatCompletionModel.modelId('gpt-4o-mini'), messages: [
        OAI.ChatCompletionMessage.system(content: '''
          You are the contraption describer, turning whatever prompt you are 
          given into a complete contraption.'''),
        OAI.ChatCompletionMessage.user(content:
        OAI.ChatCompletionUserMessageContent.string(_description.text))
      ], maxTokens: 5000)
      );
      setState(() {
        _description.text = model.choices.first.message.content!;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.deepPurple,
          title: const Text('Contraptions')),
      body: Center(
        child: Column (
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null ? _image! : Placeholder(),
            Row(
              children: [
                ConButton(callback: _getImageFromFile, allowed: true,
                    text: 'Upload an Image'),
                ConButton(allowed: _description.text != '',
                    callback: _getImageFromAPI, text:
                    'Generate Image from Description')
              ],
            ),
            TextField(controller: _description, decoration:
            const InputDecoration(hintText: '''Describe your contraption or write a prompt and have it fully described''')
            , onSubmitted: (String s) {
              setState(() {
                _description.text = s;
              });
              },),
            Row(
              children: [
                ConButton(callback: _getTextFromImage, allowed:
                false, text: "Generate Description from Image"),
                ConButton(allowed: _description.text != '',
                    callback: _getTextFromPrompt, text:
                    'Generate Description from Prompt')
              ]
            )
          ],
        )
      )
    );
  }

}

class ConButton extends StatelessWidget {
  const ConButton({super.key, required this.allowed, required this.callback,
    required this.text});
  final bool allowed;
  final void Function() callback;
  final String text;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: allowed ? callback : null,
        style: TextButton.styleFrom(backgroundColor: allowed ? Colors.white :
        Colors.grey), child: Text(text));
  }
}