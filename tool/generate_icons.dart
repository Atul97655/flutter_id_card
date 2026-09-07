// ignore_for_file: avoid_print, prefer_const_declarations
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const int size = 1024;
  final img.Image image = img.Image(width: size, height: size);

  // Background: Deep professional navy blue gradient
  for (int y = 0; y < size; y++) {
    final double t = y / size;
    final int r = (15 + t * 10).toInt();
    final int g = (32 + t * 25).toInt();
    final int b = (67 + t * 45).toInt();
    for (int x = 0; x < size; x++) {
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Draw rounded card shape in the center (54x86 aspect ratio)
  final int cardW = 540;
  final int cardH = 860;
  final int cardX = (size - cardW) ~/ 2;
  final int cardY = (size - cardH) ~/ 2;
  const int cardRadius = 40;

  // Drop shadow behind card
  img.fillCircle(image, x: size ~/ 2, y: size ~/ 2 + 20, radius: 460, color: img.ColorRgba8(0, 0, 0, 80));

  // Draw card white body
  img.fillRect(
    image,
    x1: cardX,
    y1: cardY,
    x2: cardX + cardW,
    y2: cardY + cardH,
    color: img.ColorRgba8(255, 255, 255, 255),
    radius: cardRadius,
  );

  // Header band (Primary Crimson Red: #D32F2F)
  img.fillRect(
    image,
    x1: cardX,
    y1: cardY,
    x2: cardX + cardW,
    y2: cardY + 180,
    color: img.ColorRgba8(211, 47, 47, 255),
    radius: cardRadius,
  );
  // Flatten bottom corners of header
  img.fillRect(
    image,
    x1: cardX,
    y1: cardY + 140,
    x2: cardX + cardW,
    y2: cardY + 180,
    color: img.ColorRgba8(211, 47, 47, 255),
  );

  // Lanyard slot at top center
  img.fillRect(
    image,
    x1: size ~/ 2 - 50,
    y1: cardY + 25,
    x2: size ~/ 2 + 50,
    y2: cardY + 45,
    color: img.ColorRgba8(15, 32, 67, 255),
    radius: 10,
  );

  // Photo frame (1.2 x 1.5 ratio: e.g. 240 x 300)
  final int photoW = 240;
  final int photoH = 300;
  final int photoX = (size - photoW) ~/ 2;
  final int photoY = cardY + 220;

  // Photo border
  img.fillRect(
    image,
    x1: photoX - 4,
    y1: photoY - 4,
    x2: photoX + photoW + 4,
    y2: photoY + photoH + 4,
    color: img.ColorRgba8(21, 101, 192, 255), // Secondary Blue
    radius: 16,
  );
  // Photo placeholder background (light slate)
  img.fillRect(
    image,
    x1: photoX,
    y1: photoY,
    x2: photoX + photoW,
    y2: photoY + photoH,
    color: img.ColorRgba8(240, 244, 248, 255),
    radius: 12,
  );

  // Stylized avatar head and shoulders in photo
  img.fillCircle(
    image,
    x: size ~/ 2,
    y: photoY + 110,
    radius: 55,
    color: img.ColorRgba8(144, 164, 174, 255),
  );
  img.fillCircle(
    image,
    x: size ~/ 2,
    y: photoY + 280,
    radius: 110,
    color: img.ColorRgba8(144, 164, 174, 255),
  );

  // Name banner block (Red)
  img.fillRect(
    image,
    x1: cardX + 50,
    y1: photoY + photoH + 40,
    x2: cardX + cardW - 50,
    y2: photoY + photoH + 75,
    color: img.ColorRgba8(211, 47, 47, 255),
    radius: 8,
  );

  // Student details rows (Blue lines)
  final int rowStart = photoY + photoH + 110;
  for (int i = 0; i < 4; i++) {
    final int y = rowStart + i * 45;
    // Label bar
    img.fillRect(
      image,
      x1: cardX + 60,
      y1: y,
      x2: cardX + 160,
      y2: y + 18,
      color: img.ColorRgba8(21, 101, 192, 200),
      radius: 6,
    );
    // Value bar
    img.fillRect(
      image,
      x1: cardX + 180,
      y1: y,
      x2: cardX + cardW - 60,
      y2: y + 18,
      color: img.ColorRgba8(120, 144, 156, 180),
      radius: 6,
    );
  }

  // Save 1024x1024 master icon
  Directory('assets/images').createSync(recursive: true);
  File('assets/images/app_icon.png').writeAsBytesSync(img.encodePng(image));
  print('Saved master app_icon.png (1024x1024)');

  // Generate Android mipmap sizes
  final Map<String, int> mipmaps = <String, int>{
    'android/app/src/main/res/mipmap-mdpi': 48,
    'android/app/src/main/res/mipmap-hdpi': 72,
    'android/app/src/main/res/mipmap-xhdpi': 96,
    'android/app/src/main/res/mipmap-xxhdpi': 144,
    'android/app/src/main/res/mipmap-xxxhdpi': 192,
  };

  for (final MapEntry<String, int> entry in mipmaps.entries) {
    final img.Image resized = img.copyResize(
      image,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.linear,
    );
    Directory(entry.key).createSync(recursive: true);
    File('${entry.key}/ic_launcher.png').writeAsBytesSync(img.encodePng(resized));
    print('Generated ${entry.key}/ic_launcher.png (${entry.value}x${entry.value})');
  }

  print('Launcher icon generation complete!');
}
