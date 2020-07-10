import '../db/db.dart';
void main() async {
	final db = DB.getConn();

	try {
		await db.execute("CREATE TABLE IF NOT EXISTS users(id SERIAL PRIMARY KEY, name VARCHAR(255) NOT NULL, profPic VARCHAR(255), email VARCHAR(254) NOT NULL UNIQUE, mobile CHAR(10), username VARCHAR(50) NOT NULL UNIQUE, password CHAR(64) NOT NULL, fcm TEXT, token VARCHAR(255) UNIQUE)");
		print("Users Table Created");
	} catch(e) {
		print("Error on Creating Users Table: ${e}");
	}
}