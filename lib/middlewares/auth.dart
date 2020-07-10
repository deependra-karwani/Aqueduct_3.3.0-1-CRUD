import 'package:aqueduct/aqueduct.dart';
import 'package:dotenv/dotenv.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:postgres/postgres.dart';
import 'package:sample_crud/sample_crud.dart';
import '../db/db.dart';

final PostgreSQLConnection db = DB.getConn();

class UserAuth extends Controller {
	@override
	Future<RequestOrResponse> handle(Request request, @Bind.header('token') String token) async {
		if(token == null || token == "") {
			return Response.unauthorized(body: {"message": "Missing Headers"});
		}
		try {
			load();
			final JwtClaim decClaimSet = verifyJwtHS256Signature(token, env['auth_pass']);

			decClaimSet.validate(issuer: env['issuer'], audience: env['audience']);

			final List<List<dynamic>> result = await db.query("SELECT * FROM users WHERE token = ${token}");
			if(result.isEmpty) {
				return Response.forbidden(body: {"message": "Invalid Headers"});
			}
			return request;
		} catch(e) {
			return Response.unauthorized(body: {"message": "Invalid Session"});
		}
	}
}

class UserRefresh extends Controller {
	@override
	Future<RequestOrResponse> handle(Request request, @Bind.header('token') String token) async {
		if(token == null || token == "") {
			return Response.forbidden(body: {"message": "Invalid Request"});
		}
		try {
			load();
			final JwtClaim decClaimSet = verifyJwtHS256Signature(token, env['auth_pass']);

			decClaimSet.validate(issuer: env['issuer'], audience: env['audience']);
			return request;
		} on JwtException catch(e) {
			final Map<String, String> req = await request.body.decode();
			request.attachments['email'] = req['email'];
			return request;
		} catch(e) {
			return Response.unauthorized(body: {"message": "Invalid Session"});
		}
	}
}