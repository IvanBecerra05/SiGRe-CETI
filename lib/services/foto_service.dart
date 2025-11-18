import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class FotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Selecciona una imagen desde la cámara o galería,
  /// la copia al directorio interno de la app y devuelve la ruta local.
  static Future<String?> seleccionarImagen(ImageSource source) async {
    final XFile? foto = await _picker.pickImage(source: source);
    if (foto == null) return null;

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = basename(foto.path);
    final String localPath = join(appDir.path, fileName);

    await File(foto.path).copy(localPath);

    // Guardar también en la galería (opcional)
    try {
      await Gal.putImage(foto.path, album: "Basura CETI");
    } catch (_) {
      // Si falla, no rompemos el flujo
    }

    return localPath;
  }
}
