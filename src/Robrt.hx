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
	static var VERSION = {
		var pkg = Version.getVersion("package.json");
		var sha = Version.getGitCommitHash().substr(0, 9);
		var dirty = Version.isGitTreeDirty();
		var haxe = Version.getHaxeCompilerVersion();
		'robrt v${pkg}+${sha}${dirty ? "-dirty" : ""} (haxe v${haxe})';
	}

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

		try {
			var sms = js.Lib.require("source-map-support");
			sms.install();
			haxe.CallStack.wrapCallSite = sms.wrapCallSite;
			trace("Source map support enabled");
		} catch (e:Dynamic) {
			trace("WARNING: could not prepare source map support:", e);
		}

		trace("Starting");

		var config = readServerConfig();
		var handler = robrt.IncomingRequest.handleRequest.bind(config);

		if (options["listen"]) {
			var port = Std.parseInt(options["<port>"]);
			if (port == null || port < 1 || port > 65355)
				throw 'Invalid port number ${options["<port>"]}';

			var server = Http.createServer(handler);

			// handle exit from some signals
			function signalHandler(signal:String)
			{
				server.on("close",
					function () {
						trace('Succeeded in shutting down the HTTP server; emitting $signal once more');
						Node.process.kill(Node.process.pid, signal);
					}
				);
				trace('Trying a controlled shutdown after receiving $signal');
				server.close();  // FIXME not actually waiting for all responses to finish
			}
			Node.process.once("SIGINT", signalHandler.bind("SIGINT"));
			Node.process.once("SIGTERM", signalHandler.bind("SIGTERM"));
			Node.process.once("SIGUSR2", signalHandler.bind("SIGUSR2"));

			server.listen(port);
			trace('Listening on port $port');
		} else {
			throw 'Should not have reached this point;\n$options';
		}
	}
}

