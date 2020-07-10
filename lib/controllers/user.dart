import 'dart:io';

import 'package:aqueduct/aqueduct.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http_server/http_server.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:mime/mime.dart';
import 'package:postgres/postgres.dart';
import 'package:sample_crud/sample_crud.dart';
import '../db/db.dart';

final PostgreSQLConnection db = DB.getConn();

class RegisterController extends ResourceController {
	@Operation.post()
	Future<RequestOrResponse> register(Request request) async {
		final transformer = MimeMultipartTransformer(request.raw.headers.contentType.parameters["boundary"]);
		final bodyStream = Stream.fromIterable([await request.body.decode<List<int>>()]);
		final parts = await transformer.bind(bodyStream).toList();

		String filename;
		for (var part in parts) {
			final HttpMultipartFormData multipart = HttpMultipartFormData.parse(part);

			final ContentType contentType = multipart.contentType;
			if(contentType.mimeType.contains("image/")) {
				final content = multipart.cast<List<int>>();

				final List<String> tokens = part.headers['content-disposition'].split(";");
				for (var i = 0; i < tokens.length; ++i) {
					if (tokens[i].contains('filename')) {
						filename = tokens[i].substring(tokens[i].indexOf("=") + 2, tokens[i].length - 1);
					}
				}
				final filePath = "images/${filename}";

				final IOSink sink = File(filePath).openWrite();
				await content.forEach(sink.add);
				await sink.flush();
				await sink.close();
			}
		}

		final Map<String, String> req = await request.body.decode();

		final hash = DBCrypt().hashpw(req['password'], DBCrypt().gensalt());

    	load();
		final key = env['auth_pass'];
		final claimSet = JwtClaim(
			subject: 'sampleCRUD',
			issuer: env['issuer'],
			audience: <String>[env['audience']],
			otherClaims: <String, String>{
				'email': req['email']
			},
			maxAge: const Duration(hours: 1)
		);

		final token = issueJwtHS256(claimSet, key);

		final rowCount = await db.execute("INSERT INTO users(name, email, mobile, username, password, fcm, token, profPic) VALUES(${req['name']}, ${req['email']}, ${req['mobile']}, ${req['username']}, ${hash}, ${req['fcm']}, ${token}, ${filename}) RETURNING id");
		if(rowCount == 1) {
			return Response.ok({"message": "Registration Successful"}, headers: {"token": token});
		}
		return Response.badRequest(body: {"message": "Could not Complete Registration"});
	}
}

class LoginController extends ResourceController {
	@Operation.put()
	Future<RequestOrResponse> login(Request request) async {
		final Map<String, String> req = await request.body.decode();

		final List<Map<String, Map<String, dynamic>>> result = await db.mappedResultsQuery("SELECT id, email, password FROM users WHERE username = ${req['username']}");

		if(result.isEmpty) {
			return Response.badRequest(body: {"message": "Invalid Username"});
		}

		final isCorrect = DBCrypt().checkpw(req['password'], result[0]['users']['password'] as String);
		if(isCorrect == false) {
			return Response.badRequest(body: {"message": "Incorrect Password"});
		}

    	load();
		final key = env['auth_pass'];
		final claimSet = JwtClaim(
			subject: 'sampleCRUD',
			issuer: env['issuer'],
			audience: <String>[env['audience']],
			otherClaims: <String, String>{
				'email': result[0]['users']['email'] as String
			},
			maxAge: const Duration(hours: 1)
		);

		final token = issueJwtHS256(claimSet, key);

		final rowCount = await db.execute("UPDATE users SET token = ${token}, fcm = ${req['fcm']} WHERE id = ${result[0]['users']['id']}");
		if(rowCount == 0) {
			return Response.forbidden(body: {"message": "Could not Establish Session"});
		}

		return Response.ok({"message": "Login Successful", "userid": result[0]['users']['id']}, headers: {"token": token});
	}
}

class ForgotPasswordController extends ResourceController {
	@Operation.put()
	Future<RequestOrResponse> forgotPassword(Request request) async {
		final Map<String, String> req = await request.body.decode();

		final hash = DBCrypt().hashpw(req['password'], DBCrypt().gensalt());
		final rowCount = await db.execute("UPDATE users SET password = ${hash} WHERE email = ${req['email']}");
		if(rowCount == 0) {
			return Response.badRequest(body: {"message": "Could not Change Password"});
		}
		return Response.ok({"message": "Password Changed Successfully"});
	}
}

class LogoutController extends ResourceController {
	@Operation.get()
	Future<RequestOrResponse> logout(@Bind.query('userid') int userId) async {
		final rowCount = await db.execute("UPDATE users SET token = NULL WHERE id = ${userId}");
		if(rowCount == 0) {
			return Response.badRequest(body : {"message": "Could not end Session"});
		}
		return Response.ok({"message": "Logout Successful"});
	}
}



class GetAllUsersController extends ResourceController {
	@Operation.get()
	Future<RequestOrResponse> getAll(@Bind.query('userid') int userId) async {
		final List<Map<String, Map<String, dynamic>>> result = await db.mappedResultsQuery("SELECT id, profPic, name, username FROM users WHERE id <> ${userId}");
		if(result.isEmpty) {
			return Response.ok({"message": "No other users are currently available", "users": []});
		}

		final List<Map<String, dynamic>> response = [];

		for(var row in result) {
			response.add(row['users']);
		}
		return Response.ok({"users": response});
	}
}

class GetUserDetailsController extends ResourceController {
	@Operation.get()
	Future<RequestOrResponse> getDetails(@Bind.query('userid') int userId) async {
		final List<Map<String, Map<String, dynamic>>> result = await db.mappedResultsQuery("SELECT profPic, name, username, email, mobile FROM users WHERE id = ${userId}");
		if(result.isEmpty) {
			return Response.forbidden(body: {"message": "Invalid Request", "user": {}});
		}

		return Response.ok({"user": result[0]['users']});
	}
}

class UpdateProfileController extends ResourceController {
	@Operation.put()
	Future<RequestOrResponse> updateProfile(Request request, @Bind.header("token") String token) async {
		final transformer = MimeMultipartTransformer(request.raw.headers.contentType.parameters["boundary"]);
		final bodyStream = Stream.fromIterable([await request.body.decode<List<int>>()]);
		final parts = await transformer.bind(bodyStream).toList();

		String filename;
		for (var part in parts) {
			final HttpMultipartFormData multipart = HttpMultipartFormData.parse(part);

			final ContentType contentType = multipart.contentType;
			if(contentType.mimeType.contains("image/")) {
				final content = multipart.cast<List<int>>();

				final List<String> tokens = part.headers['content-disposition'].split(";");
				for (var i = 0; i < tokens.length; ++i) {
					if (tokens[i].contains('filename')) {
						filename = tokens[i].substring(tokens[i].indexOf("=") + 2, tokens[i].length - 1);
					}
				}
				final filePath = "images/${filename}";

				final IOSink sink = File(filePath).openWrite();
				await content.forEach(sink.add);
				await sink.flush();
				await sink.close();
			}
		}

		final Map<String, String> req = await request.body.decode();
		int rowCount;
		if(filename != '') {
			rowCount = await db.execute("UPDATE users SET name = ${req['name']}, username = ${req['username']}, mobile = ${req['mobile']}, profPic = ${filename} WHERE id = ${req['userid']} AND token = ${token}");
		} else {
			rowCount = await db.execute("UPDATE users SET name = ${req['name']}, username = ${req['username']}, mobile = ${req['mobile']} WHERE id = ${req['userid']} AND token = ${token}");
		}
		if(rowCount == 0) {
			return Response.badRequest(body: {"message": "Invalid Request"});
		}
		Response.ok({"message": "Profile Updated Successfully"});
	}
}

class DeleteAccountController extends ResourceController {
	@Operation.delete()
	Future<RequestOrResponse> deleteAccount(Request request, @Bind.header('token') String token) async {
		final Map<String, String> req = await request.body.decode();
		final int rowCount = await db.execute("DELETE FROM users WHERE token = ${token} AND id = ${req['userid']}");
		if(rowCount == 0) {
			return Response.forbidden(body: {"message": "Invalid Request"});
		}
		return Response.ok({"message": "Account Deleted Successfully"});
	}
}



class RefreshTokenController extends ResourceController {
	@Operation.get()
	Future<RequestOrResponse> refreshToken(Request request) async {
    	load();
		final key = env['auth_pass'];
		final claimSet = JwtClaim(
			subject: 'sampleCRUD',
			issuer: env['issuer'],
			audience: <String>[env['audience']],
			otherClaims: <String, String>{
				'email': request.attachments["email"] as String
			},
			maxAge: const Duration(hours: 1)
		);

		final token = issueJwtHS256(claimSet, key);
		final int rowCount = await db.execute("UPDATE handlers SET token = ${token} WHERE email = ${request.attachments['email']}");
		if(rowCount == 0) {
			return Response.badRequest(body: {"message": "Could not re-establish Session. Please Try Again."});
		}
		return Response.ok({"message": "Session Renewed"}, headers: {"token": token});
	}
}