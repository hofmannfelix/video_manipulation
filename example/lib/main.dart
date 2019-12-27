import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:video_processing/video_processing.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(home: HomeScreen());
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  bool _isGenerating = false;
  String _inputAssetpath = "assets/test.mp4";
  String _outputFilepath;
  Duration _generationTime = Duration.zero;
  String _infoText = "";
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Video Timelapsing Example App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RaisedButton(
                child: Text("Show original video"),
                onPressed: _showOriginalVideo,
              ),
              RaisedButton(
                child: Text("Generate timelapse video"),
                onPressed: _isGenerating ? null : _generateTimelapse,
              ),
              RaisedButton(
                child: Text("Show timelapse video"),
                onPressed: _outputFilepath == null ? null : _showGeneratedVideo,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 40),
                child: Text(_infoText),
              ),
              if (_progress > 0.0) Text("Progress: ${(100 * _progress).floor()}%")
            ],
          ),
        ),
      ),
    );
  }

  _showOriginalVideo() => Navigator.of(this.context)
      .push(MaterialPageRoute(builder: (_) => Player(videoUrl: _inputAssetpath)));

  _showGeneratedVideo() => Navigator.of(this.context)
      .push(MaterialPageRoute(builder: (_) => Player(videoUrl: _outputFilepath)));

  _generateTimelapse() async {
    final inputFilename = "test.mp4";
    final outputFilename = "test-processed.mp4";
    final inputAsset = "assets/$inputFilename";
    final docDir = (await getApplicationDocumentsDirectory()).path;
    final inputFilepath = join(docDir, inputFilename);
    final outputFilepath = join(docDir, outputFilename);

    _infoText = "Generating Video with different speeds...";
    setState(() => _isGenerating = true);

    print("Clean up documents directory");
    if (await File(inputFilepath).exists()) await File(inputFilepath).delete();
    if (await File(outputFilepath).exists()) await File(outputFilepath).delete();

    print("Copy input file to documents directory");
    final data = await rootBundle.load(inputAsset);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(inputFilepath).writeAsBytes(bytes);

    print("Start generating video");
    try {
      final start = DateTime.now();
//      final settings = Iterable.generate(10 * 60).map((i) {
//        final start = Duration(milliseconds: (i * 1000.0 / 10.0).toInt());
//        final end = Duration(milliseconds: ((i + 1) * 1000.0 / 10.0).toInt());
//        final text = start.toString();
//        return VideoProcessSettings(start: start, end: end, text: text);
//      }).toList();

      final settings = [VideoProcessSettings(start: Duration.zero, end: Duration(seconds: 10), text: "hey")];

      _outputFilepath = await VideoProcessing.processVideo(
          inputPath: inputFilepath, outputPath: outputFilepath, settings: settings);

      _generationTime = DateTime.now().difference(start);

      print("Completed video generation");
      _infoText = "Generation took ${_generationTime.inSeconds} seconds";
      if (mounted) setState(() => _isGenerating = false);
    } catch(e, s) {
      print(e);
      print(s);
    }
  }
}

class Player extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;
  final bool isLooped;

  Player({this.videoUrl, this.width, this.height, this.isLooped});

  @override
  createState() => PlayerState();
}

class PlayerState extends State<Player> {
  VideoPlayerController _controller;
  var _isPlaying = true;
  var _playbackPosition = 0.0;

  @override
  initState() {
    _initialisePlayer();
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _controller == null ? Container() : _loadedContentWidget(),
    );
  }

  Widget _loadedContentWidget() {
    return Stack(
      children: [
        Container(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: SizedBox(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        ),
        Container(
          width: widget.width,
          child: VideoProgressIndicator(_controller, allowScrubbing: true),
        ),
      ],
    );
  }

  _initialisePlayer() async {
    VideoPlayerController controller;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final filename = fileName(widget.videoUrl);
    final localFile = File(documentsDirectory.path + '/' + filename);
    if (await localFile.exists()) {
      print("Initialised player with local file: " + localFile.path);
      controller = VideoPlayerController.file(localFile);
    } else if (isUrl(widget.videoUrl)) {
      print("Initialised player with url: " + widget.videoUrl);
      controller = VideoPlayerController.network(widget.videoUrl);
    } else {
      print("Initialised player with asset: " + widget.videoUrl);
      controller = VideoPlayerController.asset(widget.videoUrl);
    }
    controller.setLooping(widget.isLooped);
    await controller.initialize();
    final dur = controller.value.duration.inMilliseconds.roundToDouble();
    await controller.seekTo(Duration(milliseconds: (_playbackPosition * dur).round()));
    if (_isPlaying) await controller.play();
    final oldController = _controller;
    setState(() => _controller = controller);
    await oldController?.dispose();
  }

  bool isUrl(String url) => url.contains("https://") || url.contains("http://");

  String fileName(String url) => basename(url).split('?').first;
}
