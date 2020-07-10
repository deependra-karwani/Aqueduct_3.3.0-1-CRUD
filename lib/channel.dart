import 'controllers/user.dart';
import 'middlewares/auth.dart';
import 'sample_crud.dart';

/// This type initializes an application.
///
/// Override methods in this class to set up routes and initialize services like
/// database connections. See http://aqueduct.io/docs/http/channel/.
class SampleCrudChannel extends ApplicationChannel {
	/// Initialize services in this method.
	///
	/// Implement this method to initialize services, read values from [options]
	/// and any other initialization required before constructing [entryPoint].
	///
	/// This method is invoked prior to [entryPoint] being accessed.
	@override
	Future prepare() async {
		CORSPolicy.defaultPolicy.allowedMethods = ["GET", "POST", "PUT", "DELETE"];
		CORSPolicy.defaultPolicy.allowedOrigins = ["*"];
		CORSPolicy.defaultPolicy.allowedRequestHeaders = ["Content-Type", "Origin", "X-Requested-With", "Accept", "token"];
		CORSPolicy.defaultPolicy.exposedResponseHeaders = ["token"];
		logger.onRecord.listen((rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"));
	}

	/// Construct the request channel.
	///
	/// Return an instance of some [Controller] that will be the initial receiver
	/// of all [Request]s.
	///
	/// This method is invoked after [prepare].
	@override
	Controller get entryPoint {
		final router = Router();

		router
			.route("/user/register")
			.link(() => RegisterController());

		router
			.route("/user/login")
			.link(() => LoginController());

		router
			.route("/user/forgot")
			.link(() => ForgotPasswordController());

		router
			.route("/user/logout")
			.link(() => LogoutController());


		router
			.route("/user/getAll")
			.link(() => UserAuth())
			.link(() => GetAllUsersController());

		router
			.route("/user/getDetails")
			.link(() => UserAuth())
			.link(() => GetUserDetailsController());

		router
			.route("/user/updProf")
			.link(() => UserAuth())
			.link(() => UpdateProfileController());

		router
			.route("/user/delAcc")
			.link(() => UserAuth())
			.link(() => DeleteAccountController());

		router
			.route("/user/refresh")
			.link(() => UserRefresh())
			.link(() => RefreshTokenController());

    router
      .route("/static/*")
      .link(() => FileController("images/"));

		return router;
	}
}