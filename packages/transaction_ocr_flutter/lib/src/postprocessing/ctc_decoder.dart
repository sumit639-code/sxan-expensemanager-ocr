/// CTC Greedy Decoder for SVTR-LCNet / PP-OCR recognition models.
/// Matches Python `CTCLabelDecode` in RapidOCR.
class CtcDecoder {
  final List<String> characterDict;

  /// Constructs CtcDecoder with character vocabulary.
  /// Note: Index 0 is reserved for CTC blank.
  /// If characterDict already contains 'blank' at index 0, it is used directly;
  /// otherwise 'blank' is prepended.
  CtcDecoder({required List<String> characterDict})
      : characterDict = _ensureBlankToken(characterDict);

  static List<String> _ensureBlankToken(List<String> dict) {
    if (dict.isNotEmpty && dict.first == 'blank') {
      return List.from(dict);
    }
    final full = <String>['blank', ...dict];
    if (!full.contains(' ')) {
      full.add(' ');
    }
    return full;
  }

  /// Parses `keys_v1.txt` string content into character list.
  factory CtcDecoder.fromKeysText(String keysContent) {
    final lines = keysContent.split(RegExp(r'\r?\n'));
    final chars = <String>[];
    for (final line in lines) {
      if (line.isNotEmpty) {
        chars.add(line);
      }
    }
    return CtcDecoder(characterDict: chars);
  }

  /// Decodes CTC logit predictions (indices and probabilities along time dimension)
  /// into recognized string and average confidence score.
  ///
  /// - [predIndices]: 1D List of token index predictions (e.g. from argmax across classes)
  /// - [predProbs]: 1D List of corresponding max probabilities (0.0 .. 1.0)
  Map<String, dynamic> decode(
    List<int> predIndices,
    List<double> predProbs, {
    bool isRemoveDuplicate = true,
  }) {
    final List<String> charList = [];
    final List<double> confList = [];

    const int blankIndex = 0;

    for (int i = 0; i < predIndices.length; i++) {
      final idx = predIndices[i];
      if (idx == blankIndex) {
        continue;
      }
      if (isRemoveDuplicate && i > 0 && predIndices[i - 1] == idx) {
        continue;
      }

      if (idx >= 0 && idx < characterDict.length) {
        charList.add(characterDict[idx]);
        confList.add(predProbs[i]);
      }
    }

    final text = charList.join('');
    final avgConf = confList.isEmpty
        ? 0.0
        : confList.reduce((a, b) => a + b) / confList.length;

    return {
      'text': text,
      'confidence': double.parse(avgConf.toStringAsFixed(4)),
    };
  }
}
