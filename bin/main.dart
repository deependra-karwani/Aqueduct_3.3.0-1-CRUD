import 'package:dotenv/dotenv.dart';
import 'package:sample_crud/sample_crud.dart';
Future main() async {
  load();
  final app = Application<SampleCrudChannel>()
      ..options.configurationFilePath = "config.yaml"
      ..options.port = env["PORT"] as int;

  final count = Platform.numberOfProcessors ~/ 2;
  await app.start(numberOfInstances: count > 0 ? count : 1);

  print("Application started on port: ${app.options.port}.");
  print("Use Ctrl-C (SIGINT) to stop running the application.");
}