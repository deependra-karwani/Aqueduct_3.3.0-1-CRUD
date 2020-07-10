import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

class DB {
	DB() {
    load();
		createConn();
	}

	static PostgreSQLConnection _connection;

	void createConn() async {
		_connection = PostgreSQLConnection(env['db_host'], env['db_port'] as int, env['db_name'], username: env['db_user'], password: env['db_pass']);
		await _connection.open();
	}

	static PostgreSQLConnection getConn() {
		return _connection;
	}
}