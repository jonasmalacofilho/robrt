package robrt;

import robrt.repository.RepoConfig;
import robrt.server.ServerConfig;

enum ConfigFile {
	ServerConfigFile(config:ServerConfig);
	RepoConfigFile(config:RepoConfig);
}

class ConfigFileUtils {
	public static function read(path):ConfigFile
	{
		if (!sys.FileSystem.exists(path) || sys.FileSystem.isDirectory(path))
			throw 'Invalid config path: $path';
		trace('Reading config file from $path');

		var format = haxe.io.Path.extension(path).toLowerCase();
		trace('Config file is $format');

		var data:Dynamic =
			switch format {
			case "yaml":
				yaml.Yaml.parse(sys.io.File.getContent(path), yaml.Parser.options().useObjects());
			case "json":
				haxe.Json.parse(sys.io.File.getContent(path));
			case other:
				throw 'Unsupported extension: $other';
			}

		var file = Reflect.hasField(data, "repositories") ? ServerConfigFile(data) : RepoConfigFile(data);
		trace('file is ${Type.enumConstructor(file)}');

		// TODO validate according to file type

		return file;
	}

	public static function readServerConfig(path):ServerConfig
	{
		switch read(path) {
		case ServerConfigFile(config):
			return config;
		case other:
			throw "Wrong file type, expected server configuration file";
		}
	}

	public static function readRepoConfig(path):RepoConfig
	{
		switch read(path) {
		case RepoConfigFile(config):
			return config;
		case other:
			throw "Wrong file type, expected repository configuration file";
		}
	}
}

