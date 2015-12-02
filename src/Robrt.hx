import js.Node;
import js.node.*;
import robrt.Variables;
import robrt.server.ServerConfig;

/**
Robrt: a robot that listens to GitHub events and deploys stuff.

Usage:
  robrt.js listen <port>
  robrt.js -h | --help
  robrt.js --version

Environment variables:
  ROBRT_CONFIG      Alternate path to configuration file
**/
@:rtti
class Robrt {
	static inline var VERSION = "0.0.1-alpha.1";

	public static function ctrace(msg:Dynamic, ?p:haxe.PosInfos)
	{
		var lines = StringTools.rtrim(msg).split("\n");
		if (p.customParams != null)
			lines[lines.length - 1] += ': ' + p.customParams.join(',');
		var loc = '@${p.className}.${p.methodName}(${p.fileName}:${p.lineNumber})';
		if (lines.length > 1)
			lines.push(loc);
		else
			lines[lines.length - 1] += '  $loc';
		Node.console.log(lines.join("\n... "));
	}

	static function readServerConfig()
	{
		var path = Sys.getEnv(ServerVariables.ConfigPath);
		if (path == null)
			path = "/etc/robrt.json";
		if (!sys.FileSystem.exists(path) || sys.FileSystem.isDirectory(path))
			throw 'Invalid config path: $path';
		trace('Reading config file from $path');
		var data = haxe.Json.parse(sys.io.File.getContent(path));
		// TODO validate data
		return (data:ServerConfig);
	}

	static function main()
	{
		haxe.Log.trace = function (msg, ?p) ctrace('  * $msg', p);
		var usage = haxe.rtti.Rtti.getRtti(Robrt).doc;
		var options = js.npm.Docopt.docopt(usage, { version : VERSION });

		trace("Starting");

		var config = readServerConfig();
		var handler = robrt.RequestHandler.handleRequest.bind(config);

		if (options["listen"]) {
			var port = Std.parseInt(options["<port>"]);
			if (port == null || port < 1 || port > 65355)
				throw 'Invalid port number ${options["<port>"]}';

			var server = Http.createServer(handler);

			// handle exit from some signals
			function controledExit(signal:String)
			{
				var code = 128 + switch (signal) {
				case "SIGINT": 2;
				case "SIGTERM": 15;
				case "SIGUSR2": 12;  // nodemon uses this to restart
				case _: 0;  // ?
				}
				trace('Trying a controled shutdown after signal $signal');
				server.on("close", function () {
					trace('Succeded in shutting down the HTTP server; exiting now with code $code');
					js.Node.process.exit(code);
				});
				server.close();  // FIXME not really waiting for all responses to finish
			}
			Node.process.on("SIGINT", controledExit.bind("SIGINT"));
			Node.process.on("SIGTERM", controledExit.bind("SIGTERM"));
			Node.process.on("SIGUSR2", controledExit.bind("SIGUSR2"));

			server.listen(port);
			trace('Listening on port $port');
		} else {
			throw 'Should not have reached this point;\n$options';
		}
	}
}

