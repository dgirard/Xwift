/// Image format helpers: Gemini models do not all return the same format
/// (PNG or JPEG), and files must carry the matching extension and type.
library;

bool _isJpeg(List<int> bytes) =>
    bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

/// "jpg" or "png".
String imageFileExtension(List<int> bytes) => _isJpeg(bytes) ? 'jpg' : 'png';

/// "image/jpeg" or "image/png".
String imageMimeType(List<int> bytes) =>
    _isJpeg(bytes) ? 'image/jpeg' : 'image/png';
