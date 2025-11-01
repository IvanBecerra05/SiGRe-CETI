import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class FotoService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> tomarFoto() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);

    if (foto == null) return null;

    // Guardar copia en carpeta local de la app
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = basename(foto.path);
    final String localPath = join(appDir.path, fileName);
    await File(foto.path).copy(localPath);

    // Guardar también en la galería del teléfono
    await Gal.putImage(foto.path, album: "Basura CETI");

    return localPath; // este path lo guardas en la base de datos
  }
}
